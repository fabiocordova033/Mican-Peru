/**
 * Épica 5 y 7: recarga de saldo del cuidador y suscripción Premium del dueño.
 * HU-21, HU-27, HU-32 (devolución de saldo).
 *
 * Mican no guarda datos de tarjeta. La app abre el checkout de la pasarela
 * (Mercado Pago: Yape, tarjeta o PagoEfectivo) y la pasarela confirma por
 * webhook (`webhookPagos`). Solo el webhook cambia saldos o activa Premium.
 *
 * Configuración (ver README, "Pasarela de pago"):
 *  - Secretos: PAGOS_WEBHOOK_SECRET (clave secreta del webhook) y MP_ACCESS_TOKEN.
 *  - .env: PASARELA, MP_MODO, PAGOS_URL_WEBHOOK, PAGOS_URL_RETORNO.
 */
import { logger } from "firebase-functions/v2";
import { defineSecret } from "firebase-functions/params";
import { onCall, onRequest } from "firebase-functions/v2/https";
import {
  PREMIUM_PERIODO_DIAS,
  PREMIUM_PRECIO_CENTIMOS,
  PREMIUM_PRUEBA_DIAS,
  RECARGA_MAX_CENTIMOS,
  RECARGA_MIN_CENTIMOS,
} from "../config/reglas";
import { formatearSoles } from "../dominio/dinero";
import { sumarDias } from "../dominio/fechas";
import { aplicarMovimiento, leerSaldo } from "../lib/billetera";
import { datos, falla, requiereUsuario } from "../lib/errores";
import { COL, FieldValue, REGION, db, ts } from "../lib/firebase";
import { notificar } from "../lib/notificaciones";
import { decidirEventoPago } from "../dominio/pagos";
import { EventoPago, FirmaInvalida } from "../lib/pasarela";
import { obtenerPasarela } from "../lib/pasarelas";
import { esPremium, refUsuario, usuarioActivo } from "../lib/usuarios";

export const PAGOS_WEBHOOK_SECRET = defineSecret("PAGOS_WEBHOOK_SECRET");
export const MP_ACCESS_TOKEN = defineSecret("MP_ACCESS_TOKEN");
const SECRETOS = [PAGOS_WEBHOOK_SECRET, MP_ACCESS_TOKEN];

/** Lee la configuración en cada llamada (los secretos solo existen en ejecución). */
function pasarela() {
  return obtenerPasarela({
    nombre: process.env.PASARELA || "simulada",
    secretoWebhook: PAGOS_WEBHOOK_SECRET.value(),
    mpAccessToken: MP_ACCESS_TOKEN.value(),
    mpModo: process.env.MP_MODO === "produccion" ? "produccion" : "sandbox",
    urlWebhook: process.env.PAGOS_URL_WEBHOOK || undefined,
    urlRetorno: process.env.PAGOS_URL_RETORNO || undefined,
  });
}

const refPago = (id: string) => db.collection(COL.pagos).doc(id);

/** HU-21: monto rápido (S/ 20, 50, 100) o uno entre S/ 10 y S/ 500. */
export const iniciarRecarga = onCall({ region: REGION, secrets: SECRETOS }, async (req) => {
  const uid = requiereUsuario(req);
  const { monto } = datos<{ monto: number }>(req);
  if (!Number.isInteger(monto) || monto! < RECARGA_MIN_CENTIMOS || monto! > RECARGA_MAX_CENTIMOS) {
    falla("invalid-argument", `Recarga entre ${formatearSoles(RECARGA_MIN_CENTIMOS)} y ${formatearSoles(RECARGA_MAX_CENTIMOS)}`);
  }
  const u = await usuarioActivo(uid);
  if (!u.roles?.cuidador) falla("permission-denied", "Solo los cuidadores recargan saldo");
  const ref = db.collection(COL.pagos).doc();
  const checkout = await pasarela().crearCheckout({
    referencia: ref.id,
    montoCentimos: monto!,
    descripcion: "Recarga de saldo Mican",
    tipo: "recarga",
  });
  await ref.set({
    uid,
    tipo: "recarga",
    monto,
    estado: "pendiente",
    proveedor: checkout.proveedor,
    idCheckout: checkout.idCheckout ?? null,
    creadoEn: FieldValue.serverTimestamp(),
  });
  return { pagoId: ref.id, urlPago: checkout.urlPago };
});

