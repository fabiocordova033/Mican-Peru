/** Tipos que reflejan los documentos de Firestore (ver docs/modelo-de-datos.md). */

export const DOCUMENTOS_OBLIGATORIOS = ["dniFrente", "dniReverso", "antecedentes", "selfie"] as const;
export const DOCUMENTOS = [...DOCUMENTOS_OBLIGATORIOS, "cv"] as const;
export type TipoDocumento = (typeof DOCUMENTOS)[number];

export type EstadoVerificacion = "incompleta" | "en_revision" | "aprobada" | "rechazada" | "revocada";
export type EstadoDocumento = "pendiente" | "subido" | "en_revision" | "listo" | "rechazado";

export interface Verificacion {
  uid: string;
  estado: EstadoVerificacion;
  documentos: Partial<Record<TipoDocumento, EstadoDocumento>>;
  /** Rutas en Storage: verificaciones/{uid}/{tipo}[.ext] */
  archivos: Partial<Record<TipoDocumento, string>>;
  enviadoEn: Date | null;
  venceRevisionEn: Date | null;
  actualizadoEn: Date | null;
  revisadoEn: Date | null;
  motivoRechazo: string | null;
}

/** Lo que el panel muestra del cuidador: perfil público + DNI del documento privado. */
export interface Cuidador {
  uid: string;
  nombre: string;
  edad: number | null;
  distrito: string | null;
  fotoUrl: string | null;
  dni: string | null;
  telefono: string | null;
}

export interface Reclamo {
  id: string;
  numero: string;
  tipo: "reclamo" | "queja";
  consumidor: { nombre: string; documento: string; correo: string; domicilio: string };
  servicioId: string | null;
  montoReclamado: number | null;
  detalle: string;
  pedido: string;
  estado: string;
  creadoEn: Date | null;
  venceEn: Date | null;
}

export interface ServicioCompletado {
  id: string;
  tipo: "paseo" | "visita" | "transporte";
  duenoNombre: string;
  cuidadorNombre: string;
  mascotaNombre: string;
  precioFinal: number;
  comision: number;
  comisionTasa: number;
  metodoPago: string;
  finalizadoEn: Date | null;
}

export interface Recarga {
  id: string;
  monto: number;
  pagadoEn: Date | null;
}
