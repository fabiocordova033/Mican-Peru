import { decidirEventoPago } from "../../src/dominio/pagos";

const pendiente = { estado: "pendiente" as const, monto: 2000 };

describe("idempotencia de los avisos de pago (HU-21, HU-27)", () => {
  it("acredita un pago pendiente aprobado por el monto exacto", () => {
    expect(decidirEventoPago(pendiente, { estado: "pagado", montoCentimos: 2000, idExterno: "1" })).toBe("acreditar");
  });

  it("no acredita dos veces el mismo aviso", () => {
    const pagado = { estado: "pagado" as const, monto: 2000, idExterno: "1" };
    expect(decidirEventoPago(pagado, { estado: "pagado", montoCentimos: 2000, idExterno: "1" })).toBe("duplicado");
  });

  it("un rechazo tardío no deshace un pago aprobado", () => {
    const pagado = { estado: "pagado" as const, monto: 2000, idExterno: "2" };
    expect(decidirEventoPago(pagado, { estado: "fallido", montoCentimos: 2000, idExterno: "1" })).toBe("duplicado");
  });

  it("marca fallido solo una vez", () => {
    expect(decidirEventoPago(pendiente, { estado: "fallido", montoCentimos: 2000 })).toBe("marcar_fallido");
    expect(decidirEventoPago({ ...pendiente, estado: "fallido" }, { estado: "fallido", montoCentimos: 2000 })).toBe(
      "duplicado",
    );
  });

  it("permite pagar con Yape después de que falló la tarjeta", () => {
    const fallido = { estado: "fallido" as const, monto: 2000 };
    expect(decidirEventoPago(fallido, { estado: "pagado", montoCentimos: 2000, idExterno: "2" })).toBe("acreditar");
  });

  it("detecta un segundo cobro aprobado con otra transacción", () => {
    const pagado = { estado: "pagado" as const, monto: 2000, idExterno: "1" };
    expect(decidirEventoPago(pagado, { estado: "pagado", montoCentimos: 2000, idExterno: "9" })).toBe("cobro_duplicado");
  });

  it("no acredita si el monto cobrado no coincide", () => {
    expect(decidirEventoPago(pendiente, { estado: "pagado", montoCentimos: 1999 })).toBe("monto_distinto");
  });
});
