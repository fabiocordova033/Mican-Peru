/**
 * HU-19: chat dentro de la app. La app escribe los mensajes de texto
 * directamente (las reglas validan participante y chat abierto); este
 * trigger actualiza el contador de no leídos y envía la notificación.
 */
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { COL, FieldValue, REGION, db } from "../lib/firebase";
import { notificar } from "../lib/notificaciones";

export const alCrearMensaje = onDocumentCreated(
  { region: REGION, document: `${COL.chats}/{chatId}/${COL.mensajes}/{mensajeId}` },
  async (event) => {
    const m = event.data?.data();
    if (!m) return;
    const chatRef = db.collection(COL.chats).doc(event.params.chatId);
    const chat = await chatRef.get();
    const participantes = (chat.get("participantes") ?? []) as string[];
    const destinatarios = participantes.filter((p) => p !== m.autorId);
    const cambios: Record<string, unknown> = {
      ultimoMensaje: { texto: m.tipo === "foto" ? "📷 Foto" : String(m.texto ?? "").slice(0, 80), autorId: m.autorId },
      actualizadoEn: FieldValue.serverTimestamp(),
    };
    for (const d of destinatarios) cambios[`noLeidos.${d}`] = FieldValue.increment(1);
    await chatRef.update(cambios);
    if (m.tipo !== "foto") {
      await Promise.all(
        destinatarios.map((d) =>
          notificar(d, "Nuevo mensaje", String(m.texto ?? "").slice(0, 80), { tipo: "mensaje", servicioId: event.params.chatId }),
        ),
      );
    }
  },
);
