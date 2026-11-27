/**
 * Épica 3: solicitud, precio y contraofertas (estilo inDrive).
 * HU-08, HU-09, HU-10, HU-11, HU-12, HU-13, HU-14, HU-23.
 *
 * Una solicitud y su servicio son el mismo documento: servicios/{id}.
 * Las ofertas de los cuidadores van en servicios/{id}/ofertas/{cuidadorId}.
 */
import { distanceBetween, geohashForLocation, geohashQueryBounds } from "geofire-common";
import { onCall } from "firebase-functions/v2/https";
import {
  OFERTA_EXPIRA_SEGUNDOS,
  PAQUETES_FIJOS,
  RADIO_BUSQUEDA_KM,
  SALDO_MINIMO_CENTIMOS,
  SOLICITUD_EXPIRA_MINUTOS,
  TipoServicio,
} from "../config/reglas";
import { desgloseOferta } from "../dominio/dinero";
import { sumarSegundos } from "../dominio/fechas";
import { Punto, distanciaKm, esPuntoValido, minutosLlegada } from "../dominio/geo";
import { esDuracionPaquete, precioPaquete, rangoSugerido, validarPrecioOfrecido } from "../dominio/precios";
import { METODOS_PAGO, MetodoPago, TIPOS_SERVICIO, puedeTransicionar, servicioAdmiteEspecie } from "../dominio/servicio";
import { leerSaldo } from "../lib/billetera";
import { validarCuidadorApto } from "../lib/cuidador";
import { datos, falla, requiereUsuario } from "../lib/errores";
import { COL, FieldValue, REGION, db, ts } from "../lib/firebase";
import { notificar } from "../lib/notificaciones";
import { refPerfil, refUsuario, usuarioActivo } from "../lib/usuarios";

const refServicio = (id: string) => db.collection(COL.servicios).doc(id);
const refUbicacion = (uid: string) => db.collection("ubicacionesCuidadores").doc(uid);

interface Lugar extends Punto {
  direccion: string;
}

function leerLugar(v: unknown, nombre: string): Lugar {
  if (!esPuntoValido(v)) falla("invalid-argument", `Falta la ubicación de ${nombre}`);
  const direccion = (v as { direccion?: unknown }).direccion;
  return {
    lat: v.lat,
    lng: v.lng,
    direccion: typeof direccion === "string" ? direccion.slice(0, 200) : "",
  };
}

function distanciaDelServicio(tipo: TipoServicio, origen: Punto, destino?: Punto): number {
  return tipo === "transporte" && destino ? distanciaKm(origen, destino) : 0;
}

/** HU-10 / HU-11: rango sugerido y paquetes, para mostrar antes de pedir. */
export const cotizar = onCall({ region: REGION }, async (req) => {
  requiereUsuario(req);
  const d = datos<{ tipo: TipoServicio; duracionMin: number; origen: Punto; destino: Punto }>(req);
  if (!TIPOS_SERVICIO.includes(d.tipo as TipoServicio)) falla("invalid-argument", "Servicio inválido");
  const tipo = d.tipo as TipoServicio;
  const duracion = Number(d.duracionMin);
  if (!(duracion > 0 && duracion <= 600)) falla("invalid-argument", "Duración inválida");
  const km = esPuntoValido(d.origen) && esPuntoValido(d.destino) ? distanciaDelServicio(tipo, d.origen, d.destino) : 0;
  return { rango: rangoSugerido(tipo, duracion, km), paquetes: PAQUETES_FIJOS[tipo], distanciaKm: km };
});

interface EntradaSolicitud {
  mascotaId: string;
  tipo: TipoServicio;
  modalidad: "oferta" | "paquete";
  duracionMin: number;
  precio: number;
  origen: Lugar;
  destino: Lugar;
  metodoPago: MetodoPago;
  indicaciones: string;
}

