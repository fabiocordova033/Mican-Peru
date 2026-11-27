import { createHmac } from "node:crypto";
import { crearMercadoPago, eventoDesdePagoMP, manifestMP, verificarFirmaMP } from "../../src/lib/mercadopago";
import { FirmaInvalida, crearSimulada, firmar } from "../../src/lib/pasarela";
import { obtenerPasarela } from "../../src/lib/pasarelas";

const SECRETO = "clave-secreta-del-webhook";
const TOKEN = "TEST-0000000000000000-000000-abc";

/** Firma igual que Mercado Pago: HMAC-SHA256 del manifest con la clave secreta. */
function firmaMP(dataId: string, requestId: string, ts = "1704908010", secreto = SECRETO) {
  const v1 = createHmac("sha256", secreto).update(`id:${dataId};request-id:${requestId};ts:${ts};`).digest("hex");
  return `ts=${ts},v1=${v1}`;
}

/** fetch falso que responde según la ruta y guarda las llamadas. */
function fetchFalso(respuestas: Record<string, { status: number; json: unknown }>) {
  const llamadas: { url: string; init: RequestInit }[] = [];
  const f = (async (url: string, init: RequestInit = {}) => {
    llamadas.push({ url, init });
    const ruta = Object.keys(respuestas).find((r) => url.endsWith(r));
    const resp = ruta ? respuestas[ruta] : { status: 404, json: { message: "not found" } };
    return { status: resp.status, json: async () => resp.json } as Response;
  }) as unknown as typeof fetch;
  return { f, llamadas };
}

function aviso(dataId: string, firma = firmaMP(dataId, "req-1")) {
  return {
    cuerpo: Buffer.from(JSON.stringify({ type: "payment", action: "payment.updated", data: { id: dataId } })),
    cabeceras: { "x-signature": firma, "x-request-id": "req-1" },
    query: { "data.id": dataId, type: "payment" },
  };
}

const pagoMP = (extra: object) => ({
  id: 123456789,
  status: "approved",
  status_detail: "accredited",
  external_reference: "pago-abc",
  transaction_amount: 20,
  currency_id: "PEN",
  ...extra,
});

describe("firma del webhook de Mercado Pago", () => {
  it("arma el manifest con id en minúsculas", () => {
    expect(manifestMP("ABC123", "req-1", "17")).toBe("id:abc123;request-id:req-1;ts:17;");
    expect(manifestMP(undefined, undefined, "17")).toBe("ts:17;");
  });

  it("acepta una firma válida", () => {
    expect(() =>
      verificarFirmaMP({ firma: firmaMP("123", "req-1"), requestId: "req-1", dataId: "123", secreto: SECRETO }),
    ).not.toThrow();
  });

  it("rechaza firma con otra clave, otro pago u otra cabecera", () => {
    const casos = [
      { firma: firmaMP("123", "req-1", "1704908010", "otra"), requestId: "req-1", dataId: "123" },
      { firma: firmaMP("123", "req-1"), requestId: "req-1", dataId: "999" },
      { firma: firmaMP("123", "req-1"), requestId: "req-2", dataId: "123" },
      { firma: "ts=1704908010", requestId: "req-1", dataId: "123" },
      { firma: undefined, requestId: "req-1", dataId: "123" },
    ];
    for (const c of casos) {
      expect(() => verificarFirmaMP({ ...c, secreto: SECRETO })).toThrow(FirmaInvalida);
    }
  });

  it("rechaza si no hay clave configurada", () => {
    expect(() => verificarFirmaMP({ firma: firmaMP("1", "r"), requestId: "r", dataId: "1", secreto: "" })).toThrow(
      FirmaInvalida,
    );
  });
});

