/**
 * Reglas del panel para la verificación de cuidadores (HU-03, HU-04).
 * Lógica pura: sin Firebase, para poder probarla.
 */
import { horasEntre, normalizar } from "./formato";
import {
  Cuidador,
  DOCUMENTOS_OBLIGATORIOS,
  TipoDocumento,
  Verificacion,
} from "./tipos";

/** Mismo plazo que functions/src/config/reglas.ts (PLAZO_REVISION_HORAS). */
export const PLAZO_REVISION_HORAS = 48;
/** Desde aquí el panel avisa "Vence pronto". */
export const AVISO_VENCE_HORAS = 40;

export type EstadoFila = "pendiente" | "vence_pronto" | "vencido" | "incompleto" | "rechazado" | "aprobado";

export const ETIQUETA_ESTADO: Record<EstadoFila, string> = {
  pendiente: "Pendiente",
  vence_pronto: "Vence pronto",
  vencido: "Vencido",
  incompleto: "Incompleto",
  rechazado: "Rechazado",
  aprobado: "Aprobado",
};

export const NOMBRE_DOCUMENTO: Record<TipoDocumento, string> = {
  dniFrente: "DNI · anverso",
  dniReverso: "DNI · reverso",
  antecedentes: "Antecedentes policiales",
  selfie: "Selfie",
  cv: "CV",
};

const NOMBRE_CORTO: Record<TipoDocumento, string> = {
  dniFrente: "DNI anverso",
  dniReverso: "DNI reverso",
  antecedentes: "antecedentes",
  selfie: "selfie",
  cv: "CV",
};

/** Un documento cuenta como entregado si ya llegó a Storage (en cualquier etapa posterior). */
export function estaEntregado(v: Verificacion, t: TipoDocumento): boolean {
  const e = v.documentos[t];
  return e === "subido" || e === "en_revision" || e === "listo";
}

/** Horas desde que el cuidador envió a revisión. */
export function horasEnEspera(v: Verificacion, ahora: Date): number | null {
  return v.enviadoEn ? horasEntre(v.enviadoEn, ahora) : null;
}

/** Horas que quedan del plazo de 48 h (negativo si ya venció). */
export function horasRestantes(v: Verificacion, ahora: Date): number | null {
  const vence = v.venceRevisionEn ?? (v.enviadoEn ? new Date(v.enviadoEn.getTime() + PLAZO_REVISION_HORAS * 3_600_000) : null);
  if (!vence) return null;
  const ms = vence.getTime() - ahora.getTime();
  return ms >= 0 ? Math.floor(ms / 3_600_000) : -Math.ceil(-ms / 3_600_000);
}

export function estadoFila(v: Verificacion, ahora: Date): EstadoFila {
  switch (v.estado) {
    case "aprobada":
      return "aprobado";
    case "rechazada":
    case "revocada":
      return "rechazado";
    case "incompleta":
      return "incompleto";
    case "en_revision": {
      const h = horasEnEspera(v, ahora) ?? 0;
      if (h >= PLAZO_REVISION_HORAS) return "vencido";
      if (h >= AVISO_VENCE_HORAS) return "vence_pronto";
      return "pendiente";
    }
  }
}

/** "4 de 4 (CV incluido)", "3 de 4 · falta selfie", "1 de 4 · faltan 3". */
export function resumenDocumentos(v: Verificacion): string {
  const total = DOCUMENTOS_OBLIGATORIOS.length;
  const faltan = DOCUMENTOS_OBLIGATORIOS.filter((t) => !estaEntregado(v, t));
  let texto = `${total - faltan.length} de ${total}`;
  if (faltan.length === 1) texto += ` · falta ${NOMBRE_CORTO[faltan[0]!]}`;
  else if (faltan.length > 1) texto += ` · faltan ${faltan.length}`;
  else if (estaEntregado(v, "cv")) texto += " (CV incluido)";
  return texto;
}

/** Texto de la columna "Tiempo": horas en espera y lo que queda del plazo. */
export function textoTiempo(v: Verificacion, ahora: Date): { principal: string; detalle: string | null } {
  const h = horasEnEspera(v, ahora);
  if (h === null) return { principal: "—", detalle: null };
  if (v.estado !== "en_revision") return { principal: `${h} h`, detalle: null };
  const r = horasRestantes(v, ahora)!;
  return { principal: `${h} h`, detalle: r >= 0 ? `quedan ${r} h` : `vencido hace ${-r} h` };
}