/** HU-09, HU-10, HU-11, HU-23: el dueño crea la solicitud. */
export const crearSolicitud = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const d = datos<EntradaSolicitud>(req);
  if (!TIPOS_SERVICIO.includes(d.tipo as TipoServicio)) falla("invalid-argument", "Elige un servicio");
  const tipo = d.tipo as TipoServicio;
  if (!METODOS_PAGO.includes(d.metodoPago as MetodoPago)) falla("invalid-argument", "Elige cómo pagarás: Yape, Plin o efectivo");
  const origen = leerLugar(d.origen, "recojo");
  const destino = tipo === "transporte" ? leerLugar(d.destino, "destino (veterinaria o groomer)") : null;
  const km = distanciaDelServicio(tipo, origen, destino ?? undefined);

  let duracionMin: number;
  let precio: number;
  let aviso: string | undefined;
  let rango: ReturnType<typeof rangoSugerido> | null = null;
  if (d.modalidad === "paquete") {
    if (!esDuracionPaquete(d.duracionMin)) falla("invalid-argument", "Elige un paquete de 30 min, 1 h o 2 h");
    duracionMin = d.duracionMin;
    precio = precioPaquete(tipo, d.duracionMin);
  } else if (d.modalidad === "oferta") {
    duracionMin = Number(d.duracionMin);
    if (!(duracionMin > 0 && duracionMin <= 600)) falla("invalid-argument", "Duración inválida");
    precio = Number(d.precio);
    rango = rangoSugerido(tipo, duracionMin, km);
    const v = validarPrecioOfrecido(precio, rango);
    if (!v.ok) {
      falla(
        "invalid-argument",
        v.motivo === "BAJO_PISO" ? "El precio es demasiado bajo para este servicio" : "El precio va en soles enteros",
        { rango },
      );
    }
    aviso = v.aviso;
  } else {
    falla("invalid-argument", "Elige ofertar precio o paquete fijo");
  }

  const ahora = new Date();
  const ref = db.collection(COL.servicios).doc();
  await db.runTransaction(async (tx) => {
    const [usuario, mascota, abiertas] = await Promise.all([
      usuarioActivo(uid, tx),
      tx.get(db.collection(COL.mascotas).doc(String(d.mascotaId))),
      tx.get(
        db.collection(COL.servicios).where("duenoId", "==", uid).where("estado", "==", "buscando").limit(1),
      ),
    ]);
    if (!mascota.exists || mascota.get("duenoId") !== uid || !mascota.get("activa")) {
      falla("not-found", "Mascota no encontrada");
    }
    const m = mascota.data()!;
    if (!servicioAdmiteEspecie(tipo, m.especie)) falla("failed-precondition", "El paseo es solo para perros");
    if (!abiertas.empty) falla("failed-precondition", "Ya tienes una solicitud buscando cuidador");
    tx.set(ref, {
      duenoId: uid,
      duenoNombre: usuario.nombre,
      cuidadorId: null,
      participantes: [uid],
      mascotaId: mascota.id,
      // Copia de la mascota para que el cuidador la vea en la solicitud (HU-08).
      mascota: {
        nombre: m.nombre,
        especie: m.especie,
        raza: m.raza ?? "",
        tamano: m.tamano,
        edadAnios: m.edadAnios ?? null,
        temperamento: m.temperamento ?? [],
        alertas: m.alertas ?? [],
        notas: m.notas ?? "",
        fotoUrl: m.fotoUrl ?? null,
      },
      tipo,
      modalidad: d.modalidad,
      duracionMin,
      distanciaKm: km,
      origen: { ...origen, geohash: geohashForLocation([origen.lat, origen.lng]) },
      destino,
      indicaciones: typeof d.indicaciones === "string" ? d.indicaciones.slice(0, 500) : "",
      metodoPago: d.metodoPago,
      rangoSugerido: rango,
      precioOfrecido: precio,
      precioFinal: null,
      estado: "buscando",
      ofertasRecibidas: 0,
      sugerenciaSubirPrecioEnviada: false,
      creadoEn: ts(ahora),
      expiraEn: ts(new Date(ahora.getTime() + SOLICITUD_EXPIRA_MINUTOS * 60_000)),
    });
  });

  await avisarCuidadoresCercanos(ref.id, uid, origen, tipo, precio);
  return { id: ref.id, aviso };
});

