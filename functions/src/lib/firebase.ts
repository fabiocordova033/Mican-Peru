import { initializeApp, getApps } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { getStorage } from "firebase-admin/storage";

if (!getApps().length) initializeApp();

export const db = getFirestore();
export const auth = getAuth();
export const messaging = getMessaging();
export const storage = getStorage();
export { FieldValue, Timestamp };

/** Región más cercana al Perú con Cloud Functions de 2.ª generación. */
export const REGION = "southamerica-east1";

/** Nombres de colecciones. Ver docs/modelo-de-datos.md. */
export const COL = {
  usuarios: "usuarios",
  dispositivos: "dispositivos",
  perfiles: "perfilesPublicos",
  mascotas: "mascotas",
  verificaciones: "verificaciones",
  billeteras: "billeteras",
  movimientos: "movimientos",
  pagos: "pagos",
  servicios: "servicios",
  ofertas: "ofertas",
  ruta: "ruta",
  fotos: "fotos",
  calificaciones: "calificaciones",
  resenas: "resenas",
  eventos: "eventos",
  privado: "privado",
  chats: "chats",
  mensajes: "mensajes",
  emergencias: "emergencias",
  reclamos: "reclamos",
  solicitudesArco: "solicitudesArco",
  soporte: "soporteTickets",
  suscripciones: "suscripciones",
  anuncios: "anuncios",
  contadores: "contadores",
  correo: "mail",
} as const;

export const ahora = () => new Date();
export const ts = (d: Date) => Timestamp.fromDate(d);
