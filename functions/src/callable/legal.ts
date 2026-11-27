/**
 * Épica 8: legal y privacidad (Perú). HU-30, HU-31, HU-32.
 * Ley 29733 (datos personales), Ley 29571 (consumidor, Libro de
 * Reclamaciones) y reglas de las tiendas de apps (eliminar cuenta).
 */
import { onCall } from "firebase-functions/v2/https";
import {
  ARCO_PLAZO_DIAS_HABILES,
  ELIMINACION_GRACIA_DIAS,
  RECLAMO_PLAZO_DIAS_HABILES,
  TEXTO_CONFIRMAR_ELIMINACION,
} from "../config/reglas";
import { sumarDias, sumarDiasHabiles } from "../dominio/fechas";
import { ESTADOS_ACTIVOS } from "../dominio/servicio";
import { textoRequerido } from "../dominio/validaciones";
import { leerSaldo } from "../lib/billetera";
import { siguienteCorrelativo } from "../lib/contadores";
import { encolarCorreo } from "../lib/correo";
import { datos, falla, requiereUsuario } from "../lib/errores";
import { COL, FieldValue, REGION, auth, db, ts } from "../lib/firebase";
import { refPerfil, refUsuario } from "../lib/usuarios";

/** Datos del proveedor que la ley pide mostrar (HU-31). Completar al constituir la empresa. */
export const EMPRESA = {
  razonSocial: process.env.EMPRESA_RAZON_SOCIAL ?? "Mican Peru S.A.C. (por constituir)",
  ruc: process.env.EMPRESA_RUC ?? "00000000000",
  domicilio: process.env.EMPRESA_DOMICILIO ?? "Lima, Perú",
  correoPrivacidad: process.env.CORREO_PRIVACIDAD ?? "privacidad@mican.pe",
};

export const datosEmpresa = onCall({ region: REGION }, async () => EMPRESA);

/**
 * HU-30: Libro de Reclamaciones virtual. Devuelve la constancia con número
 * correlativo y el plazo de 15 días hábiles; también se envía por correo.
 */
export const presentarReclamo = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const d = datos<{
    tipo: "reclamo" | "queja";
    nombre: string;
    documento: string;
    correo: string;
    domicilio: string;
    servicioId: string;
    montoReclamado: number;
    detalle: string;
    pedido: string;
  }>(req);
  if (d.tipo !== "reclamo" && d.tipo !== "queja") falla("invalid-argument", "Elige reclamo o queja");
  const nombre = textoRequerido(d.nombre, 120);
  const documento = textoRequerido(d.documento, 20);
  const detalle = textoRequerido(d.detalle, 3000);
  const pedido = textoRequerido(d.pedido, 1500);
  const correo = typeof d.correo === "string" && /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(d.correo) ? d.correo : null;
  if (!nombre || !documento || !detalle || !pedido || !correo) {
    falla("invalid-argument", "Completa tus datos, el detalle, tu pedido y un correo válido");
  }
  if (d.servicioId !== undefined) {
    const s = await db.collection(COL.servicios).doc(String(d.servicioId)).get();
    if (!s.exists || (s.get("duenoId") !== uid && s.get("cuidadorId") !== uid)) {
      falla("not-found", "Servicio no encontrado");
    }
  }
  const ahora = new Date();
  const venceEn = sumarDiasHabiles(ahora, RECLAMO_PLAZO_DIAS_HABILES);
  const ref = db.collection(COL.reclamos).doc();
  const numero = await db.runTransaction(async (tx) => {
    const n = await siguienteCorrelativo(tx, "reclamos", "R");
    tx.set(ref, {
      numero: n,
      uid,
      tipo: d.tipo,
      consumidor: { nombre, documento, correo, domicilio: typeof d.domicilio === "string" ? d.domicilio.slice(0, 200) : "" },
      servicioId: d.servicioId ?? null,
      montoReclamado: Number.isInteger(d.montoReclamado) ? d.montoReclamado : null,
      detalle,
      pedido,
      proveedor: EMPRESA,
      estado: "recibido",
      respuesta: null,
      creadoEn: ts(ahora),
      venceEn: ts(venceEn),
      // Se conservan al menos 2 años (Ley 29571), aunque el usuario elimine su cuenta.
      conservarHasta: ts(sumarDias(ahora, 2 * 365)),
    });
    return n;
  });
  await encolarCorreo(
    correo,
    `Constancia de ${d.tipo} ${numero} · Libro de Reclamaciones Mican`,
    `<p>Registramos tu ${d.tipo} con el número <b>${numero}</b>.</p>
     <p>Te responderemos en un plazo máximo de ${RECLAMO_PLAZO_DIAS_HABILES} días hábiles
     (hasta el ${venceEn.toISOString().slice(0, 10)}).</p>
     <p><b>Detalle:</b> ${escaparHtml(detalle)}</p><p><b>Pedido:</b> ${escaparHtml(pedido)}</p>
     <p>${EMPRESA.razonSocial} · RUC ${EMPRESA.ruc} · ${EMPRESA.domicilio}</p>`,
  );
  return { numero, venceEn: venceEn.getTime(), plazoDiasHabiles: RECLAMO_PLAZO_DIAS_HABILES };
});

