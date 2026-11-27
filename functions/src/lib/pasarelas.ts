import { crearMercadoPago } from "./mercadopago";
import { ConfigPasarela, Pasarela, crearSimulada } from "./pasarela";

/** Elige la pasarela según `PASARELA` ("simulada" | "mercadopago"). */
export function obtenerPasarela(cfg: ConfigPasarela): Pasarela {
  switch (cfg.nombre) {
    case "simulada":
      return crearSimulada(cfg.secretoWebhook);
    case "mercadopago":
      return crearMercadoPago(cfg);
    default:
      throw new Error(`Pasarela no implementada: ${cfg.nombre}`);
  }
}
