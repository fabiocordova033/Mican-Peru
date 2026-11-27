import { DISTANCIA_INICIO_METROS, VELOCIDAD_LLEGADA_KMH } from "../config/reglas";

export interface Punto {
  lat: number;
  lng: number;
}

const RADIO_TIERRA_KM = 6371;
const rad = (g: number) => (g * Math.PI) / 180;

/** Distancia en km entre dos puntos (fórmula de Haversine). */
export function distanciaKm(a: Punto, b: Punto): number {
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * RADIO_TIERRA_KM * Math.asin(Math.sqrt(h));
}

/** Suma la distancia de una ruta (lista ordenada de puntos). */
export function distanciaRutaKm(ruta: Punto[]): number {
  let total = 0;
  for (let i = 1; i < ruta.length; i++) total += distanciaKm(ruta[i - 1], ruta[i]);
  return total;
}

export function esPuntoValido(p: unknown): p is Punto {
  if (!p || typeof p !== "object") return false;
  const { lat, lng } = p as Record<string, unknown>;
  return (
    typeof lat === "number" &&
    typeof lng === "number" &&
    lat >= -90 &&
    lat <= 90 &&
    lng >= -180 &&
    lng <= 180
  );
}

/** HU-15: "Iniciar" solo a menos de 100 m del punto de recojo. */
export function puedeIniciar(cuidador: Punto, recojo: Punto): boolean {
  return distanciaKm(cuidador, recojo) * 1000 <= DISTANCIA_INICIO_METROS;
}

/** Minutos estimados de llegada (mínimo 1). */
export function minutosLlegada(km: number): number {
  return Math.max(1, Math.ceil((km / VELOCIDAD_LLEGADA_KMH) * 60));
}
