import { Reclamo } from "./tipos";

export type Urgencia = "a_tiempo" | "por_vencer" | "vencido" | "atendido";

/** Días (calendario) que quedan del plazo legal de 15 días hábiles. */
export function diasRestantes(r: Reclamo, ahora: Date): number | null {
  if (!r.venceEn) return null;
  return Math.ceil((r.venceEn.getTime() - ahora.getTime()) / 86_400_000);
}

export function urgenciaReclamo(r: Reclamo, ahora: Date): Urgencia {
  if (r.estado !== "recibido") return "atendido";
  const d = diasRestantes(r, ahora);
  if (d === null) return "a_tiempo";
  if (d < 0) return "vencido";
  if (d <= 3) return "por_vencer";
  return "a_tiempo";
}

export function textoPlazo(r: Reclamo, ahora: Date): string {
  if (r.estado !== "recibido") return "Atendido";
  const d = diasRestantes(r, ahora);
  if (d === null) return "—";
  if (d < 0) return `Vencido hace ${-d} d`;
  if (d === 0) return "Vence hoy";
  return `Quedan ${d} d`;
}
