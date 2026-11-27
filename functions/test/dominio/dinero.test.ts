import { calcularComision, desgloseOferta, formatearSoles, solesACentimos } from "../../src/dominio/dinero";

describe("comisión del 12 % (HU-13, HU-22)", () => {
  it("S/ 28 -> Mican cobra S/ 3.36 y el cuidador recibe S/ 24.64", () => {
    expect(desgloseOferta(2800)).toEqual({ precio: 2800, comision: 336, recibes: 2464, tasa: 0.12 });
  });

  it("12 % de S/ 25 = S/ 3.00", () => {
    expect(calcularComision(2500)).toBe(300);
  });

  it("redondea al céntimo", () => {
    // 12 % de S/ 22.55 = 2.706 -> S/ 2.71
    expect(calcularComision(2255)).toBe(271);
    // 12 % de S/ 0.04 = 0.0048 -> S/ 0.00
    expect(calcularComision(4)).toBe(0);
  });

  it("rechaza precios inválidos", () => {
    expect(() => calcularComision(-100)).toThrow();
    expect(() => calcularComision(10.5)).toThrow();
  });

  it("acepta una tasa distinta (comisión por nivel)", () => {
    expect(calcularComision(5000, 0.1)).toBe(500);
  });

  it("formatea y convierte soles", () => {
    expect(formatearSoles(336)).toBe("S/ 3.36");
    expect(formatearSoles(-300)).toBe("− S/ 3.00");
    expect(solesACentimos(24.64)).toBe(2464);
  });
});
