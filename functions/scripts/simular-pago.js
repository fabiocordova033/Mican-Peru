/**
 * Simula el webhook de la pasarela para una recarga o un pago de Premium.
 * Usa el mismo secreto que functions/.secret.local (PAGOS_WEBHOOK_SECRET).
 *
 *   node scripts/simular-pago.js <pagoId> <montoCentimos> [pagado|fallido]
 */
const { createHmac } = require("node:crypto");
const { readFileSync } = require("node:fs");
const { join } = require("node:path");

const [pagoId, monto, estado = "pagado"] = process.argv.slice(2);
if (!pagoId || !monto) {
  console.error("Uso: node scripts/simular-pago.js <pagoId> <montoCentimos> [pagado|fallido]");
  process.exit(1);
}
const secreto =
  process.env.PAGOS_WEBHOOK_SECRET ||
  /PAGOS_WEBHOOK_SECRET=(.*)/.exec(readFileSync(join(__dirname, "..", ".secret.local"), "utf8"))[1].trim();
const url = process.env.WEBHOOK_URL || "http://127.0.0.1:5001/demo-mican/southamerica-east1/webhookPagos";
const cuerpo = JSON.stringify({
  referencia: pagoId,
  estado,
  montoCentimos: Number(monto),
  motivo: estado === "fallido" ? "Fondos insuficientes" : undefined,
});
fetch(url, {
  method: "POST",
  headers: { "content-type": "application/json", "x-mican-firma": createHmac("sha256", secreto).update(cuerpo).digest("hex") },
  body: cuerpo,
}).then(async (r) => console.log(r.status, await r.text()));
