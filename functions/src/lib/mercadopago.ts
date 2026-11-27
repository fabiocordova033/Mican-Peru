import { createHmac } from "node:crypto";
import {
  ConfigPasarela,
  EventoPago,
  FirmaInvalida,
  Pasarela,
  SolicitudWebhook,
  cabecera,
  mismaFirma,
} from "./pasarela";

/**
 * Mercado Pago Perú · Checkout Pro (API de preferencias).
 *
 * 1. `crearCheckout` crea una preferencia con `external_reference` = id de
 *    `pagos/{id}` y devuelve su `init_point` (o `sandbox_init_point` en modo
 *    sandbox). La app lo abre en el navegador: el usuario paga con Yape,
 *    tarjeta de crédito o débito, o PagoEfectivo, en la página de Mercado Pago.
 * 2. Mercado Pago avisa a `webhookPagos` con `?data.id=<id del pago>&type=payment`
 *    y la cabecera `x-signature`. Verificamos la firma y luego CONSULTAMOS el
 *    pago con el access token: el estado y el monto se toman de la API, nunca
 *    del cuerpo del aviso.
 *
 * Docs: https://www.mercadopago.com.pe/developers/es/docs/checkout-pro/landing
 */
export const API_MP = "https://api.mercadopago.com";

/** Un pago de Mercado Pago, solo los campos que usamos. */
export interface PagoMP {
  id: number | string;
  status: string;
  status_detail?: string;
  external_reference?: string | null;
  transaction_amount: number;
  currency_id: string;
  live_mode?: boolean;
}

/** Motivos que ve el usuario cuando el pago es rechazado. */
const MOTIVOS: Record<string, string> = {
  cc_rejected_insufficient_amount: "Fondos insuficientes",
  cc_rejected_bad_filled_security_code: "Código de seguridad incorrecto",
  cc_rejected_bad_filled_date: "Fecha de vencimiento incorrecta",
  cc_rejected_bad_filled_card_number: "Número de tarjeta incorrecto",
  cc_rejected_bad_filled_other: "Revisa los datos de la tarjeta",
  cc_rejected_call_for_authorize: "Tu banco debe autorizar el pago",
  cc_rejected_card_disabled: "La tarjeta está deshabilitada",
  cc_rejected_duplicated_payment: "Ya hiciste un pago por el mismo monto",
  cc_rejected_high_risk: "El pago fue rechazado por seguridad",
  cc_rejected_max_attempts: "Llegaste al límite de intentos",
  expired: "El pago venció",
  by_payer: "Cancelaste el pago",
};

export function motivoRechazo(statusDetail?: string): string {
  return (statusDetail && MOTIVOS[statusDetail]) || "El pago fue rechazado";
}

/**
 * Valida `x-signature: ts=<segundos>,v1=<hmac hex>`. El HMAC-SHA256 se calcula
 * con la clave secreta del webhook sobre el "manifest"
 *   id:<data.id>;request-id:<x-request-id>;ts:<ts>;
 * omitiendo las partes que no vengan. `data.id` va en minúsculas.
 */
export function manifestMP(dataId: string | undefined, requestId: string | undefined, ts: string): string {
  let m = "";
  if (dataId) m += `id:${dataId.toLowerCase()};`;
  if (requestId) m += `request-id:${requestId};`;
  m += `ts:${ts};`;
  return m;
}

export function verificarFirmaMP(p: {
  firma: string | undefined;
  requestId: string | undefined;
  dataId: string | undefined;
  secreto: string;
}): void {
  if (!p.secreto) throw new FirmaInvalida("Falta la clave secreta del webhook");
  if (!p.firma) throw new FirmaInvalida("Falta x-signature");
  const partes = Object.fromEntries(
    p.firma.split(",").map((s) => {
      const [k, ...v] = s.trim().split("=");
      return [k, v.join("=")];
    }),
  );
  const ts = partes["ts"];
  const v1 = partes["v1"];
  if (!ts || !v1) throw new FirmaInvalida("x-signature incompleta");
  const esperada = createHmac("sha256", p.secreto).update(manifestMP(p.dataId, p.requestId, ts)).digest("hex");
  if (!mismaFirma(esperada, v1)) throw new FirmaInvalida();
  // No rechazamos por antigüedad de `ts`: MP reintenta durante horas y un
  // aviso repetido es inofensivo, porque el estado real se consulta a la API
  // y `procesarEventoPago` es idempotente.
}

