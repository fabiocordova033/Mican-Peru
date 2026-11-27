import { VACUNA_AVISO_DIAS } from "../config/reglas";

export interface Vacuna {
  nombre: string;
  /** Fecha de aplicación AAAA-MM-DD. */
  aplicada: string;
  /** Fecha de vencimiento AAAA-MM-DD. */
  vence: string;
}

export type EstadoVacuna = "vigente" | "por_vencer" | "vencida";

/** HU-07: verde si está vigente, ámbar si vence en menos de 30 días. */
export function estadoVacuna(v: Vacuna, hoy = new Date()): EstadoVacuna {
  const vence = new Date(`${v.vence}T23:59:59Z`).getTime();
  if (Number.isNaN(vence)) throw new Error("Fecha de vencimiento inválida");
  const dias = (vence - hoy.getTime()) / 86_400_000;
  if (dias < 0) return "vencida";
  if (dias < VACUNA_AVISO_DIAS) return "por_vencer";
  return "vigente";
}

/** "Vacunas al día" solo si hay vacunas y ninguna está vencida. */
export function vacunasAlDia(vacunas: Vacuna[], hoy = new Date()): boolean {
  return vacunas.length > 0 && vacunas.every((v) => estadoVacuna(v, hoy) !== "vencida");
}
