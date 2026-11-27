/**
 * Épica 1: verificación del cuidador. HU-03, HU-04.
 *
 * Flujo:
 *  1. La app sube cada archivo a Storage en verificaciones/{uid}/{tipo}
 *     (tipo = dniFrente | dniReverso | antecedentes | selfie | cv).
 *  2. El trigger `alSubirArchivo` marca ese documento como "subido".
 *  3. El cuidador llama `enviarAVerificacion` cuando los 4 archivos
 *     obligatorios (DNI ambos lados, antecedentes y selfie) están subidos.
 *  4. Un administrador llama `revisarCuidador` para aprobar o rechazar.
 */
import { logger } from "firebase-functions/v2";
import { onCall } from "firebase-functions/v2/https";
import { PLAZO_REVISION_HORAS } from "../config/reglas";
import { sumarHoras } from "../dominio/fechas";
import { esDniValido, textoRequerido } from "../dominio/validaciones";
import { datos, falla, requiereAdmin, requiereUsuario } from "../lib/errores";
import { COL, FieldValue, REGION, db, storage, ts } from "../lib/firebase";
import { notificar } from "../lib/notificaciones";
import { refPerfil, refUsuario } from "../lib/usuarios";

export const DOCUMENTOS_OBLIGATORIOS = ["dniFrente", "dniReverso", "antecedentes", "selfie"] as const;
export const DOCUMENTOS = [...DOCUMENTOS_OBLIGATORIOS, "cv"] as const;
type TipoDocumento = (typeof DOCUMENTOS)[number];

const refVerificacion = (uid: string) => db.collection(COL.verificaciones).doc(uid);

/** Lee "verificaciones/{uid}/{tipo}[.ext]" y devuelve uid y tipo. */
export function parsearRutaDocumento(ruta: string): { uid: string; tipo: TipoDocumento } | null {
  const m = /^verificaciones\/([^/]+)\/([a-zA-Z]+)(\.[a-z0-9]+)?$/.exec(ruta);
  if (!m || !(DOCUMENTOS as readonly string[]).includes(m[2])) return null;
  return { uid: m[1], tipo: m[2] as TipoDocumento };
}

/** Marca el documento como subido en cuanto llega a Storage (ver triggers/storage.ts). */
export async function procesarDocumentoSubido(nombre: string): Promise<void> {
  const p = parsearRutaDocumento(nombre);
  if (!p) return;
  const ref = refVerificacion(p.uid);
  const snap = await ref.get();
  if (!snap.exists) {
    logger.warn("Documento sin verificación iniciada", p);
    return;
  }
  if (snap.get("estado") === "en_revision" || snap.get("estado") === "aprobada") {
    logger.warn("Se ignoró un archivo subido durante o después de la revisión", p);
    return;
  }
  await ref.update({
    [`documentos.${p.tipo}`]: "subido",
    [`archivos.${p.tipo}`]: nombre,
    actualizadoEn: FieldValue.serverTimestamp(),
  });
}

/** HU-03: "Enviar a revisión" solo con los obligatorios subidos. */
export const enviarAVerificacion = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const { dni } = datos<{ dni: string }>(req);
  if (typeof dni !== "string" || !esDniValido(dni)) falla("invalid-argument", "El DNI tiene 8 dígitos");
  const ahora = new Date();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(refVerificacion(uid));
    if (!snap.exists) falla("failed-precondition", "Activa tu perfil de cuidador primero");
    const v = snap.data()!;
    if (v.estado === "en_revision") falla("failed-precondition", "Tus documentos ya están en revisión");
    if (v.estado === "aprobada") falla("failed-precondition", "Ya estás verificado");
    const faltan = DOCUMENTOS_OBLIGATORIOS.filter((t) => v.documentos?.[t] !== "subido");
    if (faltan.length) falla("failed-precondition", "Faltan documentos obligatorios", { faltan });
    const documentos: Record<string, string> = {};
    for (const t of DOCUMENTOS) {
      documentos[t] = v.documentos?.[t] === "subido" ? "en_revision" : v.documentos?.[t] ?? "pendiente";
    }
    tx.update(refVerificacion(uid), {
      estado: "en_revision",
      documentos,
      motivoRechazo: null,
      enviadoEn: ts(ahora),
      venceRevisionEn: ts(sumarHoras(ahora, PLAZO_REVISION_HORAS)),
    });
    // El DNI solo se guarda en el documento privado del usuario (HU-05).
    tx.update(refUsuario(uid), { dni });
  });
  return { ok: true, plazoHoras: PLAZO_REVISION_HORAS };
});