describe("estado del pago de Mercado Pago", () => {
  it("approved -> pagado, en céntimos", () => {
    expect(eventoDesdePagoMP(pagoMP({ transaction_amount: 7.5 }))).toEqual({
      referencia: "pago-abc",
      estado: "pagado",
      montoCentimos: 750,
      idExterno: "123456789",
    });
  });

  it("redondea montos con decimales flotantes", () => {
    expect(eventoDesdePagoMP(pagoMP({ transaction_amount: 19.99 }))!.montoCentimos).toBe(1999);
    expect(eventoDesdePagoMP(pagoMP({ transaction_amount: 0.29 }))!.montoCentimos).toBe(29);
  });

  it("rejected -> fallido con motivo legible", () => {
    const e = eventoDesdePagoMP(pagoMP({ status: "rejected", status_detail: "cc_rejected_insufficient_amount" }));
    expect(e).toMatchObject({ estado: "fallido", motivo: "Fondos insuficientes" });
  });

  it("pendiente, en proceso o devuelto no cambian nada", () => {
    for (const status of ["pending", "in_process", "authorized", "refunded", "charged_back", "in_mediation"]) {
      expect(eventoDesdePagoMP(pagoMP({ status }))).toBeNull();
    }
  });

  it("ignora pagos sin referencia de Mican y rechaza otra moneda", () => {
    expect(eventoDesdePagoMP(pagoMP({ external_reference: null }))).toBeNull();
    expect(() => eventoDesdePagoMP(pagoMP({ currency_id: "USD" }))).toThrow();
  });
});

