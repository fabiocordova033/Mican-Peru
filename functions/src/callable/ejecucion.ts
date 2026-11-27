/**
 * Épica 4 y 5: ejecución del servicio y cobro de la comisión.
 * HU-15, HU-16, HU-17, HU-18, HU-22, HU-23.
 *
 * - La ruta en vivo (HU-16) la escribe la app del cuidador directamente en
 *   servicios/{id}/ruta cada 10 s; las reglas solo lo permiten al cuidador
 *   asignado y con el servicio en curso. El dueño la escucha en tiempo real.
 * - Las fotos (HU-17) se suben a Storage en servicios/{id}/fotos/ y el
 *   trigger de Storage las registra y las manda al chat.
 */
import { onCall } from "firebase-functions/v2/https";
import { CHAT_ABIERTO_HORAS, CONTACTO_VISIBLE_HORAS, PLAZO_CALIFICAR_DIAS, SALDO_MINIMO_CENTIMOS } from "../config/reglas";
import { calcularComision, formatearSoles } from "../dominio/dinero";
import { sumarDias, sumarHoras } from "../dominio/fechas";
import { Punto, distanciaRutaKm, esPuntoValido, puedeIniciar } from "../dominio/geo";
import { puedeTransicionar } from "../dominio/servicio";
import { aplicarMovimiento, leerSaldo } from "../lib/billetera";
import { datos, falla, requiereUsuario } from "../lib/errores";
import { COL, FieldValue, REGION, db, ts } from "../lib/firebase";
import { notificar } from "../lib/notificaciones";
import { refPerfil } from "../lib/usuarios";

const refServicio = (id: string) => db.collection(COL.servicios).doc(id);

/** HU-15: "Iniciar" solo a menos de 100 m del punto de recojo. */
export const iniciarServicio = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const d = datos<{ servicioId: string; lat: number; lng: number }>(req);
  const ubicacion = { lat: d.lat, lng: d.lng };
  if (!esPuntoValido(ubicacion)) {
    // HU-29: sin permiso de ubicación el cuidador no puede iniciar.
    falla("failed-precondition", "Activa tu ubicación para iniciar el servicio");
  }
  let duenoId = "";
  await db.runTransaction(async (tx) => {
    const ref = refServicio(String(d.servicioId));
    const snap = await tx.get(ref);
    if (!snap.exists || snap.get("cuidadorId") !== uid) falla("not-found", "Servicio no encontrado");
    const s = snap.data()!;
    duenoId = s.duenoId;
    if (!puedeTransicionar(s.estado, "en_curso")) falla("failed-precondition", "El servicio no está confirmado");
    if (!puedeIniciar(ubicacion, s.origen)) {
      falla("failed-precondition", "Acércate al punto de recojo (a menos de 100 m) para iniciar");
    }
    tx.update(ref, { estado: "en_curso", iniciadoEn: FieldValue.serverTimestamp() });
    tx.set(ref.collection(COL.ruta).doc(), { ...ubicacion, registradoEn: FieldValue.serverTimestamp() });
    tx.set(ref.collection(COL.eventos).doc(), { tipo: "iniciado", por: uid, creadoEn: FieldValue.serverTimestamp() });
  });
  await notificar(duenoId, "Servicio iniciado", "Tu cuidador empezó el servicio", {
    tipo: "servicio_iniciado",
    servicioId: String(d.servicioId),
  });
  return { ok: true };
});

/**
 * HU-15 + HU-22: al finalizar, el dueño recibe el resumen y la comisión se
 * descuenta del saldo del cuidador. En visitas a domicilio debe haber al
 * menos 1 foto (HU-17).
 */
