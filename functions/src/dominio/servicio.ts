import { Especie, TipoServicio } from "../config/reglas";

/**
 * Estados de un servicio (la solicitud del dueño es el mismo documento):
 *
 *   buscando ──(dueño acepta oferta / cuidador toma paquete)──> confirmado
 *   confirmado ──(cuidador toca Iniciar a < 100 m)──> en_curso
 *   en_curso ──(cuidador toca Finalizar)──> completado
 *   buscando | confirmado ──> cancelado
 *   buscando ──(sin cuidador a tiempo)──> expirado
 */
export type EstadoServicio =
  | "buscando"
  | "confirmado"
  | "en_curso"
  | "completado"
  | "cancelado"
  | "expirado";

const TRANSICIONES: Record<EstadoServicio, EstadoServicio[]> = {
  buscando: ["confirmado", "cancelado", "expirado"],
  confirmado: ["en_curso", "cancelado"],
  en_curso: ["completado"],
  completado: [],
  cancelado: [],
  expirado: [],
};

export function puedeTransicionar(de: EstadoServicio, a: EstadoServicio): boolean {
  return TRANSICIONES[de].includes(a);
}

export const ESTADOS_ACTIVOS: EstadoServicio[] = ["confirmado", "en_curso"];

/** HU-09: paseo solo para perros; visita y transporte para perros y gatos. */
export function servicioAdmiteEspecie(tipo: TipoServicio, especie: Especie): boolean {
  if (tipo === "paseo") return especie === "perro";
  return true;
}

export type MetodoPago = "yape" | "plin" | "efectivo";
export const METODOS_PAGO: MetodoPago[] = ["yape", "plin", "efectivo"];
export const TIPOS_SERVICIO: TipoServicio[] = ["paseo", "visita", "transporte"];
