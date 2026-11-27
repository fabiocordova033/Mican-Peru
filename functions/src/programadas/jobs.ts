/**
 * Tareas programadas (Cloud Scheduler). Hora de Lima (UTC-5).
 */
import { logger } from "firebase-functions/v2";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { SUGERIR_SUBIR_PRECIO_SEGUNDOS } from "../config/reglas";
import { revelarCalificaciones } from "../lib/calificaciones";
import { COL, REGION, Timestamp, auth, db, storage, ts } from "../lib/firebase";
import { notificar } from "../lib/notificaciones";

const opciones = { region: REGION, timeZone: "America/Lima" };

/** Procesa una consulta en lotes de hasta 400 escrituras. */
async function enLotes(
  docs: FirebaseFirestore.QueryDocumentSnapshot[],
  fn: (b: FirebaseFirestore.WriteBatch, d: FirebaseFirestore.QueryDocumentSnapshot) => void,
) {
  for (let i = 0; i < docs.length; i += 400) {
    const b = db.batch();
    docs.slice(i, i + 400).forEach((d) => fn(b, d));
    await b.commit();
  }
}

/**
 * Cada minuto:
 *  - HU-13: vence las ofertas de más de 60 s (además, `aceptarOferta`
 *    rechaza las vencidas al instante, así que no depende de este job).
 *  - HU-14: si en 3 min no llegó ninguna oferta, sugiere subir el precio.
 *  - Cierra las solicitudes que nadie tomó.
 */
export const cadaMinuto = onSchedule({ ...opciones, schedule: "every 1 minutes" }, async () => {
  const ahora = Timestamp.now();

  const ofertas = await db
    .collectionGroup(COL.ofertas)
    .where("estado", "==", "pendiente")
    .where("expiraEn", "<", ahora)
    .get();
  await enLotes(ofertas.docs, (b, d) => b.update(d.ref, { estado: "expirada" }));

  const buscando = await db.collection(COL.servicios).where("estado", "==", "buscando").get();
  const vencidas = buscando.docs.filter((d) => d.get("expiraEn").toMillis() < ahora.toMillis());
  await enLotes(vencidas, (b, d) => b.update(d.ref, { estado: "expirado" }));
  await Promise.all(
    vencidas.map((d) =>
      notificar(d.get("duenoId"), "Sin cuidador por ahora", "Tu solicitud venció. Prueba con otro precio u horario.", {
        tipo: "solicitud_expirada",
        servicioId: d.id,
      }),
    ),
  );

  const limite = ahora.toMillis() - SUGERIR_SUBIR_PRECIO_SEGUNDOS * 1000;
  const sinOfertas = buscando.docs.filter((d) => {
    if (vencidas.includes(d) || d.get("modalidad") !== "oferta") return false;
    if (d.get("sugerenciaSubirPrecioEnviada") || d.get("ofertasRecibidas") > 0) return false;
    const desde = (d.get("ultimoCambioPrecioEn") ?? d.get("creadoEn")) as Timestamp;
    return desde.toMillis() < limite;
  });
  await enLotes(sinOfertas, (b, d) => b.update(d.ref, { sugerenciaSubirPrecioEnviada: true }));
  await Promise.all(
    sinOfertas.map((d) =>
      notificar(d.get("duenoId"), "¿Subes un poco el precio?", "Aún no llegan ofertas. Subir el precio ayuda a encontrar cuidador.", {
        tipo: "sugerir_subir_precio",
        servicioId: d.id,
      }),
    ),
  );
  logger.info("cadaMinuto", { ofertas: ofertas.size, vencidas: vencidas.length, sugerencias: sinOfertas.length });
});

/**
 * Cada hora:
 *  - HU-19: cierra los chats 24 h después de terminar.
 *  - HU-24: revela las calificaciones cuyo plazo de 7 días venció.
 */
export const cadaHora = onSchedule({ ...opciones, schedule: "every 60 minutes" }, async () => {
  const ahora = Timestamp.now();
  const chats = await db.collection(COL.chats).where("abierto", "==", true).where("cierraEn", "<", ahora).get();
  await enLotes(chats.docs, (b, d) => b.update(d.ref, { abierto: false }));

  const pendientes = await db
    .collection(COL.servicios)
    .where("estado", "==", "completado")
    .where("calificacionesReveladas", "==", false)
    .where("calificarHasta", "<", ahora)
    .limit(200)
    .get();
  for (const s of pendientes.docs) {
    await db.runTransaction(async (tx) => {
      const cals = await tx.get(s.ref.collection(COL.calificaciones));
      const escribir = await revelarCalificaciones(tx, s.ref, cals.docs);
      escribir();
    });
  }
  logger.info("cadaHora", { chats: chats.size, revelados: pendientes.size });
});