/** HU-27: Premium S/ 7.50/mes con 7 días de prueba la primera vez. */
export const suscribirPremium = onCall({ region: REGION, secrets: SECRETOS }, async (req) => {
  const uid = requiereUsuario(req);
  const u = await usuarioActivo(uid);
  if (esPremium(u) && u.renovacionAutomatica) falla("already-exists", "Ya tienes Premium");
  const ahora = new Date();

  if (!u.usoPruebaPremium) {
    const hasta = sumarDias(ahora, PREMIUM_PRUEBA_DIAS);
    await refUsuario(uid).update({
      plan: "premium",
      premiumHasta: ts(hasta),
      usoPruebaPremium: true,
      renovacionAutomatica: true,
      enPrueba: true,
    });
    return { prueba: true, premiumHasta: hasta.getTime() };
  }
  if (esPremium(u)) {
    // Tenía Premium cancelado pero vigente: solo reactiva la renovación.
    await refUsuario(uid).update({ renovacionAutomatica: true });
    return { reactivado: true };
  }
  const ref = db.collection(COL.pagos).doc();
  const checkout = await pasarela().crearCheckout({
    referencia: ref.id,
    montoCentimos: PREMIUM_PRECIO_CENTIMOS,
    descripcion: "Mican Premium (1 mes)",
    tipo: "premium",
  });
  await ref.set({
    uid,
    tipo: "premium",
    monto: PREMIUM_PRECIO_CENTIMOS,
    estado: "pendiente",
    proveedor: checkout.proveedor,
    idCheckout: checkout.idCheckout ?? null,
    creadoEn: FieldValue.serverTimestamp(),
  });
  return { pagoId: ref.id, urlPago: checkout.urlPago };
});

/** HU-27: cancela la renovación; sigue Premium hasta el fin del periodo. */
export const cancelarPremium = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const u = await usuarioActivo(uid);
  await refUsuario(uid).update({ renovacionAutomatica: false });
  return { premiumHasta: u.premiumHasta?.toMillis?.() ?? null };
});

/**
 * HU-32: el cuidador pide la devolución de su saldo no usado. Lo procesa el
 * equipo de soporte (transferencia manual en el MVP).
 */
export const solicitarDevolucionSaldo = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const d = datos<{ cuentaDestino: string }>(req);
  if (typeof d.cuentaDestino !== "string" || d.cuentaDestino.length < 6) {
    falla("invalid-argument", "Indica tu número de Yape, Plin o cuenta bancaria");
  }
  const saldo = await db.runTransaction((tx) => leerSaldo(tx, uid));
  if (saldo <= 0) falla("failed-precondition", "No tienes saldo para devolver");
  const ref = await db.collection(COL.soporte).add({
    tipo: "devolucion_saldo",
    uid,
    monto: saldo,
    cuentaDestino: d.cuentaDestino,
    estado: "abierto",
    creadoEn: FieldValue.serverTimestamp(),
  });
  return { ticketId: ref.id, monto: saldo };
});

/**
 * Webhook de la pasarela. Verifica la firma, consulta el estado real del pago
 * y lo aplica una sola vez aunque la pasarela reintente. Responde 200 a todo
 * aviso válido (aunque no cambie nada) para que no se reintente; 401 si la
 * firma no corresponde; 500 solo ante errores transitorios, para que sí reintente.
 */
export const webhookPagos = onRequest(
  { region: REGION, secrets: SECRETOS },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Método no permitido");
      return;
    }
    let evento: EventoPago | null;
    try {
      evento = await pasarela().leerWebhook({
        cuerpo: req.rawBody ?? Buffer.alloc(0),
        cabeceras: req.headers,
        query: req.query as Record<string, unknown>,
      });
    } catch (e) {
      if (e instanceof FirmaInvalida) {
        logger.warn("Webhook con firma inválida", { e: String(e) });
        res.status(401).send("Firma inválida");
      } else if (e instanceof SyntaxError || String(e).includes("Evento inválido")) {
        logger.warn("Webhook rechazado", { e: String(e) });
        res.status(400).send("Evento inválido");
      } else {
        logger.error("No se pudo leer el aviso de pago", { e: String(e) });
        res.status(500).send("error");
      }
      return;
    }
    if (!evento) {
      res.status(200).send("ignorado");
      return;
    }
    try {
      const r = await procesarEventoPago(evento);
      res.status(200).send(r);
    } catch (e) {
      logger.error("Error al procesar pago", { e: String(e), referencia: evento.referencia });
      res.status(500).send("error");
    }
  },
);

