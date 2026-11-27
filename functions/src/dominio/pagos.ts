/**
 * Qué hacer con un aviso de la pasarela según el estado actual del pago.
 * Lógica pura (sin Firestore) para poder probar la idempotencia con Jest.
 *
 * - Un pago se acredita UNA sola vez, aunque la pasarela reintente el aviso.
 * - Un pago rechazado puede aprobarse después: en Mercado Pago el usuario
 *   reintenta en el mismo checkout con otro medio (p. ej. falla la tarjeta y
 *   paga con Yape). Por eso `fallido` -> `pagado` sí se permite.
 * - Si llega un SEGUNDO cobro aprobado (otra transacción) para un pago ya
 *   acreditado, no se acredita dos veces: se abre un ticket para devolverlo.
 * - Si el monto cobrado no coincide, no se acredita y lo revisa soporte.
 */
export type EstadoPago = "pendiente" | "pagado" | "fallido";

export interface PagoGuardado {
  estado: EstadoPago;
  monto: number;
  idExterno?: string;
}

export interface AvisoPago {
  estado: "pagado" | "fallido";
  montoCentimos: number;
  idExterno?: string;
}

export type DecisionPago =
  | "acreditar"
  | "marcar_fallido"
  | "duplicado"
  | "cobro_duplicado"
  | "monto_distinto";

export function decidirEventoPago(pago: PagoGuardado, aviso: AvisoPago): DecisionPago {
  if (pago.estado === "pagado") {
    const otraTransaccion =
      aviso.estado === "pagado" && !!aviso.idExterno && !!pago.idExterno && aviso.idExterno !== pago.idExterno;
    return otraTransaccion ? "cobro_duplicado" : "duplicado";
  }
  if (aviso.estado === "fallido") {
    return pago.estado === "pendiente" ? "marcar_fallido" : "duplicado";
  }
  if (aviso.montoCentimos !== pago.monto) return "monto_distinto";
  return "acreditar";
}