export const finalizarServicio = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const { servicioId } = datos<{ servicioId: string }>(req);
  if (typeof servicioId !== "string") falla("invalid-argument", "Falta el servicio");
  const ref = refServicio(servicioId);

  // Lecturas que no necesitan estar en la transacción (ruta y fotos son de solo escritura incremental).
  const [rutaSnap, fotosCount] = await Promise.all([
    ref.collection(COL.ruta).orderBy("registradoEn").get(),
    ref.collection(COL.fotos).count().get(),
  ]);
  const ruta: Punto[] = rutaSnap.docs.map((p) => ({ lat: p.get("lat"), lng: p.get("lng") }));
  const distanciaKm = Math.round(distanciaRutaKm(ruta) * 100) / 100;
  const fotos = fotosCount.data().count;

  const ahora = new Date();
  const resumen = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists || snap.get("cuidadorId") !== uid) falla("not-found", "Servicio no encontrado");
    const s = snap.data()!;
    if (!puedeTransicionar(s.estado, "completado")) falla("failed-precondition", "El servicio no está en curso");
    if (s.tipo === "visita" && fotos < 1) {
      falla("failed-precondition", "Envía al menos 1 foto antes de finalizar la visita");
    }
    const saldo = await leerSaldo(tx, uid);
    const perfilRef = refPerfil(uid);

    const comision = calcularComision(s.precioFinal, s.comisionTasa);
    const iniciado: Date = s.iniciadoEn.toDate();
    const duracionRealMin = Math.max(1, Math.round((ahora.getTime() - iniciado.getTime()) / 60_000));
    const r = {
      duracionRealMin,
      duracionContratadaMin: s.duracionMin,
      distanciaKm: s.tipo === "transporte" && distanciaKm === 0 ? s.distanciaKm : distanciaKm,
      precio: s.precioFinal,
      metodoPago: s.metodoPago,
      comision,
      recibeCuidador: s.precioFinal - comision,
      fotos,
    };
    const { saldo: saldoNuevo } = aplicarMovimiento(tx, uid, saldo, {
      tipo: "comision",
      monto: -comision,
      descripcion: `Comisión ${Math.round(s.comisionTasa * 100)}% · ${s.mascota.nombre}`,
      servicioId,
      mascotaNombre: s.mascota.nombre,
      tasa: s.comisionTasa,
    });
    tx.update(ref, {
      estado: "completado",
      finalizadoEn: ts(ahora),
      resumen: r,
      comision,
      chatCierraEn: ts(sumarHoras(ahora, CHAT_ABIERTO_HORAS)),
      calificarHasta: ts(sumarDias(ahora, PLAZO_CALIFICAR_DIAS)),
      calificacionesReveladas: false,
    });
    tx.update(ref.collection(COL.privado).doc("contacto"), {
      visibleHasta: ts(sumarHoras(ahora, CONTACTO_VISIBLE_HORAS)),
    });
    tx.set(db.collection(COL.chats).doc(servicioId), { cierraEn: ts(sumarHoras(ahora, CHAT_ABIERTO_HORAS)) }, { merge: true });
    tx.update(perfilRef, { serviciosCompletados: FieldValue.increment(1) });
    tx.set(ref.collection(COL.eventos).doc(), { tipo: "finalizado", por: uid, creadoEn: ts(ahora) });
    return { ...r, duenoId: s.duenoId as string, saldoNuevo };
  });

  const { duenoId, saldoNuevo, ...paraDueno } = resumen;
  await notificar(
    duenoId,
    "Servicio finalizado",
    `Paga ${formatearSoles(paraDueno.precio)} por ${paraDueno.metodoPago}. ¡Califica a tu cuidador!`,
    { tipo: "servicio_finalizado", servicioId },
  );
  if (saldoNuevo < SALDO_MINIMO_CENTIMOS) {
    await notificar(uid, "Recarga tu saldo", `Tu saldo es ${formatearSoles(saldoNuevo)}. Recarga para seguir recibiendo solicitudes.`, {
      tipo: "saldo_bajo",
    });
  }
  return { ...paraDueno, saldo: saldoNuevo };
});

/**
 * HU-18: botón de emergencia. Queda registrado en el historial del servicio
 * y abre un ticket urgente para soporte. Devuelve a quién llamar.
 */
export const reportarEmergencia = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const d = datos<{ servicioId: string; detalle: string; lat: number; lng: number }>(req);
  const ref = refServicio(String(d.servicioId));
  const [snap, contacto] = await Promise.all([ref.get(), ref.collection(COL.privado).doc("contacto").get()]);
  if (!snap.exists) falla("not-found", "Servicio no encontrado");
  const s = snap.data()!;
  if (s.duenoId !== uid && s.cuidadorId !== uid) falla("permission-denied", "No participas en este servicio");
  const esDueno = s.duenoId === uid;
  const ubicacion = esPuntoValido({ lat: d.lat, lng: d.lng }) ? { lat: d.lat, lng: d.lng } : null;
  const emergencia = {
    servicioId: ref.id,
    reportadoPor: uid,
    rol: esDueno ? "dueno" : "cuidador",
    duenoId: s.duenoId,
    cuidadorId: s.cuidadorId,
    detalle: typeof d.detalle === "string" ? d.detalle.slice(0, 1000) : "",
    ubicacion,
    estado: "abierta",
    creadoEn: FieldValue.serverTimestamp(),
  };
  const batch = db.batch();
  batch.set(db.collection(COL.emergencias).doc(), emergencia);
  batch.set(ref.collection(COL.eventos).doc(), { tipo: "emergencia", por: uid, creadoEn: FieldValue.serverTimestamp() });
  await batch.commit();
  const otro = esDueno ? s.cuidadorId : s.duenoId;
  if (otro) {
    await notificar(otro, "Emergencia reportada", "La otra parte activó el botón de emergencia", {
      tipo: "emergencia",
      servicioId: ref.id,
    });
  }
  return {
    llamarA: {
      otraParte: contacto.exists ? (esDueno ? contacto.get("telefonoCuidador") : contacto.get("telefonoDueno")) : null,
      soporteMican: process.env.TELEFONO_SOPORTE ?? null,
      // La veterinaria más cercana la busca la app con el mapa (Places API).
    },
  };
});
