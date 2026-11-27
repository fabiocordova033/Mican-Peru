import { createHmac, timingSafeEqual } from "node:crypto";

/**
 * Abstracción de la pasarela de pagos peruana (Culqi, Mercado Pago, Niubiz,
 * Izipay). Mican nunca guarda datos de tarjeta: la app abre el checkout de la
 * pasarela y la pasarela confirma por webhook.
 *
 * Hoy solo existe la implementación "simulada" (para el emulador y la
 * demo). Para producción, implementar `Pasarela` con el SDK/API del
 * proveedor elegido y verificar la firma según su documentación.
 */
export interface CheckoutCreado {
  proveedor: string;
  referencia: string;
  /** URL o token que la app usa para abrir el checkout. */
  urlPago: string;
}

export interface EventoPago {
  referencia: string;
  estado: "pagado" | "fallido";
  motivo?: string;
  montoCentimos: number;
}

export interface Pasarela {
  nombre: string;
  crearCheckout(p: {
    referencia: string;
    montoCentimos: number;
    descripcion: string;
  }): Promise<CheckoutCreado>;
  /** Verifica la firma del webhook y devuelve el evento normalizado. */
  leerWebhook(cuerpoCrudo: Buffer, cabeceras: Record<string, string | string[] | undefined>, secreto: string): EventoPago;
}

export function firmar(cuerpo: Buffer | string, secreto: string): string {
  return createHmac("sha256", secreto).update(cuerpo).digest("hex");
}

export function firmaValida(cuerpo: Buffer, firma: string, secreto: string): boolean {
  const esperada = Buffer.from(firmar(cuerpo, secreto));
  const recibida = Buffer.from(firma);
  return esperada.length === recibida.length && timingSafeEqual(esperada, recibida);
}

/**
 * Pasarela simulada: el checkout es una URL ficticia y el webhook es un JSON
 * { referencia, estado, montoCentimos, motivo? } firmado con HMAC-SHA256 en la
 * cabecera `x-mican-firma`. Ver functions/scripts/simular-pago.js.
 */
export const pasarelaSimulada: Pasarela = {
  nombre: "simulada",
  async crearCheckout({ referencia }) {
    return {
      proveedor: "simulada",
      referencia,
      urlPago: `https://pagos.simulados.mican.pe/checkout/${referencia}`,
    };
  },
  leerWebhook(cuerpo, cabeceras, secreto) {
    const firma = cabeceras["x-mican-firma"];
    if (typeof firma !== "string" || !firmaValida(cuerpo, firma, secreto)) {
      throw new Error("Firma inválida");
    }
    const e = JSON.parse(cuerpo.toString("utf8"));
    if (typeof e.referencia !== "string" || !["pagado", "fallido"].includes(e.estado)) {
      throw new Error("Evento inválido");
    }
    return {
      referencia: e.referencia,
      estado: e.estado,
      motivo: e.motivo,
      montoCentimos: Number(e.montoCentimos),
    };
  },
};

export function obtenerPasarela(nombre = process.env.PASARELA ?? "simulada"): Pasarela {
  switch (nombre) {
    case "simulada":
      return pasarelaSimulada;
    // case "culqi": return pasarelaCulqi;          // TODO producción
    // case "mercadopago": return pasarelaMercadoPago; // TODO producción
    default:
      throw new Error(`Pasarela no implementada: ${nombre}`);
  }
}
