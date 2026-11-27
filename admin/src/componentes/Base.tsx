import type { ReactNode } from "react";
import { iniciales } from "../dominio/formato";

export type TonoChip = "acento" | "primario" | "error" | "gris" | "exito";

export function Chip({ tono, children }: { tono: TonoChip; children: ReactNode }) {
  return <span className={`chip chip-${tono}`}>{children}</span>;
}

export function Avatar({ nombre, foto, tam = 36 }: { nombre: string; foto?: string | null; tam?: number }) {
  return (
    <span className="avatar" style={{ width: tam, height: tam, fontSize: tam * 0.4 }} aria-hidden="true">
      {foto ? <img src={foto} alt="" /> : iniciales(nombre)}
    </span>
  );
}

export type TonoIndicador = "primario" | "error" | "exito" | "gris";

export function Indicador({ valor, etiqueta, tono }: { valor: ReactNode; etiqueta: string; tono: TonoIndicador }) {
  return (
    <div className="tarjeta indicador">
      <div className={`indicador-valor texto-${tono}`}>{valor}</div>
      <div className="indicador-etiqueta">{etiqueta}</div>
    </div>
  );
}

export function Aviso({ tono = "error", children }: { tono?: "error" | "info"; children: ReactNode }) {
  return (
    <div className={`aviso aviso-${tono}`} role={tono === "error" ? "alert" : "status"}>
      {children}
    </div>
  );
}

export function Cargando({ texto = "Cargando…" }: { texto?: string }) {
  return (
    <div className="cargando" role="status">
      <span className="spinner" aria-hidden="true" />
      {texto}
    </div>
  );
}