function escaparHtml(t: string): string {
  return t.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);
}

/** HU-31: solicitud ARCO (acceso, rectificación, cancelación, oposición). */
export const solicitarArco = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const d = datos<{ derecho: "acceso" | "rectificacion" | "cancelacion" | "oposicion"; detalle: string }>(req);
  if (!["acceso", "rectificacion", "cancelacion", "oposicion"].includes(String(d.derecho))) {
    falla("invalid-argument", "Elige el derecho que quieres ejercer");
  }
  const detalle = textoRequerido(d.detalle, 2000);
  if (!detalle) falla("invalid-argument", "Cuéntanos qué necesitas");
  const ahora = new Date();
  const venceEn = sumarDiasHabiles(ahora, ARCO_PLAZO_DIAS_HABILES);
  const ref = await db.collection(COL.solicitudesArco).add({
    uid,
    derecho: d.derecho,
    detalle,
    estado: "recibida",
    creadoEn: ts(ahora),
    venceEn: ts(venceEn),
  });
  return { id: ref.id, venceEn: venceEn.getTime() };
});

/** HU-31: descargar mis datos (derecho de acceso) en JSON. */
export const exportarMisDatos = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const [usuario, perfil, mascotas, billetera, movimientos, comoDueno, comoCuidador, reclamos, arco] = await Promise.all([
    refUsuario(uid).get(),
    refPerfil(uid).get(),
    db.collection(COL.mascotas).where("duenoId", "==", uid).get(),
    db.collection(COL.billeteras).doc(uid).get(),
    db.collection(COL.billeteras).doc(uid).collection(COL.movimientos).get(),
    db.collection(COL.servicios).where("duenoId", "==", uid).get(),
    db.collection(COL.servicios).where("cuidadorId", "==", uid).get(),
    db.collection(COL.reclamos).where("uid", "==", uid).get(),
    db.collection(COL.solicitudesArco).where("uid", "==", uid).get(),
  ]);
  const verificacion = await db.collection(COL.verificaciones).doc(uid).get();
  const json = (v: unknown) => JSON.parse(JSON.stringify(v ?? null));
  return {
    generadoEn: new Date().toISOString(),
    titular: EMPRESA,
    cuenta: json(usuario.data()),
    perfilPublico: json(perfil.data()),
    verificacion: json(verificacion.exists ? { estado: verificacion.get("estado"), documentos: verificacion.get("documentos") } : null),
    mascotas: mascotas.docs.map((m) => json({ id: m.id, ...m.data() })),
    billetera: json(billetera.data()),
    movimientos: movimientos.docs.map((m) => json({ id: m.id, ...m.data() })),
    servicios: [...comoDueno.docs, ...comoCuidador.docs].map((s) => json({ id: s.id, ...s.data() })),
    reclamos: reclamos.docs.map((r) => json({ id: r.id, ...r.data() })),
    solicitudesArco: arco.docs.map((r) => json({ id: r.id, ...r.data() })),
  };
});

