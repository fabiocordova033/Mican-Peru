import {
  COMENTARIO_MAX_CARACTERES,
  ETIQUETAS_CALIFICACION,
  EDAD_MINIMA,
} from "../config/reglas";
import { edadEnAnios } from "./fechas";

/** HU-01: celular peruano de 9 dígitos que empieza con 9, en E.164 (+51...). */
export function esCelularPeruano(telefono: string | undefined | null): boolean {
  return typeof telefono === "string" && /^\+519\d{8}$/.test(telefono);
}

/** HU-28: solo mayores de 18 años. */
export function esMayorDeEdad(fechaNacimiento: string, hoy = new Date()): boolean {
  return edadEnAnios(fechaNacimiento, hoy) >= EDAD_MINIMA;
}

/** DNI peruano: 8 dígitos. */
export function esDniValido(dni: string): boolean {
  return /^\d{8}$/.test(dni);
}

export interface EntradaCalificacion {
  estrellas: number;
  etiquetas?: string[];
  comentario?: string;
  motivo?: string;
}

/** HU-24: valida estrellas, etiquetas, comentario y motivo con 1-2 estrellas. */
export function validarCalificacion(c: EntradaCalificacion): string | null {
  if (!Number.isInteger(c.estrellas) || c.estrellas < 1 || c.estrellas > 5) {
    return "Las estrellas van de 1 a 5";
  }
  const etiquetas = c.etiquetas ?? [];
  if (!Array.isArray(etiquetas)) return "Etiquetas inválidas";
  for (const e of etiquetas) {
    if (!(ETIQUETAS_CALIFICACION as readonly string[]).includes(e)) return `Etiqueta no permitida: ${e}`;
  }
  if (new Set(etiquetas).size !== etiquetas.length) return "Etiquetas repetidas";
  if (c.comentario !== undefined && typeof c.comentario !== "string") return "Comentario inválido";
  if ((c.comentario ?? "").length > COMENTARIO_MAX_CARACTERES) {
    return `El comentario admite hasta ${COMENTARIO_MAX_CARACTERES} caracteres`;
  }
  if (c.estrellas <= 2 && !(c.motivo ?? "").trim()) {
    return "Con 1 o 2 estrellas debes indicar el motivo";
  }
  return null;
}

/** Texto obligatorio, recortado y con largo máximo. */
export function textoRequerido(valor: unknown, max = 500): string | null {
  if (typeof valor !== "string") return null;
  const t = valor.trim();
  if (!t || t.length > max) return null;
  return t;
}
