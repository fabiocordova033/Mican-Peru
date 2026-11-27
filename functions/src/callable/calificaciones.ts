/**
 * Épica 6: calificaciones y niveles. HU-24, HU-25.
 */
import { onCall } from "firebase-functions/v2/https";
import { NOMBRE_NIVEL } from "../dominio/textos";
import { progresoNivel } from "../dominio/niveles";
import { EntradaCalificacion, validarCalificacion } from "../dominio/validaciones";
import { coleccionCalificaciones, revelarCalificaciones, ResultadoRevelado } from "../lib/calificaciones";
import { datos, falla, requiereAdmin, requiereUsuario } from "../lib/errores";
import { COL, FieldValue, REGION, db, ts } from "../lib/firebase";
import { notificar } from "../lib/notificaciones";
import { refPerfil } from "../lib/usuarios";
import { calcularNivel } from "../dominio/niveles";

/**
 * HU-24: calificar de 1 a 5 estrellas con etiquetas, solo servicios
 * completados y hasta 7 días después. Queda oculta hasta que la otra parte
 * califique o pasen los 7 días. Con 1 o 2 estrellas se envía el motivo a
 * soporte.
 */
export const calificar = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const d = datos<EntradaCalificacion & { servicioId: string }>(req);
  const error = validarCalificacion(d as EntradaCalificacion);
  if (error) falla("invalid-argument", error);
  const servicioRef = db.collection(COL.servicios).doc(String(d.servicioId));
  const ahora = new Date();
  let revelado: ResultadoRevelado | null = null;

  await db.runTransaction(async (tx) => {
    const [servicio, existentes] = await Promise.all([
      tx.get(servicioRef),
      tx.get(coleccionCalificaciones(servicioRef)),
    ]);
    if (!servicio.exists) falla("not-found", "Servicio no encontrado");
    const s = servicio.data()!;
    const esDueno = s.duenoId === uid;
    if (!esDueno && s.cuidadorId !== uid) falla("permission-denied", "No participas en este servicio");
    if (s.estado !== "completado") falla("failed-precondition", "Solo puedes calificar servicios completados");
    if (s.calificarHasta.toDate() < ahora) falla("deadline-exceeded", "Pasaron los 7 días para calificar");
    if (existentes.docs.some((c) => c.id === uid)) falla("already-exists", "Ya calificaste este servicio");

    const ref = coleccionCalificaciones(servicioRef).doc(uid);
    const data = {
      autorId: uid,
      rolAutor: esDueno ? "dueno" : "cuidador",
      calificadoId: esDueno ? s.cuidadorId : s.duenoId,
      rolCalificado: esDueno ? "cuidador" : "dueno",
      estrellas: d.estrellas,
      etiquetas: d.etiquetas ?? [],
      comentario: (d.comentario ?? "").trim(),
      visible: false,
      creadoEn: ts(ahora),
    };
    const otraParteCalifico = existentes.docs.length > 0;
    if (otraParteCalifico) {
      const escribir = await revelarCalificaciones(tx, servicioRef, existentes.docs, { ref, data });
      revelado = escribir();
    } else {
      tx.set(ref, data);
    }
    if (d.estrellas! <= 2) {
      tx.set(db.collection(COL.soporte).doc(), {
        tipo: "calificacion_baja",
        servicioId: servicioRef.id,
        uid,
        calificadoId: data.calificadoId,
        estrellas: d.estrellas,
        motivo: String(d.motivo).slice(0, 1000),
        estado: "abierto",
        creadoEn: FieldValue.serverTimestamp(),
      });
    }
  });

  for (const c of (revelado as ResultadoRevelado | null)?.cambiosNivel ?? []) {
    await notificar(c.uid, "¡Nuevo nivel!", `Ahora eres ${NOMBRE_NIVEL[c.despues]}`, { tipo: "nivel" });
  }
  return { ok: true, revelada: !!revelado };
});

/** HU-25: "En Cuenta veo cuánto me falta para el siguiente nivel". */
export const miProgresoNivel = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const p = (await refPerfil(uid).get()).data();
  if (!p?.esCuidador) falla("permission-denied", "Solo para cuidadores");
  return progresoNivel({
    serviciosCompletados: p.serviciosCompletados ?? 0,
    calificacionPromedio: p.calificacionPromedio ?? 0,
    ultimoIncidente: p.ultimoIncidenteEn?.toDate() ?? null,
  });
});

/**
 * Soporte registra un incidente confirmado (p. ej. tras una emergencia). Afecta
 * el nivel Embajador, que pide 90 días sin incidentes.
 */
export const registrarIncidente = onCall({ region: REGION }, async (req) => {
  const admin = requiereAdmin(req);
  const d = datos<{ cuidadorId: string; emergenciaId: string; detalle: string }>(req);
  if (typeof d.cuidadorId !== "string") falla("invalid-argument", "Falta el cuidador");
  const ahora = new Date();
  await db.runTransaction(async (tx) => {
    const ref = refPerfil(d.cuidadorId!);
    const p = (await tx.get(ref)).data();
    if (!p) falla("not-found", "Cuidador no encontrado");
    const nivel = calcularNivel(
      { serviciosCompletados: p.serviciosCompletados ?? 0, calificacionPromedio: p.calificacionPromedio ?? 0, ultimoIncidente: ahora },
      ahora,
    );
    tx.update(ref, { ultimoIncidenteEn: ts(ahora), nivel });
    tx.set(db.collection("incidentes").doc(), {
      cuidadorId: d.cuidadorId,
      emergenciaId: d.emergenciaId ?? null,
      detalle: typeof d.detalle === "string" ? d.detalle.slice(0, 1000) : "",
      registradoPor: admin,
      creadoEn: ts(ahora),
    });
  });
  return { ok: true };
});
