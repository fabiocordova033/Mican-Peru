/**
 * Un solo trigger de Storage que reparte según la carpeta:
 *  - verificaciones/{uid}/{tipo}       -> documentos del cuidador (HU-03)
 *  - servicios/{servicioId}/fotos/{f}  -> fotos del servicio (HU-17)
 */
import { logger } from "firebase-functions/v2";
import { onObjectFinalized } from "firebase-functions/v2/storage";
import { procesarDocumentoSubido } from "../callable/verificacion";
import { COL, FieldValue, REGION, db } from "../lib/firebase";
import { notificar } from "../lib/notificaciones";

export const alSubirArchivo = onObjectFinalized({ region: REGION }, async (event) => {
  const nombre = event.data.name ?? "";
  if (nombre.startsWith("verificaciones/")) return procesarDocumentoSubido(nombre);
  const foto = /^servicios\/([^/]+)\/fotos\/([^/]+)$/.exec(nombre);
  if (foto) return registrarFoto(foto[1], nombre, event.data.metadata?.subidoPor);
});

/**
 * HU-17: registra la foto en servicios/{id}/fotos, la manda al chat y avisa
 * al dueño. Las reglas de Storage ya validaron que la sube el cuidador
 * asignado con el servicio en curso.
 */
async function registrarFoto(servicioId: string, ruta: string, subidoPor?: string) {
  const ref = db.collection(COL.servicios).doc(servicioId);
  const s = await ref.get();
  if (!s.exists) {
    logger.warn("Foto de un servicio inexistente", { ruta });
    return;
  }
  const cuidadorId = s.get("cuidadorId");
  if (subidoPor && subidoPor !== cuidadorId) logger.warn("Foto con autor inesperado", { ruta, subidoPor });
  const batch = db.batch();
  batch.set(ref.collection(COL.fotos).doc(), { ruta, subidoPor: cuidadorId, creadoEn: FieldValue.serverTimestamp() });
  batch.set(db.collection(COL.chats).doc(servicioId).collection(COL.mensajes).doc(), {
    autorId: cuidadorId,
    tipo: "foto",
    ruta,
    texto: "",
    creadoEn: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  await notificar(s.get("duenoId"), "Nueva foto", `Mira cómo está ${s.get("mascota.nombre")}`, {
    tipo: "foto",
    servicioId,
  });
}
