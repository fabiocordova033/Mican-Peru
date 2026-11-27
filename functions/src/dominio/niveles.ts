import { Nivel, REGLAS_NIVEL } from "../config/reglas";

export interface EstadisticasCuidador {
  serviciosCompletados: number;
  /** Promedio de estrellas (0 si no tiene reseñas). */
  calificacionPromedio: number;
  /** Fecha del último incidente, si hubo. */
  ultimoIncidente?: Date | null;
}

function cumple(
  regla: (typeof REGLAS_NIVEL)[number],
  e: EstadisticasCuidador,
  ahora: Date,
): boolean {
  if (e.serviciosCompletados < regla.serviciosMin) return false;
  if (regla.calificacionMin > 0 && e.calificacionPromedio < regla.calificacionMin) return false;
  if (regla.diasSinIncidentes > 0 && e.ultimoIncidente) {
    const dias = (ahora.getTime() - e.ultimoIncidente.getTime()) / 86_400_000;
    if (dias < regla.diasSinIncidentes) return false;
  }
  return true;
}

/** HU-25: nivel que corresponde según servicios, calificación e incidentes. */
export function calcularNivel(e: EstadisticasCuidador, ahora = new Date()): Nivel {
  for (const regla of REGLAS_NIVEL) {
    if (cumple(regla, e, ahora)) return regla.nivel;
  }
  return "nuevo";
}

export interface ProgresoNivel {
  nivelActual: Nivel;
  siguiente: Nivel | null;
  serviciosFaltantes: number;
  calificacionRequerida: number | null;
  requiereSinIncidentesDias: number;
}

/** HU-25: "En Cuenta veo cuánto me falta para el siguiente nivel". */
export function progresoNivel(e: EstadisticasCuidador, ahora = new Date()): ProgresoNivel {
  const actual = calcularNivel(e, ahora);
  const ascendente = [...REGLAS_NIVEL].reverse();
  const i = ascendente.findIndex((r) => r.nivel === actual);
  const sig = ascendente[i + 1];
  if (!sig) {
    return {
      nivelActual: actual,
      siguiente: null,
      serviciosFaltantes: 0,
      calificacionRequerida: null,
      requiereSinIncidentesDias: 0,
    };
  }
  return {
    nivelActual: actual,
    siguiente: sig.nivel,
    serviciosFaltantes: Math.max(0, sig.serviciosMin - e.serviciosCompletados),
    calificacionRequerida: sig.calificacionMin || null,
    requiereSinIncidentesDias: sig.diasSinIncidentes,
  };
}
