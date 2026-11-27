/**
 * Todo lo que el panel lee o hace en Firebase pasa por esta interfaz.
 * Las pantallas la reciben por contexto, así las pruebas usan una versión falsa.
 *
 * Lecturas: Firestore directo (las reglas permiten leer a quien tiene el claim admin).
 * Acciones: Cloud Functions de administración (`revisarCuidador`,
 * `enlacesDocumentosVerificacion`), que vuelven a comprobar el claim.
 */
import { createContext, useContext } from "react";
import type {
  Cuidador,
  EstadoVerificacion,
  Reclamo,
  Recarga,
  ServicioCompletado,
  TipoDocumento,
  Verificacion,
} from "../dominio/tipos";

export interface DatosRevision {
  uid: string;
  aprobar: boolean;
  motivo?: string;
  documentosARehacer?: TipoDocumento[];
}

export interface ApiPanel {
  /** Lista en vivo de verificaciones con cierto estado (máx. 200). */
  observarVerificaciones(estado: EstadoVerificacion, cb: (v: Verificacion[]) => void, error: (e: Error) => void): () => void;
  /** Cuántas verificaciones quedaron en ese estado con revisión desde la fecha. */
  contarRevisadas(estado: "aprobada" | "rechazada", desde: Date): Promise<number>;
  /** Perfil público + DNI y teléfono (documento privado) de cada cuidador. */
  cuidadores(uids: string[]): Promise<Map<string, Cuidador>>;
  observarVerificacion(uid: string, cb: (v: Verificacion | null) => void, error: (e: Error) => void): () => void;
  /** Enlaces temporales para ver los documentos (15 min). */
  enlacesDocumentos(v: Verificacion): Promise<Partial<Record<TipoDocumento, string>>>;
  revisarCuidador(d: DatosRevision): Promise<void>;
  reclamos(): Promise<Reclamo[]>;
  finanzas(desde: Date, hasta: Date): Promise<{ servicios: ServicioCompletado[]; recargas: Recarga[]; truncado: boolean }>;
}

export const ContextoApi = createContext<ApiPanel | null>(null);

export function useApi(): ApiPanel {
  const api = useContext(ContextoApi);
  if (!api) throw new Error("Falta <ContextoApi.Provider>");
  return api;
}

/** Mensaje en español a partir de un error de Firebase. */
export function mensajeError(e: unknown): string {
  const err = e as { code?: string; message?: string };
  const code = err?.code ?? "";
  if (code.endsWith("permission-denied")) return "No tienes permiso de administrador para esto.";
  if (code.endsWith("unavailable")) return "No hay conexión con Firebase. ¿Están corriendo los emuladores?";
  if (code.endsWith("failed-precondition") && err.message?.includes("index"))
    return "Falta un índice de Firestore. Despliega firestore.indexes.json.";
  // Las Cloud Functions de Mican ya responden en español.
  if (code.startsWith("functions/") && err.message) return err.message;
  return err?.message || "Ocurrió un error inesperado.";
}
