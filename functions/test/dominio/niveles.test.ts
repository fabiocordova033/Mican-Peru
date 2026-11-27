import { calcularNivel, progresoNivel } from "../../src/dominio/niveles";

const hoy = new Date("2026-11-27T12:00:00Z");

describe("niveles del cuidador (HU-25)", () => {
  it.each([
    [0, 0, "nuevo"],
    [9, 5, "nuevo"],
    [10, 4.5, "confiable"],
    [10, 4.4, "nuevo"],
    [50, 4.7, "experto"],
    [50, 4.6, "confiable"],
    [150, 4.8, "embajador"],
    [150, 4.75, "experto"],
  ])("%i servicios y %f estrellas -> %s", (servicios, estrellas, nivel) => {
    expect(calcularNivel({ serviciosCompletados: servicios, calificacionPromedio: estrellas }, hoy)).toBe(nivel);
  });

  it("Embajador exige 90 días sin incidentes", () => {
    const base = { serviciosCompletados: 200, calificacionPromedio: 4.9 };
    expect(calcularNivel({ ...base, ultimoIncidente: new Date("2026-10-01T00:00:00Z") }, hoy)).toBe("experto");
    expect(calcularNivel({ ...base, ultimoIncidente: new Date("2026-06-01T00:00:00Z") }, hoy)).toBe("embajador");
  });

  it("muestra cuánto falta para el siguiente nivel", () => {
    expect(progresoNivel({ serviciosCompletados: 4, calificacionPromedio: 4.9 }, hoy)).toMatchObject({
      nivelActual: "nuevo",
      siguiente: "confiable",
      serviciosFaltantes: 6,
      calificacionRequerida: 4.5,
    });
    expect(progresoNivel({ serviciosCompletados: 300, calificacionPromedio: 5 }, hoy).siguiente).toBeNull();
  });
});