/** Traduce un pago de MP a nuestro evento. `null` = todavía no hay nada que hacer. */
export function eventoDesdePagoMP(pago: PagoMP): EventoPago | null {
  if (!pago.external_reference) return null; // no lo creó Mican
  if (pago.currency_id !== "PEN") throw new Error(`Moneda inesperada: ${pago.currency_id}`);
  const base = {
    referencia: pago.external_reference,
    montoCentimos: Math.round(pago.transaction_amount * 100),
    idExterno: String(pago.id),
  };
  switch (pago.status) {
    case "approved":
      return { ...base, estado: "pagado" };
    case "rejected":
    case "cancelled":
      return { ...base, estado: "fallido", motivo: motivoRechazo(pago.status_detail) };
    default:
      // pending, in_process, authorized: llegará otro aviso cuando cambie.
      // refunded, charged_back, in_mediation: lo revisa soporte, no tocamos saldos.
      return null;
  }
}

function texto(v: unknown): string | undefined {
  if (typeof v === "string") return v;
  if (typeof v === "number") return String(v);
  if (Array.isArray(v)) return texto(v[0]);
  return undefined;
}

export function crearMercadoPago(cfg: ConfigPasarela): Pasarela {
  const pedir = cfg.fetch ?? fetch;
  const token = cfg.mpAccessToken ?? "";
  const modo = cfg.mpModo ?? "sandbox";

  async function api<T>(ruta: string, init: RequestInit = {}): Promise<{ status: number; json: T }> {
    if (!token) throw new Error("Falta MP_ACCESS_TOKEN");
    const r = await pedir(`${API_MP}${ruta}`, {
      ...init,
      headers: {
        authorization: `Bearer ${token}`,
        "content-type": "application/json",
        ...(init.headers as Record<string, string> | undefined),
      },
    });
    const json = (await r.json().catch(() => ({}))) as T;
    return { status: r.status, json };
  }

  return {
    nombre: "mercadopago",

    async crearCheckout({ referencia, montoCentimos, descripcion, tipo }) {
      const vence = new Date(Date.now() + 24 * 60 * 60 * 1000);
      const retorno = (estado: string) => `${cfg.urlRetorno}?pago=${referencia}&estado=${estado}`;
      const preferencia = {
        items: [
          {
            id: tipo,
            title: descripcion,
            quantity: 1,
            currency_id: "PEN",
            unit_price: montoCentimos / 100,
          },
        ],
        external_reference: referencia,
        metadata: { pago_id: referencia, tipo },
        statement_descriptor: "MICAN",
        payment_methods: { installments: 1 },
        expires: true,
        expiration_date_to: vence.toISOString(),
        ...(cfg.urlWebhook ? { notification_url: `${cfg.urlWebhook}?source_news=webhooks` } : {}),
        ...(cfg.urlRetorno
          ? {
              back_urls: { success: retorno("pagado"), pending: retorno("pendiente"), failure: retorno("fallido") },
              auto_return: "approved",
            }
          : {}),
      };
      const r = await api<{ id?: string; init_point?: string; sandbox_init_point?: string; message?: string }>(
        "/checkout/preferences",
        {
          method: "POST",
          // Si la llamada se reintenta, MP no crea una segunda preferencia.
          headers: { "x-idempotency-key": referencia },
          body: JSON.stringify(preferencia),
        },
      );
      const url = modo === "sandbox" ? r.json.sandbox_init_point ?? r.json.init_point : r.json.init_point;
      if (r.status >= 300 || !url || !r.json.id) {
        throw new Error(`Mercado Pago no creó la preferencia (${r.status}): ${r.json.message ?? ""}`);
      }
      return { proveedor: "mercadopago", referencia, urlPago: url, idCheckout: r.json.id };
    },

    async leerWebhook({ cuerpo, cabeceras, query }: SolicitudWebhook) {
      let body: { type?: string; action?: string; data?: { id?: unknown } } = {};
      try {
        body = cuerpo.length ? JSON.parse(cuerpo.toString("utf8")) : {};
      } catch {
        body = {};
      }
      const dataId = texto(query["data.id"]) ?? texto(query["id"]) ?? texto(body.data?.id);
      verificarFirmaMP({
        firma: cabecera(cabeceras, "x-signature"),
        requestId: cabecera(cabeceras, "x-request-id"),
        dataId,
        secreto: cfg.secretoWebhook,
      });
      const tipo = body.type ?? texto(query["type"]) ?? texto(query["topic"]);
      if (tipo !== "payment" || !dataId) return null;

      const r = await api<PagoMP>(`/v1/payments/${encodeURIComponent(dataId)}`);
      // 404: p. ej. la "notificación de prueba" del panel de MP, con un id inventado.
      if (r.status === 404) return null;
      if (r.status >= 300) throw new Error(`Mercado Pago respondió ${r.status} al consultar el pago ${dataId}`);
      return eventoDesdePagoMP(r.json);
    },
  };
}
