import {
  COMISION_BASE,
  COMISION_POR_NIVEL,
  COMISION_REDUCIDA_HABILITADA,
  Nivel,
} from "../config/reglas";

/** Convierte soles (número con decimales) a céntimos enteros. */
export function solesACentimos(soles: number): number {
  return Math.round(soles * 100);
}

/** Formato para mostrar: 336 -> "S/ 3.36". */
export function formatearSoles(centimos: number): string {
  const signo = centimos < 0 ? "− " : "";
  return `${signo}S/ ${(Math.abs(centimos) / 100).toFixed(2)}`;
}

/** Tasa de comisión que aplica al cuidador según su nivel. */
export function tasaComision(nivel: Nivel = "nuevo"): number {
  return COMISION_REDUCIDA_HABILITADA ? COMISION_POR_NIVEL[nivel] : COMISION_BASE;
}

/**
 * Comisión de Mican sobre un precio, redondeada al céntimo (HU-22).
 * Ej.: S/ 28 -> S/ 3.36; S/ 25 -> S/ 3.00.
 */
export function calcularComision(precioCentimos: number, tasa = COMISION_BASE): number {
  if (!Number.isInteger(precioCentimos) || precioCentimos < 0) {
    throw new Error("El precio debe ser un entero de céntimos no negativo");
  }
  return Math.round(precioCentimos * tasa);
}

/** Desglose que ve el cuidador antes de enviar su oferta (HU-13). */
export function desgloseOferta(precioCentimos: number, tasa = COMISION_BASE) {
  const comision = calcularComision(precioCentimos, tasa);
  return {
    precio: precioCentimos,
    comision,
    recibes: precioCentimos - comision,
    tasa,
  };
}