export type ResultadoPago = "aplicado" | "duplicado" | "fallido" | "revision" | "desconocido";

/** Aplica un evento de pago. Exportada para pruebas y scripts. */
export async function procesarEventoPago(evento: EventoPago): Promise<ResultadoPago> {
  const { referencia: pagoId, estado, montoCentimos, motivo, idExterno } = evento;
  const ahora = new Date();
  const r = await db.runTransaction(async (tx) => {
    const pagoSnap = await tx.get(refPago(pagoId));
    if (!pagoSnap.exists) return { resultado: "desconocido" as const, pago: null };
    const pago = pagoSnap.data()!;
    const decision = decidirEventoPago(
      { estado: pago.estado, monto: pago.monto, idExterno: pago.idExterno },
      { estado, montoCentimos, idExterno },
    );

    if (decision === "duplicado") return { resultado: "duplicado" as const, pago };

    if (decision === "cobro_duplicado" || decision === "monto_distinto") {
      // No se acredita: soporte revisa y, si corresponde, devuelve el dinero.
      tx.set(db.collection(COL.soporte).doc(), {
        tipo: decision === "cobro_duplicado" ? "pago_duplicado" : "pago_monto_distinto",
        uid: pago.uid,
        pagoId,
        idExterno: idExterno ?? null,
        proveedor: pago.proveedor ?? null,
        montoEsperado: pago.monto,
        montoCobrado: montoCentimos,
        estado: "abierto",
        creadoEn: FieldValue.serverTimestamp(),
      });
      return { resultado: "revision" as const, pago };
    }

    if (decision === "marcar_fallido") {
      // HU-21: si el pago falla, el saldo no cambia y se muestra el motivo.
      tx.update(pagoSnap.ref, {
        estado: "fallido",
        motivo: motivo ?? "Pago rechazado",
        idExterno: idExterno ?? null,
        actualizadoEn: ts(ahora),
      });
      return { resultado: "fallido" as const, pago };
    }

    // decision === "acreditar"
    if (pago.tipo === "recarga") {
      const saldo = await leerSaldo(tx, pago.uid);
      aplicarMovimiento(tx, pago.uid, saldo, {
        tipo: "recarga",
        monto: pago.monto,
        descripcion: "Recarga",
        pagoId,
      });
    } else if (pago.tipo === "premium") {
      const usuario = await tx.get(refUsuario(pago.uid));
      const vigente = usuario.get("premiumHasta")?.toDate() as Date | undefined;
      const desde = vigente && vigente > ahora ? vigente : ahora;
      tx.update(usuario.ref, {
        plan: "premium",
        premiumHasta: ts(sumarDias(desde, PREMIUM_PERIODO_DIAS)),
        renovacionAutomatica: true,
        enPrueba: false,
      });
      // Comprobante electrónico SUNAT (boleta) por el cobro: pendiente de integrar con OSE/PSE.
    }
    tx.update(pagoSnap.ref, {
      estado: "pagado",
      motivo: FieldValue.delete(),
      idExterno: idExterno ?? null,
      pagadoEn: ts(ahora),
    });
    return { resultado: "aplicado" as const, pago };
  });

  if (r.resultado === "desconocido") {
    // Un pago que no es de Mican (u otro entorno): no reintentar.
    logger.warn("Aviso de un pago desconocido", { pagoId, idExterno });
  } else if (r.resultado === "revision") {
    logger.error("Pago enviado a revisión", { pagoId, idExterno, montoCentimos });
  } else if (r.resultado === "aplicado") {
    await notificar(
      r.pago.uid,
      r.pago.tipo === "recarga" ? "Recarga exitosa" : "¡Bienvenido a Premium!",
      r.pago.tipo === "recarga" ? `Se agregaron ${formatearSoles(r.pago.monto)} a tu saldo` : "Ya no verás anuncios",
      { tipo: `pago_${r.pago.tipo}` },
    );
  } else if (r.resultado === "fallido") {
    await notificar(r.pago.uid, "Pago no realizado", motivo ?? "El pago fue rechazado", { tipo: "pago_fallido" });
  }
  return r.resultado;
}
