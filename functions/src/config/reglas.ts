/**
 * Reglas de negocio de Mican en un solo lugar.
 *
 * Todos los montos de dinero se guardan en CÉNTIMOS (enteros) para evitar
 * errores de redondeo con decimales: S/ 28.00 = 2800.
 *
 * Los valores marcados como PROVISIONAL vienen de las historias de usuario y
 * se validarán con usuarios en el piloto.
 */

/** Comisión base de Mican sobre el precio final de cada servicio completado. */
export const COMISION_BASE = 0.12;

/**
 * Comisión reducida por nivel (PROVISIONAL). Desactivada por defecto: mientras
 * esté en `false`, todos los cuidadores pagan el 12 %.
 */
export const COMISION_REDUCIDA_HABILITADA = false;
export const COMISION_POR_NIVEL: Record<Nivel, number> = {
  nuevo: 0.12,
  confiable: 0.12,
  experto: 0.12,
  embajador: 0.1,
};

/** Saldo mínimo para recibir solicitudes, ofertar o aceptar (PROVISIONAL). */
export const SALDO_MINIMO_CENTIMOS = 10_00;

/** Límites de recarga (PROVISIONAL). */
export const RECARGA_MIN_CENTIMOS = 10_00;
export const RECARGA_MAX_CENTIMOS = 500_00;
export const RECARGAS_RAPIDAS_CENTIMOS = [20_00, 50_00, 100_00];

/** Radio en el que un cuidador ve solicitudes (PROVISIONAL). */
export const RADIO_BUSQUEDA_KM = 3;

/** Tiempo de vida de una oferta del cuidador (PROVISIONAL). */
export const OFERTA_EXPIRA_SEGUNDOS = 60;

/** Si no llega ninguna oferta en este tiempo, se sugiere subir el precio. */
export const SUGERIR_SUBIR_PRECIO_SEGUNDOS = 3 * 60;

/** Una solicitud sin cuidador se cierra sola pasado este tiempo. */
export const SOLICITUD_EXPIRA_MINUTOS = 15;

/** El precio ofrecido no puede ser menor a este % del mínimo sugerido. */
export const PRECIO_MINIMO_PORCENTAJE = 0.7;

/** Contraofertas rápidas del cuidador: +S/ 2, +S/ 5, +S/ 8. */
export const CONTRAOFERTAS_RAPIDAS_CENTIMOS = [2_00, 5_00, 8_00];

/** "Iniciar" se habilita a menos de esta distancia del punto de recojo. */
export const DISTANCIA_INICIO_METROS = 100;

/** El teléfono y el chat siguen visibles este tiempo tras terminar. */
export const CONTACTO_VISIBLE_HORAS = 24;
export const CHAT_ABIERTO_HORAS = 24;

/** Plazo para calificar; pasado este plazo las calificaciones se revelan. */
export const PLAZO_CALIFICAR_DIAS = 7;

/** Etiquetas predefinidas para calificar. */
export const ETIQUETAS_CALIFICACION = [
  "Puntual",
  "Cariñoso",
  "Responsable",
  "Buena comunicación",
  "Envió fotos",
  "Cuidadoso",
] as const;
export const COMENTARIO_MAX_CARACTERES = 300;

/** Revisión de documentos del cuidador. */
export const PLAZO_REVISION_HORAS = 48;

/** Mascotas por plan. */
export const MASCOTAS_MAX_GRATIS = 1;
export const MASCOTAS_MAX_PREMIUM = 5;

/** Historial visible sin Premium. */
export const HISTORIAL_GRATIS_DIAS = 30;

/** Premium. */
export const PREMIUM_PRECIO_CENTIMOS = 7_50;
export const PREMIUM_PRUEBA_DIAS = 7;
export const PREMIUM_PERIODO_DIAS = 30;

/** Vacuna "por vencer" si vence en menos de estos días. */
export const VACUNA_AVISO_DIAS = 30;

/** Legal. */
export const EDAD_MINIMA = 18;
export const ELIMINACION_GRACIA_DIAS = 30;
export const RECLAMO_PLAZO_DIAS_HABILES = 15;
export const ARCO_PLAZO_DIAS_HABILES = 20;
export const TEXTO_CONFIRMAR_ELIMINACION = "ELIMINAR";

/**
 * Versiones vigentes de los documentos legales. Si se cambia una versión, a
 * los usuarios que aceptaron la anterior se les pide aceptar de nuevo (HU-28).
 */
export const VERSION_TERMINOS = "2026-11-01";
export const VERSION_PRIVACIDAD = "2026-11-01";

/** Niveles del cuidador (HU-25, PROVISIONAL). */
export type Nivel = "nuevo" | "confiable" | "experto" | "embajador";

export interface ReglaNivel {
  nivel: Nivel;
  serviciosMin: number;
  calificacionMin: number;
  /** Días sin incidentes requeridos (0 = no aplica). */
  diasSinIncidentes: number;
}

/** Ordenadas de mayor a menor. */
export const REGLAS_NIVEL: ReglaNivel[] = [
  { nivel: "embajador", serviciosMin: 150, calificacionMin: 4.8, diasSinIncidentes: 90 },
  { nivel: "experto", serviciosMin: 50, calificacionMin: 4.7, diasSinIncidentes: 0 },
  { nivel: "confiable", serviciosMin: 10, calificacionMin: 4.5, diasSinIncidentes: 0 },
  { nivel: "nuevo", serviciosMin: 0, calificacionMin: 0, diasSinIncidentes: 0 },
];

/** Tipos de servicio del MVP. */
export type TipoServicio = "paseo" | "visita" | "transporte";
export type Especie = "perro" | "gato";

/**
 * Tarifas para el rango sugerido (PROVISIONAL, en céntimos).
 * precio = base + porMinuto * minutos + porKm * km
 */
export const TARIFAS: Record<TipoServicio, { base: number; porMinuto: number; porKm: number }> = {
  paseo: { base: 10_00, porMinuto: 25, porKm: 0 },
  visita: { base: 12_00, porMinuto: 20, porKm: 50 },
  transporte: { base: 8_00, porMinuto: 10, porKm: 150 },
};
/** El rango sugerido va de -X % a +X % del precio calculado. */
export const RANGO_SUGERIDO_VARIACION = 0.12;

/** Paquetes fijos (HU-11, PROVISIONAL, en céntimos). */
export const PAQUETES_FIJOS: Record<TipoServicio, Record<30 | 60 | 120, number>> = {
  paseo: { 30: 15_00, 60: 25_00, 120: 45_00 },
  visita: { 30: 20_00, 60: 30_00, 120: 50_00 },
  transporte: { 30: 25_00, 60: 35_00, 120: 55_00 },
};

/** Velocidad promedio usada para estimar minutos de llegada. */
export const VELOCIDAD_LLEGADA_KMH = 20;