/** HU-04: el administrador aprueba o rechaza. */
export const revisarCuidador = onCall({ region: REGION }, async (req) => {
  const adminUid = requiereAdmin(req);
  const d = datos<{
    uid: string;
    aprobar: boolean;
    motivo: string;
    documentosARehacer: TipoDocumento[];
  }>(req);
  if (typeof d.uid !== "string" || typeof d.aprobar !== "boolean") falla("invalid-argument", "Datos incompletos");
  const uid = d.uid;
  let archivoAntecedentes: string | undefined;

  if (d.aprobar) {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(refVerificacion(uid));
      if (snap.get("estado") !== "en_revision") falla("failed-precondition", "No está en revisión");
      archivoAntecedentes = snap.get("archivos.antecedentes");
      const documentos: Record<string, string> = {};
      for (const t of DOCUMENTOS) {
        documentos[t] = snap.get(`documentos.${t}`) === "en_revision" ? "listo" : snap.get(`documentos.${t}`);
      }
      tx.update(refVerificacion(uid), {
        estado: "aprobada",
        documentos,
        revisadoPor: adminUid,
        revisadoEn: FieldValue.serverTimestamp(),
        // Requisitos legales: del certificado de antecedentes se guarda solo el resultado.
        resultadoAntecedentes: "sin_antecedentes",
        "archivos.antecedentes": FieldValue.delete(),
      });
      tx.update(refPerfil(uid), { verificado: true });
    });
    if (archivoAntecedentes) {
      await storage.bucket().file(archivoAntecedentes).delete({ ignoreNotFound: true });
    }
    await notificar(uid, "Mican", "Tu verificación fue aprobada", { tipo: "verificacion_aprobada" });
    return { ok: true };
  }

  const motivo = textoRequerido(d.motivo, 500);
  if (!motivo) falla("invalid-argument", "Indica el motivo del rechazo");
  const rehacer = (d.documentosARehacer ?? []).filter((t) => (DOCUMENTOS as readonly string[]).includes(t));
  if (!rehacer.length) falla("invalid-argument", "Indica qué documento debe volver a subir");
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(refVerificacion(uid));
    if (snap.get("estado") !== "en_revision") falla("failed-precondition", "No está en revisión");
    const documentos: Record<string, string> = {};
    for (const t of DOCUMENTOS) {
      const actual = snap.get(`documentos.${t}`);
      documentos[t] = rehacer.includes(t) ? "rechazado" : actual === "en_revision" ? "subido" : actual;
    }
    tx.update(refVerificacion(uid), {
      estado: "rechazada",
      documentos,
      motivoRechazo: motivo,
      revisadoPor: adminUid,
      revisadoEn: FieldValue.serverTimestamp(),
    });
  });
  await notificar(uid, "Mican", `Revisa tu verificación: ${motivo}`, { tipo: "verificacion_rechazada" });
  return { ok: true };
});

/** Panel admin: enlaces temporales (15 min) para ver los documentos. */
export const enlacesDocumentosVerificacion = onCall({ region: REGION }, async (req) => {
  requiereAdmin(req);
  const { uid } = datos<{ uid: string }>(req);
  if (typeof uid !== "string") falla("invalid-argument", "Falta el cuidador");
  const snap = await refVerificacion(uid).get();
  const archivos = (snap.get("archivos") ?? {}) as Record<string, string>;
  const expires = Date.now() + 15 * 60_000;
  const enlaces: Record<string, string> = {};
  for (const [tipo, ruta] of Object.entries(archivos)) {
    const [url] = await storage.bucket().file(ruta).getSignedUrl({ action: "read", expires });
    enlaces[tipo] = url;
  }
  return { enlaces };
});
