import { COL, db } from "./firebase";

/**
 * Encola un correo en la colección `mail`, que procesa la extensión oficial
 * "Trigger Email from Firestore" (firebase/firestore-send-email).
 * Instálala con: firebase ext:install firebase/firestore-send-email
 */
export async function encolarCorreo(para: string, asunto: string, html: string): Promise<void> {
  await db.collection(COL.correo).add({ to: para, message: { subject: asunto, html } });
}
