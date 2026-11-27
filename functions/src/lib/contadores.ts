import { Transaction } from "firebase-admin/firestore";
import { COL, db } from "./firebase";

/**
 * Número correlativo dentro de una transacción (p. ej. Libro de
 * Reclamaciones: R-2026-000001). Reinicia cada año.
 */
export async function siguienteCorrelativo(
  tx: Transaction,
  nombre: string,
  prefijo: string,
  anio = new Date().getUTCFullYear(),
): Promise<string> {
  const ref = db.collection(COL.contadores).doc(`${nombre}-${anio}`);
  const snap = await tx.get(ref);
  const n = (snap.exists ? (snap.get("valor") as number) : 0) + 1;
  tx.set(ref, { valor: n }, { merge: true });
  return `${prefijo}-${anio}-${String(n).padStart(6, "0")}`;
}
