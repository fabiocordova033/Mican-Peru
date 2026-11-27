const DIA_MS = 86_400_000;

export function sumarDias(fecha: Date, dias: number): Date {
  return new Date(fecha.getTime() + dias * DIA_MS);
}

export function sumarHoras(fecha: Date, horas: number): Date {
  return new Date(fecha.getTime() + horas * 3_600_000);
}

export function sumarSegundos(fecha: Date, s: number): Date {
  return new Date(fecha.getTime() + s * 1000);
}

/**
 * Suma días hábiles (lunes a viernes). No descuenta feriados nacionales:
 * para producción, agregar el calendario de feriados del Perú.
 */
export function sumarDiasHabiles(fecha: Date, dias: number, feriados: string[] = []): Date {
  const r = new Date(fecha.getTime());
  let n = 0;
  while (n < dias) {
    r.setUTCDate(r.getUTCDate() + 1);
    const dia = r.getUTCDay();
    const iso = r.toISOString().slice(0, 10);
    if (dia !== 0 && dia !== 6 && !feriados.includes(iso)) n++;
  }
  return r;
}

/** Edad cumplida a una fecha, desde "AAAA-MM-DD". */
export function edadEnAnios(fechaNacimiento: string, hoy = new Date()): number {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(fechaNacimiento);
  if (!m) throw new Error("Fecha de nacimiento inválida (usa AAAA-MM-DD)");
  const [a, mes, d] = [Number(m[1]), Number(m[2]), Number(m[3])];
  const nac = new Date(Date.UTC(a, mes - 1, d));
  if (nac.getUTCMonth() !== mes - 1 || nac.getUTCDate() !== d) {
    throw new Error("Fecha de nacimiento inválida");
  }
  let edad = hoy.getUTCFullYear() - a;
  const antesDelCumple =
    hoy.getUTCMonth() < mes - 1 || (hoy.getUTCMonth() === mes - 1 && hoy.getUTCDate() < d);
  if (antesDelCumple) edad--;
  return edad;
}