/**
 * HU-32: eliminar cuenta. No se puede con un servicio en curso; si es
 * cuidador con saldo, primero se le ofrece la devolución. Se confirma
 * escribiendo ELIMINAR. La cuenta queda desactivada y se borra en 30 días
 * (job `purgarCuentasEliminadas`); mientras tanto se puede recuperar.
 */
export const eliminarCuenta = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const d = datos<{ confirmacion: string; renunciarSaldo: boolean }>(req);
  if (d.confirmacion !== TEXTO_CONFIRMAR_ELIMINACION) {
    falla("invalid-argument", `Escribe ${TEXTO_CONFIRMAR_ELIMINACION} para confirmar`);
  }
  const ahora = new Date();
  const eliminarEn = sumarDias(ahora, ELIMINACION_GRACIA_DIAS);
  await db.runTransaction(async (tx) => {
    const [usuario, comoDueno, comoCuidador, buscando, saldo] = await Promise.all([
      tx.get(refUsuario(uid)),
      tx.get(db.collection(COL.servicios).where("duenoId", "==", uid).where("estado", "in", ESTADOS_ACTIVOS).limit(1)),
      tx.get(db.collection(COL.servicios).where("cuidadorId", "==", uid).where("estado", "in", ESTADOS_ACTIVOS).limit(1)),
      tx.get(db.collection(COL.servicios).where("duenoId", "==", uid).where("estado", "==", "buscando")),
      leerSaldo(tx, uid),
    ]);
    if (!usuario.exists) falla("not-found", "Cuenta no encontrada");
    if (usuario.get("estadoCuenta") === "eliminacion_pendiente") falla("failed-precondition", "Tu cuenta ya está en proceso de eliminación");
    if (!comoDueno.empty || !comoCuidador.empty) falla("failed-precondition", "Tienes un servicio en curso. Termínalo antes de eliminar tu cuenta");
    if (saldo > 0 && d.renunciarSaldo !== true) {
      falla("failed-precondition", "Tienes saldo a favor. Pide la devolución antes de eliminar tu cuenta", {
        saldo,
        ofrecerDevolucion: true,
      });
    }
    for (const s of buscando.docs) tx.update(s.ref, { estado: "cancelado", canceladoPor: "sistema", canceladoEn: ts(ahora) });
    tx.update(usuario.ref, {
      estadoCuenta: "eliminacion_pendiente",
      eliminacionSolicitadaEn: ts(ahora),
      eliminarEn: ts(eliminarEn),
    });
    tx.update(refPerfil(uid), { disponible: false, oculto: true });
  });
  // Cierra las sesiones en otros dispositivos.
  await auth.revokeRefreshTokens(uid);
  return {
    eliminarEn: eliminarEn.getTime(),
    seConserva: [
      "Comprobantes de pago (obligación tributaria, hasta 5 años)",
      "Reclamos y quejas (Ley 29571, al menos 2 años)",
    ],
  };
});

/** HU-32: recuperar la cuenta durante los 30 días de gracia. */
export const recuperarCuenta = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  await db.runTransaction(async (tx) => {
    const u = await tx.get(refUsuario(uid));
    if (u.get("estadoCuenta") !== "eliminacion_pendiente") falla("failed-precondition", "Tu cuenta no está en eliminación");
    tx.update(u.ref, {
      estadoCuenta: "activa",
      eliminacionSolicitadaEn: FieldValue.delete(),
      eliminarEn: FieldValue.delete(),
    });
    tx.update(refPerfil(uid), { oculto: false });
  });
  return { ok: true };
});