/** Notifica a los cuidadores disponibles cuya última ubicación está a ≤ 3 km. */
async function avisarCuidadoresCercanos(
  servicioId: string,
  duenoId: string,
  origen: Punto,
  tipo: TipoServicio,
  precio: number,
) {
  const radioM = RADIO_BUSQUEDA_KM * 1000;
  const limite = new Date(Date.now() - 15 * 60_000);
  const consultas = geohashQueryBounds([origen.lat, origen.lng], radioM).map(([inicio, fin]) =>
    db.collection("ubicacionesCuidadores").orderBy("geohash").startAt(inicio).endAt(fin).get(),
  );
  const snaps = await Promise.all(consultas);
  const uids = new Set<string>();
  for (const s of snaps) {
    for (const doc of s.docs) {
      const u = doc.data();
      if (doc.id === duenoId || !u.disponible || u.actualizadoEn?.toDate() < limite) continue;
      if (distanceBetween([u.lat, u.lng], [origen.lat, origen.lng]) <= RADIO_BUSQUEDA_KM) uids.add(doc.id);
    }
  }
  await Promise.all(
    [...uids].map((u) =>
      notificar(u, "Nueva solicitud cerca", `${tipo} por S/ ${(precio / 100).toFixed(2)}`, {
        tipo: "nueva_solicitud",
        servicioId,
      }),
    ),
  );
}

/**
 * HU-12: solicitudes en un radio de 3 km. También guarda la ubicación del
 * cuidador para avisarle de nuevas solicitudes. Si su saldo es menor a S/ 10,
 * devuelve el aviso para recargar y ninguna solicitud.
 */
export const listarSolicitudesCercanas = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const d = datos<Punto>(req);
  if (!esPuntoValido(d)) falla("invalid-argument", "Activa tu ubicación");
  const perfil = (await refPerfil(uid).get()).data();
  if (!perfil?.esCuidador) falla("permission-denied", "Solo para cuidadores");
  if (!perfil.verificado) falla("failed-precondition", "Tu verificación aún no está aprobada");

  await refUbicacion(uid).set({
    lat: d.lat,
    lng: d.lng,
    geohash: geohashForLocation([d.lat, d.lng]),
    disponible: !!perfil.disponible,
    actualizadoEn: FieldValue.serverTimestamp(),
  });
  if (!perfil.disponible) return { disponible: false, solicitudes: [] };

  const saldo = await db.runTransaction((tx) => leerSaldo(tx, uid));
  if (saldo < SALDO_MINIMO_CENTIMOS) {
    return { disponible: true, recargar: true, saldo, solicitudes: [] };
  }

  const bounds = geohashQueryBounds([d.lat, d.lng], RADIO_BUSQUEDA_KM * 1000);
  const snaps = await Promise.all(
    bounds.map(([inicio, fin]) =>
      db
        .collection(COL.servicios)
        .where("estado", "==", "buscando")
        .orderBy("origen.geohash")
        .startAt(inicio)
        .endAt(fin)
        .get(),
    ),
  );
  const ahora = new Date();
  const vistas = new Set<string>();
  const solicitudes = [];
  for (const s of snaps) {
    for (const doc of s.docs) {
      if (vistas.has(doc.id)) continue;
      vistas.add(doc.id);
      const v = doc.data();
      if (v.duenoId === uid || v.expiraEn.toDate() < ahora) continue;
      const km = distanceBetween([v.origen.lat, v.origen.lng], [d.lat, d.lng]);
      if (km > RADIO_BUSQUEDA_KM) continue;
      solicitudes.push({
        id: doc.id,
        tipo: v.tipo,
        modalidad: v.modalidad,
        mascota: v.mascota,
        distanciaKm: Math.round(km * 10) / 10,
        minutosLlegada: minutosLlegada(km),
        duracionMin: v.duracionMin,
        precioOfrecido: v.precioOfrecido,
        desglose: desgloseOferta(v.precioOfrecido),
        metodoPago: v.metodoPago,
        destino: v.destino ? { direccion: v.destino.direccion } : null,
        expiraEn: v.expiraEn.toMillis(),
      });
    }
  }
  solicitudes.sort((a, b) => a.distanciaKm - b.distanciaKm);
  return { disponible: true, saldo, solicitudes };
});

/**
 * HU-13: el cuidador acepta el precio del dueño o contraoferta uno mayor
 * (montos rápidos +S/ 2, +S/ 5, +S/ 8 o uno escrito). La oferta vence en 60 s.
 */
