import { Transaction } from "firebase-admin/firestore";
import { COL, db } from "./firebase";
import { falla } from "./errores";

export const refUsuario = (uid: string) => db.collection(COL.usuarios).doc(uid);
export const refPerfil = (uid: string) => db.collection(COL.perfiles).doc(uid);

/** ¿Tiene Premium vigente (incluye la prueba gratis)? */
export function esPremium(usuario: FirebaseFirestore.DocumentData | undefined, ahora = new Date()): boolean {
  const hasta = usuario?.premiumHasta?.toDate?.() as Date | undefined;
  return !!hasta && hasta > ahora;
}

/** Lee el usuario y valida que la cuenta esté activa. */
export async function usuarioActivo(uid: string, tx?: Transaction) {
  const ref = refUsuario(uid);
  const snap = tx ? await tx.get(ref) : await ref.get();
  if (!snap.exists) falla("failed-precondition", "Completa tu registro primero");
  const u = snap.data()!;
  if (u.estadoCuenta !== "activa") falla("failed-precondition", "Tu cuenta no está activa");
  return u;
}
