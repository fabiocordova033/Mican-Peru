/** Formatos para Perú (es-PE, hora de Lima). Montos en céntimos. */

const ZONA = "America/Lima";
const NOMBRES_MES = [
  "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
  "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre",
];
const MESES = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];

/** 2800 -> "S/ 28.00" */
export function soles(centimos: number): string {
  const signo = centimos < 0 ? "-" : "";
  const abs = Math.abs(Math.round(centimos));
  const enteros = Math.floor(abs / 100).toLocaleString("en-US");
  return `${signo}S/ ${enteros}.${String(abs % 100).padStart(2, "0")}`;
}

/** Partes de fecha en la hora de Lima, sin depender de la zona del navegador. */
function partesLima(d: Date) {
  const p = new Intl.DateTimeFormat("en-US", {
    timeZone: ZONA,
    year: "numeric",
    month: "numeric",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(d);
  const v = (t: string) => Number(p.find((x) => x.type === t)?.value);
  return { anio: v("year"), mes: v("month"), dia: v("day"), hora: v("hour"), minuto: v("minute") };
}

/** "27 nov 09:12" */
export function fechaCorta(d: Date | null): string {
  if (!d) return "—";
  const { mes, dia, hora, minuto } = partesLima(d);
  return `${dia} ${MESES[mes - 1]} ${String(hora).padStart(2, "0")}:${String(minuto).padStart(2, "0")}`;
}

/** Inicio del mes (hora de Lima, UTC-5 sin horario de verano) de la fecha dada. */
export function inicioDeMes(d: Date): Date {
  const { anio, mes } = partesLima(d);
  return new Date(Date.UTC(anio, mes - 1, 1, 5, 0, 0));
}

/** Inicio del mes siguiente (hora de Lima). */
export function inicioMesSiguiente(d: Date): Date {
  const { anio, mes } = partesLima(d);
  return new Date(Date.UTC(anio, mes, 1, 5, 0, 0));
}

/** "Noviembre 2026" */
export function nombreMes(d: Date): string {
  const { anio, mes } = partesLima(d);
  return `${NOMBRES_MES[mes - 1]} ${anio}`;
}

/** Horas enteras entre dos fechas (redondeadas hacia abajo, nunca negativas). */
export function horasEntre(desde: Date, hasta: Date): number {
  return Math.max(0, Math.floor((hasta.getTime() - desde.getTime()) / 3_600_000));
}

/** "hace 6 h", "hace 15 min", "hace 2 d" */
export function hace(d: Date | null, ahora: Date): string {
  if (!d) return "—";
  const min = Math.max(0, Math.floor((ahora.getTime() - d.getTime()) / 60_000));
  if (min < 60) return `hace ${min} min`;
  const h = Math.floor(min / 60);
  if (h < 48) return `hace ${h} h`;
  return `hace ${Math.floor(h / 24)} d`;
}

/** "Carlos Quispe García" -> "CQ" */
export function iniciales(nombre: string): string {
  const partes = nombre.trim().split(/\s+/).filter(Boolean);
  if (!partes.length) return "?";
  const dos = partes.length === 1 ? [partes[0]] : [partes[0], partes[1]];
  return dos.map((p) => p[0]!.toLocaleUpperCase("es-PE")).join("");
}

/** "79512345" -> "7951****" (HU-05: el DNI no se muestra completo). */
export function enmascararDni(dni: string | null): string {
  if (!dni) return "sin DNI";
  return dni.slice(0, 4) + "*".repeat(Math.max(0, dni.length - 4));
}

/** Quita tildes y pasa a minúsculas para buscar. */
export function normalizar(texto: string): string {
  return texto.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().trim();
}