export const enviarOferta = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const d = datos<{ servicioId: string; precio: number; lat: number; lng: number }>(req);
  if (typeof d.servicioId !== "string") falla("invalid-argument", "Falta la solicitud");
  const ubicacion = { lat: d.lat, lng: d.lng };
  if (!esPuntoValido(ubicacion)) falla("invalid-argument", "Activa tu ubicación");
  const precio = Number(d.precio);
  if (!Number.isInteger(precio) || precio % 100 !== 0) falla("invalid-argument", "El precio va en soles enteros");

  const ahora = new Date();
  const expiraEn = sumarSegundos(ahora, OFERTA_EXPIRA_SEGUNDOS);
  let duenoId = "";
  const resultado = await db.runTransaction(async (tx) => {
    const servicioRef = refServicio(d.servicioId!);
    const ofertaRef = servicioRef.collection(COL.ofertas).doc(uid);
    const [servicio, ofertaPrevia, apto] = await Promise.all([
      tx.get(servicioRef),
      tx.get(ofertaRef),
      validarCuidadorApto(tx, uid, precio),
    ]);
    if (!servicio.exists) falla("not-found", "La solicitud ya no existe");
    const s = servicio.data()!;
    duenoId = s.duenoId;
    if (s.estado !== "buscando" || s.expiraEn.toDate() < ahora) falla("failed-precondition", "La solicitud ya no está disponible");
    if (s.duenoId === uid) falla("failed-precondition", "No puedes ofertar en tu propia solicitud");
    if (s.modalidad === "paquete") falla("failed-precondition", "Es un paquete fijo: usa \"Aceptar\"");
    if (precio < s.precioOfrecido) falla("invalid-argument", "Tu oferta no puede ser menor al precio del dueño");
    if (ofertaPrevia.exists && ofertaPrevia.get("estado") === "pendiente" && ofertaPrevia.get("expiraEn").toDate() > ahora) {
      falla("already-exists", "Ya tienes una oferta activa en esta solicitud");
    }
    const km = distanciaKm(ubicacion, s.origen);
    if (km > RADIO_BUSQUEDA_KM) falla("failed-precondition", "Estás fuera del radio de esta solicitud");
    const desglose = desgloseOferta(precio, apto.tasa);
    tx.set(ofertaRef, {
      cuidadorId: uid,
      nombre: apto.perfil.nombre,
      fotoUrl: apto.perfil.fotoUrl ?? null,
      nivel: apto.perfil.nivel,
      calificacionPromedio: apto.perfil.calificacionPromedio ?? 0,
      numResenas: apto.perfil.numResenas ?? 0,
      verificado: true,
      precio,
      esContraoferta: precio > s.precioOfrecido,
      comision: desglose.comision,
      recibes: desglose.recibes,
      distanciaKm: Math.round(km * 10) / 10,
      minutosLlegada: minutosLlegada(km),
      estado: "pendiente",
      creadoEn: ts(ahora),
      expiraEn: ts(expiraEn),
    });
    tx.update(servicioRef, { ofertasRecibidas: FieldValue.increment(1) });
    return desglose;
  });
  await notificar(duenoId, "Nueva oferta", `Un cuidador ofrece S/ ${(precio / 100).toFixed(2)}`, {
    tipo: "nueva_oferta",
    servicioId: d.servicioId!,
  });
  return { ...resultado, expiraEn: expiraEn.getTime() };
});

