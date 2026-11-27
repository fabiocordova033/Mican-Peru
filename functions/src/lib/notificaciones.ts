import { logger } from "firebase-functions/v2";
import { COL, db, messaging } from "./firebase";

/**
 * Envía una notificación push (FCM) a todos los dispositivos del usuario.
 * La app guarda su token en usuarios/{uid}/dispositivos/{token}.
 * Los tokens inválidos se borran.
 */
export async function notificar(
  uid: string,
  titulo: string,
  cuerpo: string,
  data: Record<string, string> = {},
): Promise<void> {
  const snap = await db.collection(COL.usuarios).doc(uid).collection(COL.dispositivos).get();
  const tokens = snap.docs.map((d) => d.id);
  if (!tokens.length) return;
  try {
    const res = await messaging.sendEachForMulticast({
      tokens,
      notification: { title: titulo, body: cuerpo },
      data,
    });
    const invalidos = res.responses
      .map((r, i) => (!r.success && r.error?.code === "messaging/registration-token-not-registered" ? tokens[i] : null))
      .filter((t): t is string => !!t);
    await Promise.all(invalidos.map((t) => snap.docs.find((d) => d.id === t)?.ref.delete()));
  } catch (e) {
    // Una notificación fallida nunca debe romper la operación principal.
    logger.warn("No se pudo notificar", { uid, e });
  }
}
