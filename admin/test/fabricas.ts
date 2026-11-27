import type { Cuidador, Verificacion } from "../src/dominio/tipos";

export const AHORA = new Date("2026-11-27T14:12:00Z"); // 27 nov 09:12 en Lima
export const horasAntes = (h: number) => new Date(AHORA.getTime() - h * 3_600_000);

export function verificacion(p: Partial<Verificacion> = {}): Verificacion {
  const enviadoEn = p.enviadoEn === undefined ? horasAntes(6) : p.enviadoEn;
  return {
    uid: "cq",
    estado: "en_revision",
    documentos: { dniFrente: "en_revision", dniReverso: "en_revision", antecedentes: "en_revision", selfie: "en_revision", cv: "pendiente" },
    archivos: {
      dniFrente: "verificaciones/cq/dniFrente.jpg",
      dniReverso: "verificaciones/cq/dniReverso.jpg",
      antecedentes: "verificaciones/cq/antecedentes.pdf",
      selfie: "verificaciones/cq/selfie.jpg",
    },
    enviadoEn,
    venceRevisionEn: enviadoEn ? new Date(enviadoEn.getTime() + 48 * 3_600_000) : null,
    actualizadoEn: enviadoEn,
    revisadoEn: null,
    motivoRechazo: null,
    ...p,
  };
}

export function cuidador(p: Partial<Cuidador> = {}): Cuidador {
  return {
    uid: "cq",
    nombre: "Carlos Quispe García",
    edad: 24,
    distrito: "Miraflores",
    fotoUrl: null,
    dni: "79512345",
    telefono: "+51987654321",
    ...p,
  };
}