/** Datos que se crean al confirmar: contacto (HU-05) y chat (HU-19). */
async function confirmar(
  tx: FirebaseFirestore.Transaction,
  servicioRef: FirebaseFirestore.DocumentReference,
  s: FirebaseFirestore.DocumentData,
  cuidadorId: string,
  precioFinal: number,
  tasa: number,
  ahora: Date,
) {
  const [dueno, cuidador] = await Promise.all([tx.get(refUsuario(s.duenoId)), tx.get(refUsuario(cuidadorId))]);
  return () => {
    if (!puedeTransicionar(s.estado, "confirmado")) falla("failed-precondition", "La solicitud ya no está disponible");
    tx.update(servicioRef, {
      estado: "confirmado",
      cuidadorId,
      cuidadorNombre: cuidador.get("nombre"),
      participantes: [s.duenoId, cuidadorId],
      precioFinal,
      comisionTasa: tasa,
      confirmadoEn: ts(ahora),
    });
    // HU-05: el teléfono se ve solo desde que se acepta hasta 24 h después de terminar.
    tx.set(servicioRef.collection(COL.privado).doc("contacto"), {
      participantes: [s.duenoId, cuidadorId],
      telefonoDueno: dueno.get("telefono"),
      telefonoCuidador: cuidador.get("telefono"),
      visibleHasta: null,
    });
    tx.set(db.collection(COL.chats).doc(servicioRef.id), {
      servicioId: servicioRef.id,
      participantes: [s.duenoId, cuidadorId],
      abierto: true,
      cierraEn: null,
      noLeidos: { [s.duenoId]: 0, [cuidadorId]: 0 },
      creadoEn: ts(ahora),
    });
  };
}

/**
 * HU-14: el dueño elige una oferta. Las demás se rechazan y el servicio pasa
 * a "Confirmado". La oferta debe seguir vigente (60 s).
 */
export const aceptarOferta = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const d = datos<{ servicioId: string; cuidadorId: string }>(req);
  if (typeof d.servicioId !== "string" || typeof d.cuidadorId !== "string") falla("invalid-argument", "Faltan datos");
  const ahora = new Date();
  const rechazados: string[] = [];
  await db.runTransaction(async (tx) => {
    const servicioRef = refServicio(d.servicioId!);
    const [servicio, ofertas] = await Promise.all([
      tx.get(servicioRef),
      tx.get(servicioRef.collection(COL.ofertas).where("estado", "==", "pendiente")),
    ]);
    if (!servicio.exists || servicio.get("duenoId") !== uid) falla("not-found", "Solicitud no encontrada");
    const s = servicio.data()!;
    if (s.estado !== "buscando") falla("failed-precondition", "La solicitud ya no está buscando cuidador");
    const elegida = ofertas.docs.find((o) => o.id === d.cuidadorId);
    if (!elegida) falla("not-found", "La oferta ya no está disponible");
    if (elegida.get("expiraEn").toDate() < ahora) falla("deadline-exceeded", "La oferta venció");
    const precio = elegida.get("precio") as number;
    // Se vuelve a validar al cuidador: su saldo pudo cambiar en estos segundos.
    const apto = await validarCuidadorApto(tx, d.cuidadorId!, precio);
    const escribir = await confirmar(tx, servicioRef, s, d.cuidadorId!, precio, apto.tasa, ahora);
    escribir();
    for (const o of ofertas.docs) {
      if (o.id === d.cuidadorId) {
        tx.update(o.ref, { estado: "aceptada", respondidaEn: ts(ahora) });
      } else {
        tx.update(o.ref, { estado: "rechazada", respondidaEn: ts(ahora) });
        rechazados.push(o.id);
      }
    }
  });
  await notificar(d.cuidadorId!, "¡Oferta aceptada!", "El dueño eligió tu oferta. Revisa los detalles.", {
    tipo: "oferta_aceptada",
    servicioId: d.servicioId!,
  });
  await Promise.all(
    rechazados.map((c) =>
      notificar(c, "Oferta no elegida", "El dueño eligió otra oferta", { tipo: "oferta_rechazada", servicioId: d.servicioId! }),
    ),
  );
  return { ok: true };
});