/**
 * Cada día a las 3:00 a. m.:
 *  - HU-27: vence Premium (sin renovación) y avisa de la renovación.
 *  - HU-04: avisa de verificaciones que pasaron las 48 h.
 *  - HU-32: borra las cuentas cuyo plazo de 30 días terminó.
 */
export const diario = onSchedule({ ...opciones, schedule: "0 3 * * *" }, async () => {
  const ahora = Timestamp.now();

  const premiumVencido = await db
    .collection(COL.usuarios)
    .where("plan", "==", "premium")
    .where("premiumHasta", "<", ahora)
    .get();
  await enLotes(premiumVencido.docs, (b, d) => b.update(d.ref, { plan: "gratis", enPrueba: false }));
  await Promise.all(
    premiumVencido.docs
      .filter((d) => d.get("renovacionAutomatica"))
      .map((d) =>
        // TODO producción: cobro recurrente con la tarjeta tokenizada de la pasarela.
        notificar(d.id, "Renueva Premium", "Tu periodo terminó. Renueva para seguir sin anuncios.", { tipo: "renovar_premium" }),
      ),
  );

  const atrasadas = await db
    .collection(COL.verificaciones)
    .where("estado", "==", "en_revision")
    .where("venceRevisionEn", "<", ahora)
    .get();
  if (!atrasadas.empty) logger.warn("Verificaciones con más de 48 h", { uids: atrasadas.docs.map((d) => d.id) });

  const aBorrar = await db
    .collection(COL.usuarios)
    .where("estadoCuenta", "==", "eliminacion_pendiente")
    .where("eliminarEn", "<", ahora)
    .limit(100)
    .get();
  for (const u of aBorrar.docs) {
    try {
      await purgarCuenta(u.id);
    } catch (e) {
      logger.error("No se pudo purgar la cuenta", { uid: u.id, e: String(e) });
    }
  }
});

/**
 * Borra los datos personales de una cuenta. Se conservan, sin datos de
 * contacto, los movimientos de billetera (comprobantes, obligación
 * tributaria) y los reclamos (Ley 29571).
 */
export async function purgarCuenta(uid: string): Promise<void> {
  const anonimo = "Usuario eliminado";
  const [mascotas, comoDueno, comoCuidador] = await Promise.all([
    db.collection(COL.mascotas).where("duenoId", "==", uid).get(),
    db.collection(COL.servicios).where("duenoId", "==", uid).get(),
    db.collection(COL.servicios).where("cuidadorId", "==", uid).get(),
  ]);
  await enLotes(mascotas.docs, (b, d) => b.delete(d.ref));
  await enLotes(comoDueno.docs, (b, d) => b.update(d.ref, { duenoNombre: anonimo, "origen.direccion": "", indicaciones: "" }));
  await enLotes(comoCuidador.docs, (b, d) => b.update(d.ref, { cuidadorNombre: anonimo }));
  for (const s of [...comoDueno.docs, ...comoCuidador.docs]) {
    await db.recursiveDelete(s.ref.collection(COL.privado));
    await db.recursiveDelete(s.ref.collection(COL.ruta));
  }
  await db.recursiveDelete(db.collection(COL.verificaciones).doc(uid));
  await db.recursiveDelete(db.collection(COL.perfiles).doc(uid));
  await db.collection("ubicacionesCuidadores").doc(uid).delete();
  await db.collection(COL.usuarios).doc(uid).collection(COL.dispositivos).get().then((s) => enLotes(s.docs, (b, d) => b.delete(d.ref)));
  await db.collection(COL.usuarios).doc(uid).set({
    estadoCuenta: "eliminada",
    eliminadaEn: ts(new Date()),
  });
  await storage.bucket().deleteFiles({ prefix: `verificaciones/${uid}/` });
  await storage.bucket().deleteFiles({ prefix: `usuarios/${uid}/` });
  await auth.deleteUser(uid).catch((e) => {
    if (e?.code !== "auth/user-not-found") throw e;
  });
  logger.info("Cuenta purgada", { uid });
}
