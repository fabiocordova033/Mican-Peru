import {
  PAQUETES_FIJOS,
  PRECIO_MINIMO_PORCENTAJE,
  RANGO_SUGERIDO_VARIACION,
  TARIFAS,
  TipoServicio,
} from "../config/reglas";

export type DuracionPaquete = 30 | 60 | 120;

export interface RangoSugerido {
  /** Céntimos, redondeado al sol. */
  minimo: number;
  maximo: number;
  /** Lo mínimo que el dueño puede ofrecer (70 % del mínimo sugerido). */
  piso: number;
}

const redondearSol = (c: number) => Math.round(c / 100) * 100;

/** HU-10: rango sugerido por tiempo y distancia. */
export function rangoSugerido(
  tipo: TipoServicio,
  duracionMin: number,
  distanciaKm = 0,
): RangoSugerido {
  if (duracionMin <= 0) throw new Error("La duración debe ser mayor a 0");
  const t = TARIFAS[tipo];
  const base = t.base + t.porMinuto * duracionMin + t.porKm * Math.max(0, distanciaKm);
  const minimo = redondearSol(base * (1 - RANGO_SUGERIDO_VARIACION));
  const maximo = redondearSol(base * (1 + RANGO_SUGERIDO_VARIACION));
  const piso = Math.ceil((minimo * PRECIO_MINIMO_PORCENTAJE) / 100) * 100;
  return { minimo, maximo, piso };
}

export type ResultadoPrecio =
  | { ok: true; aviso?: "MENOS_OFERTAS" }
  | { ok: false; motivo: "NO_ENTERO" | "BAJO_PISO" };

/**
 * HU-10: el precio sube o baja de S/ 1 en S/ 1 y no puede ser menor al 70 %
 * del mínimo sugerido. Si es menor al mínimo, se avisa.
 */
export function validarPrecioOfrecido(precioCentimos: number, rango: RangoSugerido): ResultadoPrecio {
  if (!Number.isInteger(precioCentimos) || precioCentimos % 100 !== 0) {
    return { ok: false, motivo: "NO_ENTERO" };
  }
  if (precioCentimos < rango.piso) return { ok: false, motivo: "BAJO_PISO" };
  if (precioCentimos < rango.minimo) return { ok: true, aviso: "MENOS_OFERTAS" };
  return { ok: true };
}

/** HU-11: precio cerrado del paquete. */
export function precioPaquete(tipo: TipoServicio, duracion: DuracionPaquete): number {
  const precio = PAQUETES_FIJOS[tipo][duracion];
  if (precio === undefined) throw new Error("Paquete no existe");
  return precio;
}

export function esDuracionPaquete(d: unknown): d is DuracionPaquete {
  return d === 30 || d === 60 || d === 120;
}
