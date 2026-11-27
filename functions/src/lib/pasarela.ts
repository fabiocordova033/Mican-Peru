import { createHmac, timingSafeEqual } from "node:crypto";

/**
 * Abstracción de la pasarela de pagos. Mican nunca guarda datos de tarjeta:
 * la app abre el checkout de la pasarela y la pasarela confirma por webhook.
 *
 * Implementaciones:
 *  - "simulada": para el emulador, las pruebas y la demo (scripts/simular-pago.js).
 *  - "mercadopago": Checkout Pro de Mercado Pago Perú (Yape, tarjetas, PagoEfectivo).
 *    Ver lib/mercadopago.ts y la sección "Pasarela de pago" del README.
 *
 * Este módulo no importa Firebase para poder probarlo con Jest sin emulador.
 */
export interface CheckoutCreado {
  proveedor: string;
  referencia: string;
  /** URL que la app abre en el navegador para pagar. */
  urlPago: string;
  /** Id del checkout en la pasarela (preferencia de Mercado Pago). */
  idCheckout?: string;
}

export interface EventoPago {
  /** Nuestro id de `pagos/{id}` (external_reference en Mercado Pago). */
  referencia: string;
  estado: "pagado" | "fallido";
  motivo?: string;
  montoCentimos: number;
  /** Id de la transacción en la pasarela, para soporte y devoluciones. */
  idExterno?: string;
}

/** Lo que llega al webhook, tal cual lo entrega Cloud Functions. */
export interface SolicitudWebhook {
  cuerpo: Buffer;
  cabeceras: Record<string, string | string[] | undefined>;
  query: Record<string, unknown>;
}

export interface Pasarela {
  nombre: string;
  crearCheckout(p: {
    referencia: string;
    montoCentimos: number;
    descripcion: string;
    tipo: "recarga" | "premium";
  }): Promise<CheckoutCreado>;
  /**
   * Verifica la firma del webhook y devuelve el evento normalizado, o `null`
   * si el aviso no cambia nada (otro tipo de notificación, pago aún pendiente).
   * Lanza `FirmaInvalida` si la firma no corresponde.
   */
  leerWebhook(s: SolicitudWebhook): Promise<EventoPago | null>;
}

/** Credenciales y opciones. Los secretos vienen de Secret Manager. */
export interface ConfigPasarela {
  nombre: string;
  /** Clave secreta con la que la pasarela firma los webhooks. */
  secretoWebhook: string;
  /** Access token de Mercado Pago (TEST-... en sandbox, APP_USR-... en producción). */
  mpAccessToken?: string;
  /** "sandbox" usa el checkout de pruebas; "produccion" cobra de verdad. */
  mpModo?: "sandbox" | "produccion";
  /** URL pública de webhookPagos, se envía como notification_url. */
  urlWebhook?: string;
  /** URL a la que vuelve el usuario después de pagar (opcional). */
  urlRetorno?: string;
  /** Para pruebas: reemplaza fetch. */
  fetch?: typeof fetch;
}

export class FirmaInvalida extends Error {
  constructor(motivo = "Firma inválida") {
    super(motivo);
    this.name = "FirmaInvalida";
  }
}

export function firmar(cuerpo: Buffer | string, secreto: string): string {
  return createHmac("sha256", secreto).update(cuerpo).digest("hex");
}

/** Compara en tiempo constante dos firmas hex. */
export function mismaFirma(esperada: string, recibida: string): boolean {
  const a = Buffer.from(esperada);
  const b = Buffer.from(recibida);
  return a.length === b.length && timingSafeEqual(a, b);
}

export function firmaValida(cuerpo: Buffer, firma: string, secreto: string): boolean {
  return mismaFirma(firmar(cuerpo, secreto), firma);
}

export function cabecera(c: SolicitudWebhook["cabeceras"], nombre: string): string | undefined {
  const v = c[nombre.toLowerCase()];
  return Array.isArray(v) ? v[0] : v;
}

/**
 * Pasarela simulada: el checkout es una URL ficticia y el webhook es un JSON
 * { referencia, estado, montoCentimos, motivo? } firmado con HMAC-SHA256 en la
 * cabecera `x-mican-firma`. Ver functions/scripts/simular-pago.js.
 */
export function crearSimulada(secreto: string): Pasarela {
  return {
    nombre: "simulada",
    async crearCheckout({ referencia }) {
      return {
        proveedor: "simulada",
        referencia,
        urlPago: `https://pagos.simulados.mican.pe/checkout/${referencia}`,
      };
    },
    async leerWebhook({ cuerpo, cabeceras }) {
      const firma = cabecera(cabeceras, "x-mican-firma");
      if (!firma || !firmaValida(cuerpo, firma, secreto)) throw new FirmaInvalida();
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
}
