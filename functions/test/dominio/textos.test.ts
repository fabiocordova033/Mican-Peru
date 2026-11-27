import { nombrePublico } from "../../src/dominio/textos";

describe("nombre en reseñas públicas (HU-05, HU-24)", () => {
  it("muestra el primer nombre y la inicial de la segunda palabra", () => {
    expect(nombrePublico("Ana Pérez Gómez")).toBe("Ana P.");
    expect(nombrePublico("  luis   ramos ")).toBe("luis R.");
  });
  it("con una sola palabra la deja tal cual", () => {
    expect(nombrePublico("Ana")).toBe("Ana");
  });
  it("sin nombre usa un texto genérico", () => {
    expect(nombrePublico("")).toBe("Dueño de Mican");
    expect(nombrePublico(undefined)).toBe("Dueño de Mican");
  });
});
