import { CallableRequest, HttpsError } from "firebase-functions/v2/https";

/** Lanza un error que la app recibe con código y mensaje en español. */
export function falla(
  codigo: "invalid-argument" | "failed-precondition" | "permission-denied" | "not-found" | "already-exists" | "resource-exhausted" | "unauthenticated" | "deadline-exceeded",
  mensaje: string,
  detalle?: Record<string, unknown>,
): never {
  throw new HttpsError(codigo, mensaje, detalle);
}

/** Exige sesión iniciada y devuelve el uid. */
export function requiereUsuario(req: CallableRequest): string {
  if (!req.auth) falla("unauthenticated", "Inicia sesión para continuar");
  return req.auth.uid;
}

/** Exige el claim de administrador (ver functions/scripts/asignar-admin.js). */
export function requiereAdmin(req: CallableRequest): string {
  const uid = requiereUsuario(req);
  if (req.auth?.token.admin !== true) falla("permission-denied", "Solo administradores");
  return uid;
}

/** Lee `req.data` como objeto. */
export function datos<T = Record<string, unknown>>(req: CallableRequest): Partial<T> {
  const d = req.data;
  if (!d || typeof d !== "object") return {};
  return d as Partial<T>;
}
