import { describe, expect, it } from "vitest";
import {
  documentoConforme,
  documentosObservados,
  estadoFila,
  filtrarFilas,
  horasRestantes,
  indicadoresDeLista,
  prepararDecision,
  resumenDocumentos,
  textoTiempo,
} from "../src/dominio/verificacion";
import { AHORA, cuidador, horasAntes, verificacion } from "./fabricas";

const TODO = { selfie: true, dni: true, delitos: true, vigencia: true };

describe("estado de la fila", () => {
  it("pendiente, vence pronto (40 h) y vencido (48 h)", () => {
    expect(estadoFila(verificacion({ enviadoEn: horasAntes(6) }), AHORA)).toBe("pendiente");
    expect(estadoFila(verificacion({ enviadoEn: horasAntes(39.9) }), AHORA)).toBe("pendiente");
    expect(estadoFila(verificacion({ enviadoEn: horasAntes(40) }), AHORA)).toBe("vence_pronto");
    expect(estadoFila(verificacion({ enviadoEn: horasAntes(48) }), AHORA)).toBe("vencido");
  });

  it("refleja los demás estados del backend", () => {
    expect(estadoFila(verificacion({ estado: "incompleta" }), AHORA)).toBe("incompleto");
    expect(estadoFila(verificacion({ estado: "rechazada" }), AHORA)).toBe("rechazado");
    expect(estadoFila(verificacion({ estado: "aprobada" }), AHORA)).toBe("aprobado");
  });
});

describe("tiempo", () => {
  it("muestra horas en espera y lo que queda del plazo", () => {
    expect(textoTiempo(verificacion({ enviadoEn: horasAntes(6) }), AHORA)).toEqual({ principal: "6 h", detalle: "quedan 42 h" });
    expect(textoTiempo(verificacion({ enviadoEn: horasAntes(49.5) }), AHORA)).toEqual({
      principal: "49 h",
      detalle: "vencido hace 2 h",
    });
  });

  it("sin fecha de envío no hay tiempo", () => {
    expect(textoTiempo(verificacion({ enviadoEn: null }), AHORA)).toEqual({ principal: "—", detalle: null });
    expect(horasRestantes(verificacion({ enviadoEn: null }), AHORA)).toBeNull();
  });
});

describe("resumen de documentos", () => {
  it("cuenta los 4 obligatorios y menciona el CV", () => {
    expect(resumenDocumentos(verificacion())).toBe("4 de 4");
    expect(resumenDocumentos(verificacion({ documentos: { ...verificacion().documentos, cv: "en_revision" } }))).toBe(
      "4 de 4 (CV incluido)",
    );
  });

  it("dice qué falta", () => {
    const v = verificacion({ documentos: { dniFrente: "subido", dniReverso: "subido", antecedentes: "subido", selfie: "pendiente" } });
    expect(resumenDocumentos(v)).toBe("3 de 4 · falta selfie");
    expect(resumenDocumentos(verificacion({ documentos: { dniFrente: "subido" } }))).toBe("1 de 4 · faltan 3");
  });
});

describe("búsqueda", () => {
  const filas = [
    { verificacion: verificacion(), cuidador: cuidador() },
    { verificacion: verificacion({ uid: "lr" }), cuidador: cuidador({ uid: "lr", nombre: "Lucía Ramos", dni: "40112233" }) },
  ];
  it("por nombre sin importar tildes ni mayúsculas", () => {
    expect(filtrarFilas(filas, "LUCIA").map((f) => f.cuidador!.uid)).toEqual(["lr"]);
  });
  it("por DNI", () => {
    expect(filtrarFilas(filas, "7951").map((f) => f.cuidador!.uid)).toEqual(["cq"]);
  });
  it("vacía devuelve todo", () => {
    expect(filtrarFilas(filas, "  ")).toHaveLength(2);
  });
});

it("indicadores de la cola", () => {
  const lista = [verificacion({ enviadoEn: horasAntes(2) }), verificacion({ enviadoEn: horasAntes(41) }), verificacion({ enviadoEn: horasAntes(50) })];
  expect(indicadoresDeLista(lista, AHORA)).toEqual({ pendientes: 3, vencenPronto: 2 });
});

describe("checklist", () => {
  it("cada documento depende de sus puntos", () => {
    expect(documentoConforme("selfie", { selfie: true })).toBe(true);
    expect(documentoConforme("antecedentes", { delitos: true })).toBe(false);
    expect(documentoConforme("antecedentes", { delitos: true, vigencia: true })).toBe(true);
  });

  it("lo no marcado queda observado", () => {
    expect(documentosObservados({ selfie: true, dni: true })).toEqual(["antecedentes"]);
    expect(documentosObservados({})).toEqual(["dniFrente", "dniReverso", "antecedentes", "selfie"]);
    expect(documentosObservados(TODO)).toEqual([]);
  });
});

describe("decisión (datos para revisarCuidador)", () => {
  it("aprobar exige el checklist completo", () => {
    expect(prepararDecision("cq", true, { selfie: true }, "")).toEqual({
      ok: false,
      error: "Marca todos los puntos del checklist para aprobar",
    });
    expect(prepararDecision("cq", true, TODO, "")).toEqual({ ok: true, datos: { uid: "cq", aprobar: true } });
  });

  it("rechazar exige motivo y pide rehacer lo no marcado", () => {
    expect(prepararDecision("cq", false, {}, "   ").ok).toBe(false);
    expect(prepararDecision("cq", false, { selfie: true, dni: true, delitos: true }, " Certificado vencido ")).toEqual({
      ok: true,
      datos: { uid: "cq", aprobar: false, motivo: "Certificado vencido", documentosARehacer: ["antecedentes"] },
    });
  });

  it("no deja rechazar con todo conforme (el backend exige al menos un documento)", () => {
    const d = prepararDecision("cq", false, TODO, "Motivo");
    expect(d.ok).toBe(false);
  });

  it("limita el motivo a 500 caracteres como el backend", () => {
    expect(prepararDecision("cq", false, {}, "x".repeat(501)).ok).toBe(false);
  });
});
