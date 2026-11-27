import { esDuracionPaquete, precioPaquete, rangoSugerido, validarPrecioOfrecido } from "../../src/dominio/precios";

describe("precio sugerido y ofrecido (HU-10, HU-11)", () => {
  it("el rango está en soles enteros y el piso es el 70 % del mínimo", () => {
    const r = rangoSugerido("paseo", 60);
    expect(r.minimo % 100).toBe(0);
    expect(r.maximo % 100).toBe(0);
    expect(r.minimo).toBeLessThan(r.maximo);
    expect(r.piso).toBe(Math.ceil((r.minimo * 0.7) / 100) * 100);
  });

  it("paseo de 1 h cae cerca de S/ 22 a 28", () => {
    const r = rangoSugerido("paseo", 60);
    expect(r.minimo).toBe(2200);
    expect(r.maximo).toBe(2800);
  });

  it("transporte sube con la distancia", () => {
    expect(rangoSugerido("transporte", 30, 10).minimo).toBeGreaterThan(rangoSugerido("transporte", 30, 2).minimo);
  });

  it("valida el precio ofrecido", () => {
    const r = { minimo: 2200, maximo: 2800, piso: 1600 };
    expect(validarPrecioOfrecido(2500, r)).toEqual({ ok: true });
    expect(validarPrecioOfrecido(2000, r)).toEqual({ ok: true, aviso: "MENOS_OFERTAS" });
    expect(validarPrecioOfrecido(1500, r)).toEqual({ ok: false, motivo: "BAJO_PISO" });
    expect(validarPrecioOfrecido(2550, r)).toEqual({ ok: false, motivo: "NO_ENTERO" });
  });

  it("paquetes fijos de 30 min, 1 h y 2 h", () => {
    expect(precioPaquete("paseo", 60)).toBe(2500);
    expect(esDuracionPaquete(60)).toBe(true);
    expect(esDuracionPaquete(45)).toBe(false);
  });

  it("rechaza duraciones inválidas", () => {
    expect(() => rangoSugerido("paseo", 0)).toThrow();
  });
});