export interface Fila {
  verificacion: Verificacion;
  cuidador: Cuidador | null;
}

/** Busca por nombre (sin tildes) o por DNI. */
export function filtrarFilas(filas: Fila[], busqueda: string): Fila[] {
  const q = normalizar(busqueda);
  if (!q) return filas;
  const soloDigitos = /^\d+$/.test(q);
  return filas.filter(({ cuidador }) => {
    if (!cuidador) return false;
    if (soloDigitos) return (cuidador.dni ?? "").includes(q);
    return normalizar(cuidador.nombre).includes(q);
  });
}

/** Indicadores de la cabecera calculados con la lista en revisión. */
export function indicadoresDeLista(enRevision: Verificacion[], ahora: Date) {
  return {
    pendientes: enRevision.length,
    vencenPronto: enRevision.filter((v) => (horasEnEspera(v, ahora) ?? 0) >= AVISO_VENCE_HORAS).length,
  };
}

// ---------------------------------------------------------------------------
// Checklist de revisión
// ---------------------------------------------------------------------------

export interface PuntoChecklist {
  id: string;
  texto: string;
  /** Documentos que quedan observados si este punto no se cumple. */
  documentos: TipoDocumento[];
}

export const CHECKLIST: PuntoChecklist[] = [
  { id: "selfie", texto: "La foto del DNI coincide con la selfie", documentos: ["selfie"] },
  { id: "dni", texto: "El DNI es legible y está vigente", documentos: ["dniFrente", "dniReverso"] },
  { id: "delitos", texto: "El certificado de antecedentes no registra delitos", documentos: ["antecedentes"] },
  { id: "vigencia", texto: "El certificado tiene menos de 3 meses", documentos: ["antecedentes"] },
];

export type Marcas = Record<string, boolean>;

/** Un documento está conforme cuando todos los puntos del checklist que lo tocan están marcados. */
export function documentoConforme(t: TipoDocumento, marcas: Marcas): boolean {
  return CHECKLIST.filter((p) => p.documentos.includes(t)).every((p) => marcas[p.id] === true);
}

/** Los documentos obligatorios que el cuidador tendría que volver a subir. */
export function documentosObservados(marcas: Marcas): TipoDocumento[] {
  return DOCUMENTOS_OBLIGATORIOS.filter((t) => !documentoConforme(t, marcas));
}

export const checklistCompleto = (marcas: Marcas) => CHECKLIST.every((p) => marcas[p.id] === true);

export type Decision =
  | { ok: true; datos: { uid: string; aprobar: true } }
  | { ok: true; datos: { uid: string; aprobar: false; motivo: string; documentosARehacer: TipoDocumento[] } }
  | { ok: false; error: string };

/**
 * Arma los datos para la Cloud Function `revisarCuidador`, con las mismas
 * validaciones que el backend para avisar antes de llamarla.
 */
export function prepararDecision(uid: string, aprobar: boolean, marcas: Marcas, motivo: string): Decision {
  if (aprobar) {
    if (!checklistCompleto(marcas)) return { ok: false, error: "Marca todos los puntos del checklist para aprobar" };
    return { ok: true, datos: { uid, aprobar: true } };
  }
  const m = motivo.trim();
  if (!m) return { ok: false, error: "Escribe el motivo del rechazo: el cuidador lo verá en la app" };
  if (m.length > 500) return { ok: false, error: "El motivo puede tener hasta 500 caracteres" };
  const rehacer = documentosObservados(marcas);
  if (!rehacer.length) {
    return { ok: false, error: "Desmarca en el checklist lo que no cumple, así el cuidador sabe qué volver a subir" };
  }
  return { ok: true, datos: { uid, aprobar: false, motivo: m, documentosARehacer: rehacer } };
}

/** Archivo PDF o imagen, según la extensión de la ruta en Storage. */
export function esPdf(ruta: string | undefined): boolean {
  return !!ruta && /\.pdf$/i.test(ruta);
}
