import { describe, expect, it } from "vitest";
import { resumirFinanzas } from "../src/dominio/finanzas";
import { enmascararDni, fechaCorta, hace, iniciales, inicioDeMes, inicioMesSiguiente, soles } from "../src/dominio/formato";
import { textoPlazo, urgenciaReclamo } from "../src/dominio/reclamos";
import type { Reclamo, ServicioCompletado } from "../src/dominio/tipos";
import { AHORA } from "./fabricas";

describe("formato", () => {
  it("soles desde céntimos", () => {
    expect(soles(2800)).toBe("S/ 28.00");
    expect(soles(336)).toBe("S/ 3.36");
    expect(soles(123456)).toBe("S/ 1,234.56");
    expect(soles(-500)).toBe("-S/ 5.00");
  });

  it("fecha corta en hora de Lima", () => {
    expect(fechaCorta(AHORA)).toBe("27 nov 09:12");
    expect(fechaCorta(null)).toBe("—");
  });

  it("inicio de mes en hora de Lima", () => {
    // 1 dic 02:00 UTC todavía es 30 nov en Lima.
    expect(inicioDeMes(new Date("2026-12-01T02:00:00Z")).toISOString()).toBe("2026-11-01T05:00:00.000Z");
    expect(inicioMesSiguiente(new Date("2026-12-15T12:00:00Z")).toISOString()).toBe("2027-01-01T05:00:00.000Z");
  });

  it("hace cuánto", () => {
    expect(hace(new Date(AHORA.getTime() - 6 * 3_600_000), AHORA)).toBe("hace 6 h");
    expect(hace(new Date(AHORA.getTime() - 5 * 60_000), AHORA)).toBe("hace 5 min");
  });

  it("iniciales y DNI enmascarado", () => {
    expect(iniciales("Carlos Quispe García")).toBe("CQ");
    expect(iniciales("lucía")).toBe("L");
    expect(enmascararDni("79512345")).toBe("7951****");
    expect(enmascararDni(null)).toBe("sin DNI");
  });
});

describe("finanzas", () => {
  const s = (tipo: ServicioCompletado["tipo"], precioFinal: number, comision: number): ServicioCompletado => ({
    id: Math.random().toString(),
    tipo,
    precioFinal,
    comision,
    comisionTasa: 0.12,
    duenoNombre: "",
    cuidadorNombre: "",
    mascotaNombre: "",
    metodoPago: "yape",
    finalizadoEn: null,
  });

  it("suma comisiones, lo movido y recargas", () => {
    const r = resumirFinanzas(
      [s("paseo", 2800, 336), s("paseo", 2000, 240), s("visita", 3500, 420)],
      [{ id: "p1", monto: 2000, pagadoEn: null }, { id: "p2", monto: 5000, pagadoEn: null }],
    );
    expect(r.comision).toBe(996);
    expect(r.movido).toBe(8300);
    expect(r.recibenCuidadores).toBe(7304);
    expect(r.montoRecargado).toBe(7000);
    expect(r.ticketPromedio).toBe(2767);
    expect(r.porTipo.paseo).toEqual({ servicios: 2, comision: 576 });
    expect(r.porTipo.transporte).toEqual({ servicios: 0, comision: 0 });
  });

  it("sin servicios no divide entre cero", () => {
    expect(resumirFinanzas([], []).ticketPromedio).toBe(0);
  });
});

describe("plazo de reclamos", () => {
  const r = (dias: number, estado = "recibido"): Reclamo => ({
    id: "1",
    numero: "R-2026-000001",
    tipo: "reclamo",
    consumidor: { nombre: "", documento: "", correo: "", domicilio: "" },
    servicioId: null,
    montoReclamado: null,
    detalle: "",
    pedido: "",
    estado,
    creadoEn: null,
    venceEn: new Date(AHORA.getTime() + dias * 86_400_000),
  });

  it("clasifica por días restantes", () => {
    expect(urgenciaReclamo(r(10), AHORA)).toBe("a_tiempo");
    expect(urgenciaReclamo(r(2), AHORA)).toBe("por_vencer");
    expect(urgenciaReclamo(r(-1), AHORA)).toBe("vencido");
    expect(urgenciaReclamo(r(-1, "respondido"), AHORA)).toBe("atendido");
    expect(textoPlazo(r(2), AHORA)).toBe("Quedan 2 d");
    expect(textoPlazo(r(-3), AHORA)).toBe("Vencido hace 3 d");
  });
});

it("nombre del mes en hora de Lima", async () => {
  const { nombreMes } = await import("../src/dominio/formato");
  expect(nombreMes(new Date("2026-12-01T02:00:00Z"))).toBe("Noviembre 2026");
});