describe("pasarela Mercado Pago", () => {
  it("crea la preferencia en soles con external_reference e idempotencia", async () => {
    const { f, llamadas } = fetchFalso({
      "/checkout/preferences": {
        status: 201,
        json: { id: "pref-1", init_point: "https://mp/real", sandbox_init_point: "https://mp/sandbox" },
      },
    });
    const mp = crearMercadoPago({
      nombre: "mercadopago",
      secretoWebhook: SECRETO,
      mpAccessToken: TOKEN,
      urlWebhook: "https://funcs.example/webhookPagos",
      urlRetorno: "https://mican.pe/pago",
      fetch: f,
    });
    const c = await mp.crearCheckout({ referencia: "pago-abc", montoCentimos: 2000, descripcion: "Recarga", tipo: "recarga" });
    expect(c).toEqual({ proveedor: "mercadopago", referencia: "pago-abc", urlPago: "https://mp/sandbox", idCheckout: "pref-1" });

    const { init } = llamadas[0];
    const h = init.headers as Record<string, string>;
    expect(h.authorization).toBe(`Bearer ${TOKEN}`);
    expect(h["x-idempotency-key"]).toBe("pago-abc");
    const body = JSON.parse(init.body as string);
    expect(body.items[0]).toMatchObject({ unit_price: 20, currency_id: "PEN", quantity: 1 });
    expect(body.external_reference).toBe("pago-abc");
    expect(body.notification_url).toBe("https://funcs.example/webhookPagos?source_news=webhooks");
    expect(body.back_urls.success).toBe("https://mican.pe/pago?pago=pago-abc&estado=pagado");
  });

  it("en producción usa init_point", async () => {
    const { f } = fetchFalso({
      "/checkout/preferences": { status: 201, json: { id: "p", init_point: "https://mp/real", sandbox_init_point: "x" } },
    });
    const mp = crearMercadoPago({ nombre: "mercadopago", secretoWebhook: SECRETO, mpAccessToken: TOKEN, mpModo: "produccion", fetch: f });
    const c = await mp.crearCheckout({ referencia: "r", montoCentimos: 750, descripcion: "Premium", tipo: "premium" });
    expect(c.urlPago).toBe("https://mp/real");
  });

  it("falla con un error claro si Mercado Pago rechaza la preferencia o falta el token", async () => {
    const { f } = fetchFalso({ "/checkout/preferences": { status: 401, json: { message: "invalid access token" } } });
    const mp = crearMercadoPago({ nombre: "mercadopago", secretoWebhook: SECRETO, mpAccessToken: TOKEN, fetch: f });
    await expect(mp.crearCheckout({ referencia: "r", montoCentimos: 1000, descripcion: "x", tipo: "recarga" })).rejects.toThrow(
      /invalid access token/,
    );
    const sinToken = crearMercadoPago({ nombre: "mercadopago", secretoWebhook: SECRETO, fetch: f });
    await expect(sinToken.crearCheckout({ referencia: "r", montoCentimos: 1000, descripcion: "x", tipo: "recarga" })).rejects.toThrow(
      /MP_ACCESS_TOKEN/,
    );
  });

  it("webhook: verifica la firma y toma estado y monto de la API, no del aviso", async () => {
    const { f, llamadas } = fetchFalso({ "/v1/payments/123456789": { status: 200, json: pagoMP({}) } });
    const mp = crearMercadoPago({ nombre: "mercadopago", secretoWebhook: SECRETO, mpAccessToken: TOKEN, fetch: f });
    const e = await mp.leerWebhook(aviso("123456789"));
    expect(e).toEqual({ referencia: "pago-abc", estado: "pagado", montoCentimos: 2000, idExterno: "123456789" });
    expect(llamadas[0].url).toBe("https://api.mercadopago.com/v1/payments/123456789");
  });

  it("webhook: firma falsa no consulta la API", async () => {
    const { f, llamadas } = fetchFalso({});
    const mp = crearMercadoPago({ nombre: "mercadopago", secretoWebhook: SECRETO, mpAccessToken: TOKEN, fetch: f });
    await expect(mp.leerWebhook(aviso("123", "ts=1,v1=deadbeef"))).rejects.toThrow(FirmaInvalida);
    expect(llamadas).toHaveLength(0);
  });

  it("webhook: ignora otros tipos de aviso y pagos inexistentes", async () => {
    const { f } = fetchFalso({});
    const mp = crearMercadoPago({ nombre: "mercadopago", secretoWebhook: SECRETO, mpAccessToken: TOKEN, fetch: f });
    const orden = {
      cuerpo: Buffer.from(JSON.stringify({ type: "merchant_order", data: { id: "55" } })),
      cabeceras: { "x-signature": firmaMP("55", "req-1"), "x-request-id": "req-1" },
      query: { "data.id": "55", type: "merchant_order" },
    };
    expect(await mp.leerWebhook(orden)).toBeNull();
    expect(await mp.leerWebhook(aviso("404404"))).toBeNull();
  });

  it("webhook: un error de la API se propaga para que Mercado Pago reintente", async () => {
    const { f } = fetchFalso({ "/v1/payments/1": { status: 500, json: {} } });
    const mp = crearMercadoPago({ nombre: "mercadopago", secretoWebhook: SECRETO, mpAccessToken: TOKEN, fetch: f });
    await expect(mp.leerWebhook(aviso("1"))).rejects.toThrow(/500/);
  });
});

describe("pasarela simulada y selección", () => {
  it("la simulada valida x-mican-firma", async () => {
    const sim = crearSimulada(SECRETO);
    const cuerpo = Buffer.from(JSON.stringify({ referencia: "p1", estado: "pagado", montoCentimos: 2000 }));
    await expect(sim.leerWebhook({ cuerpo, cabeceras: { "x-mican-firma": firmar(cuerpo, SECRETO) }, query: {} })).resolves.toMatchObject({
      referencia: "p1",
      estado: "pagado",
    });
    await expect(sim.leerWebhook({ cuerpo, cabeceras: { "x-mican-firma": "x" }, query: {} })).rejects.toThrow(FirmaInvalida);
  });

  it("elige la pasarela por nombre", () => {
    expect(obtenerPasarela({ nombre: "simulada", secretoWebhook: SECRETO }).nombre).toBe("simulada");
    expect(obtenerPasarela({ nombre: "mercadopago", secretoWebhook: SECRETO }).nombre).toBe("mercadopago");
    expect(() => obtenerPasarela({ nombre: "culqi", secretoWebhook: SECRETO })).toThrow(/no implementada/);
  });
});
