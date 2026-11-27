/** Resumen de comisiones y recargas de un mes (montos en céntimos). */
import { Recarga, ServicioCompletado } from "./tipos";

export interface ResumenFinanzas {
  servicios: number;
  movido: number;
  comision: number;
  recibenCuidadores: number;
  recargas: number;
  montoRecargado: number;
  ticketPromedio: number;
  porTipo: Record<ServicioCompletado["tipo"], { servicios: number; comision: number }>;
}

export function resumirFinanzas(servicios: ServicioCompletado[], recargas: Recarga[]): ResumenFinanzas {
  const porTipo: ResumenFinanzas["porTipo"] = {
    paseo: { servicios: 0, comision: 0 },
    visita: { servicios: 0, comision: 0 },
    transporte: { servicios: 0, comision: 0 },
  };
  let movido = 0;
  let comision = 0;
  for (const s of servicios) {
    movido += s.precioFinal;
    comision += s.comision;
    const t = porTipo[s.tipo];
    if (t) {
      t.servicios += 1;
      t.comision += s.comision;
    }
  }
  const montoRecargado = recargas.reduce((a, r) => a + r.monto, 0);
  return {
    servicios: servicios.length,
    movido,
    comision,
    recibenCuidadores: movido - comision,
    recargas: recargas.length,
    montoRecargado,
    ticketPromedio: servicios.length ? Math.round(movido / servicios.length) : 0,
    porTipo,
  };
}
