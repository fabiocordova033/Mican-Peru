import { DocumentReference, Transaction } from "firebase-admin/firestore";
import { COL, FieldValue, db } from "./firebase";

export type TipoMovimiento = "recarga" | "comision" | "devolucion" | "ajuste";

export const refBilletera = (uid: string) => db.collection(COL.billeteras).doc(uid);

/** Lee el saldo dentro de una transacción (0 si la billetera no existe). */
export async function leerSaldo(tx: Transaction, uid: string): Promise<number> {
  const snap = await tx.get(refBilletera(uid));
  return snap.exists ? (snap.get("saldo") as number) : 0;
}

export interface Movimiento {
  tipo: TipoMovimiento;
  /** Céntimos con signo: positivo suma, negativo resta. */
  monto: number;
  descripcion: string;
  servicioId?: string;
  pagoId?: string;
  mascotaNombre?: string;
  tasa?: number;
}

/**
 * Aplica un movimiento a la billetera y deja el registro en
 * billeteras/{uid}/movimientos. Debe llamarse DESPUÉS de todas las lecturas
 * de la transacción, pasando el saldo leído con `leerSaldo`.
 *
 * Es la ÚNICA forma de cambiar un saldo: las reglas de Firestore impiden que
 * la app escriba en billeteras.
 */
export function aplicarMovimiento(
  tx: Transaction,
  uid: string,
  saldoActual: number,
  mov: Movimiento,
): { saldo: number; movimientoRef: DocumentReference } {
  const saldo = saldoActual + mov.monto;
  const billetera = refBilletera(uid);
  tx.set(
    billetera,
    { saldo, actualizadoEn: FieldValue.serverTimestamp() },
    { merge: true },
  );
  const movimientoRef = billetera.collection(COL.movimientos).doc();
  tx.set(movimientoRef, {
    ...mov,
    saldoResultante: saldo,
    creadoEn: FieldValue.serverTimestamp(),
  });
  return { saldo, movimientoRef };
}
