import { edadEnAnios, sumarDiasHabiles } from "../../src/dominio/fechas";
import { esCelularPeruano, esDniValido, esMayorDeEdad, validarCalificacion } from "../../src/dominio/validaciones";
import { estadoVacuna, vacunasAlDia } from "../../src/dominio/vacunas";
import { distanciaKm, puedeIniciar } from "../../src/dominio/geo";
import { puedeTransicionar, servicioAdmiteEspecie } from "../../src/dominio/servicio";

const hoy = new Date("2026-11-27T12:00:00Z");

describe("registro (HU-01, HU-28)", () => {
  it("celular peruano de 9 dígitos que empieza con 9", () => {
    expect(esCelularPeruano("+51931945511")).toBe(true);
    expect(esCelularPeruano("+51831945511")).toBe(false);
    expect(esCelularPeruano("+5193194551")).toBe(false);
    expect(esCelularPeruano("931945511")).toBe(false);
    expect(esCelularPeruano(undefined)).toBe(false);
  });

  it("solo mayores de 18 años", () => {
    expect(esMayorDeEdad("2008-11-27", hoy)).toBe(true);
    expect(esMayorDeEdad("2008-11-28", hoy)).toBe(false);
    expect(edadEnAnios("2002-05-10", hoy)).toBe(24);
    expect(() => edadEnAnios("2002-02-30", hoy)).toThrow();
  });

  it("DNI de 8 dígitos", () => {
    expect(esDniValido("79512536")).toBe(true);
    expect(esDniValido("7951253")).toBe(false);
  });
});

describe("calificaciones (HU-24)", () => {
  it("acepta una calificación válida", () => {
    expect(validarCalificacion({ estrellas: 5, etiquetas: ["Puntual", "Cariñoso"], comentario: "Excelente" })).toBeNull();
  });
  it("rechaza estrellas fuera de rango, etiquetas inventadas y comentarios largos", () => {
    expect(validarCalificacion({ estrellas: 0 })).not.toBeNull();
    expect(validarCalificacion({ estrellas: 4, etiquetas: ["Rápido"] })).not.toBeNull();
    expect(validarCalificacion({ estrellas: 4, comentario: "x".repeat(301) })).not.toBeNull();
  });
  it("con 1 o 2 estrellas pide el motivo", () => {
    expect(validarCalificacion({ estrellas: 2 })).not.toBeNull();
    expect(validarCalificacion({ estrellas: 2, motivo: "Llegó tarde" })).toBeNull();
  });
});

describe("vacunas (HU-07)", () => {
  it("vigente, por vencer y vencida", () => {
    expect(estadoVacuna({ nombre: "Rabia", aplicada: "2026-01-01", vence: "2027-01-01" }, hoy)).toBe("vigente");
    expect(estadoVacuna({ nombre: "Rabia", aplicada: "2025-12-15", vence: "2026-12-15" }, hoy)).toBe("por_vencer");
    expect(estadoVacuna({ nombre: "Rabia", aplicada: "2025-11-01", vence: "2026-11-01" }, hoy)).toBe("vencida");
  });
  it("vacunas al día", () => {
    expect(vacunasAlDia([], hoy)).toBe(false);
    expect(vacunasAlDia([{ nombre: "Rabia", aplicada: "2026-01-01", vence: "2027-01-01" }], hoy)).toBe(true);
  });
});

describe("plazos legales", () => {
  it("15 días hábiles saltan fines de semana", () => {
    // Viernes 27/11/2026 + 15 días hábiles = viernes 18/12/2026
    expect(sumarDiasHabiles(hoy, 15).toISOString().slice(0, 10)).toBe("2026-12-18");
    expect(sumarDiasHabiles(hoy, 1, ["2026-11-30"]).toISOString().slice(0, 10)).toBe("2026-12-01");
  });
});

describe("servicio", () => {
  it("paseo solo para perros (HU-09)", () => {
    expect(servicioAdmiteEspecie("paseo", "gato")).toBe(false);
    expect(servicioAdmiteEspecie("visita", "gato")).toBe(true);
  });
  it("estados válidos", () => {
    expect(puedeTransicionar("buscando", "confirmado")).toBe(true);
    expect(puedeTransicionar("completado", "cancelado")).toBe(false);
    expect(puedeTransicionar("en_curso", "cancelado")).toBe(false);
  });
  it("iniciar solo a menos de 100 m (HU-15)", () => {
    const recojo = { lat: -12.1211, lng: -77.0297 }; // Miraflores
    expect(puedeIniciar({ lat: -12.1215, lng: -77.0299 }, recojo)).toBe(true);
    expect(puedeIniciar({ lat: -12.1231, lng: -77.0297 }, recojo)).toBe(false);
    expect(distanciaKm(recojo, { lat: -12.0464, lng: -77.0428 })).toBeCloseTo(8.4, 0);
  });
});
