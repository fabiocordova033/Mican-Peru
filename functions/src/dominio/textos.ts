import { Nivel } from "../config/reglas";

export const NOMBRE_NIVEL: Record<Nivel, string> = {
  nuevo: "Nuevo",
  confiable: "Confiable",
  experto: "Experto",
  embajador: "Embajador Mican",
};

/**
 * Nombre que se muestra en una reseña pública: la primera palabra completa y
 * la inicial de la segunda ("Ana Pérez Gómez" -> "Ana P."). Protege la
 * identidad del dueño (HU-05) sin que la reseña pierda credibilidad.
 */
export function nombrePublico(nombre: unknown): string {
  const partes = typeof nombre === "string" ? nombre.trim().split(/\s+/).filter(Boolean) : [];
  if (!partes.length) return "Dueño de Mican";
  const [primero, segundo] = partes;
  return segundo ? `${primero} ${segundo[0].toUpperCase()}.` : primero;
}