/** HU-11: en paquete fijo, el primer cuidador que acepta queda asignado. */
export const tomarPaquete = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const d = datos<{ servicioId: string; lat: number; lng: number }>(req);
  if (typeof d.servicioId !== "string") falla("invalid-argument", "Falta la solicitud");
  const ubicacion = { lat: d.lat, lng: d.lng };
  if (!esPuntoValido(ubicacion)) falla("invalid-argument", "Activa tu ubicación");
  const ahora = new Date();
  let duenoId = "";
  await db.runTransaction(async (tx) => {
    const servicioRef = refServicio(d.servicioId!);
    const servicio = await tx.get(servicioRef);
    if (!servicio.exists) falla("not-found", "La solicitud ya no existe");
    const s = servicio.data()!;
    duenoId = s.duenoId;
    if (s.modalidad !== "paquete") falla("failed-precondition", "Esta solicitud recibe ofertas");
    if (s.estado !== "buscando" || s.expiraEn.toDate() < ahora) falla("failed-precondition", "Otro cuidador la tomó primero");
    if (s.duenoId === uid) falla("failed-precondition", "No puedes tomar tu propia solicitud");
    if (distanciaKm(ubicacion, s.origen) > RADIO_BUSQUEDA_KM) falla("failed-precondition", "Estás fuera del radio");
    const apto = await validarCuidadorApto(tx, uid, s.precioOfrecido);
    const escribir = await confirmar(tx, servicioRef, s, uid, s.precioOfrecido, apto.tasa, ahora);
    escribir();
  });
  await notificar(duenoId, "Cuidador asignado", "Un cuidador aceptó tu paquete", {
    tipo: "servicio_confirmado",
    servicioId: d.servicioId!,
  });
  return { ok: true };
});

/**
 * Cancelar: el dueño mientras busca o está confirmado; el cuidador solo si
 * está confirmado (antes de iniciar). La política de penalidades está
 * pendiente de definir (ver requisitos legales, "Cancelaciones").
 */
export const cancelarServicio = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const d = datos<{ servicioId: string; motivo: string }>(req);
  if (typeof d.servicioId !== "string") falla("invalid-argument", "Falta el servicio");
  let otro: string | null = null;
  await db.runTransaction(async (tx) => {
    const ref = refServicio(d.servicioId!);
    const snap = await tx.get(ref);
    if (!snap.exists) falla("not-found", "Servicio no encontrado");
    const s = snap.data()!;
    const esDueno = s.duenoId === uid;
    const esCuidador = s.cuidadorId === uid;
    if (!esDueno && !esCuidador) falla("permission-denied", "No participas en este servicio");
    if (!puedeTransicionar(s.estado, "cancelado")) falla("failed-precondition", "Ya no se puede cancelar");
    if (esCuidador && s.estado !== "confirmado") falla("failed-precondition", "Ya no se puede cancelar");
    otro = esDueno ? s.cuidadorId : s.duenoId;
    tx.update(ref, {
      estado: "cancelado",
      canceladoPor: esDueno ? "dueno" : "cuidador",
      motivoCancelacion: typeof d.motivo === "string" ? d.motivo.slice(0, 300) : "",
      canceladoEn: FieldValue.serverTimestamp(),
    });
    tx.set(db.collection(COL.chats).doc(ref.id), { abierto: false }, { merge: true });
    tx.set(ref.collection(COL.eventos).doc(), {
      tipo: "cancelado",
      por: uid,
      creadoEn: FieldValue.serverTimestamp(),
    });
  });
  if (otro) {
    await notificar(otro, "Servicio cancelado", "La otra parte canceló el servicio", {
      tipo: "servicio_cancelado",
      servicioId: d.servicioId!,
    });
  }
  return { ok: true };
});

/** HU-14: el dueño sube el precio si no llegan ofertas. */
export const subirPrecio = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const d = datos<{ servicioId: string; precio: number }>(req);
  const precio = Number(d.precio);
  if (!Number.isInteger(precio) || precio % 100 !== 0) falla("invalid-argument", "El precio va en soles enteros");
  await db.runTransaction(async (tx) => {
    const ref = refServicio(String(d.servicioId));
    const snap = await tx.get(ref);
    if (!snap.exists || snap.get("duenoId") !== uid) falla("not-found", "Solicitud no encontrada");
    if (snap.get("estado") !== "buscando" || snap.get("modalidad") !== "oferta") {
      falla("failed-precondition", "Esta solicitud ya no admite cambios de precio");
    }
    if (precio <= snap.get("precioOfrecido")) falla("invalid-argument", "El nuevo precio debe ser mayor");
    const ahora = new Date();
    tx.update(ref, {
      precioOfrecido: precio,
      sugerenciaSubirPrecioEnviada: false,
      expiraEn: ts(new Date(ahora.getTime() + SOLICITUD_EXPIRA_MINUTOS * 60_000)),
      ultimoCambioPrecioEn: ts(ahora),
    });
  });
  return { ok: true };
});
