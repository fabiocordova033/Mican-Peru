/**
 * Flujo completo contra los emuladores (Auth, Firestore, Functions):
 * registro -> verificación -> recarga -> solicitud -> oferta -> paseo ->
 * comisión del 12 % -> calificaciones -> nivel.
 *
 *   npm run test:integracion
 */
import { initializeApp as initAdmin } from "firebase-admin/app";
import { getFirestore as adminDb } from "firebase-admin/firestore";
import { createHmac } from "node:crypto";

const PROYECTO = "demo-mican";
const REGION = "southamerica-east1";
const SECRETO = "secreto-de-prueba";
const AUTH = "http://127.0.0.1:9099";
const FUNCIONES = `http://127.0.0.1:5001/${PROYECTO}/${REGION}`;
initAdmin({ projectId: PROYECTO });
const db = adminDb();

async function post(url: string, body: unknown, token?: string) {
  const res = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json", ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify(body),
  });
  return { status: res.status, json: (await res.json().catch(() => null)) as any };
}

/** Inicia sesión con SMS en el emulador de Auth (HU-01) y devuelve el idToken. */
async function iniciarSesionSms(telefono: string): Promise<{ uid: string; token: string }> {
  const envio = await post(`${AUTH}/identitytoolkit.googleapis.com/v1/accounts:sendVerificationCode?key=demo`, {
    phoneNumber: telefono,
    recaptchaToken: "ignorado",
  });
  const codigos: any = await (await fetch(`${AUTH}/emulator/v1/projects/${PROYECTO}/verificationCodes`)).json();
  const { code } = codigos.verificationCodes.filter((c: any) => c.sessionInfo === envio.json.sessionInfo)[0];
  const r = await post(`${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPhoneNumber?key=demo`, {
    sessionInfo: envio.json.sessionInfo,
    code,
  });
  return { uid: r.json.localId, token: r.json.idToken };
}

/** Crea un usuario y devuelve una función para llamar callables como él. */
async function cliente(telefono: string, claims?: object) {
  let sesion = await iniciarSesionSms(telefono);
  if (claims) {
    await post(
      `${AUTH}/identitytoolkit.googleapis.com/v1/projects/${PROYECTO}/accounts:update`,
      { localId: sesion.uid, customAttributes: JSON.stringify(claims) },
      "owner",
    );
    sesion = await iniciarSesionSms(telefono);
  }
  const llamar = async (nombre: string, datos: unknown = {}): Promise<any> => {
    const r = await post(`${FUNCIONES}/${nombre}`, { data: datos }, sesion.token);
    if (r.json?.error) throw new Error(`${nombre}: ${r.json.error.message}`);
    return r.json.result;
  };
  return { llamar, uid: sesion.uid };
}

async function webhook(pagoId: string, monto: number, estado = "pagado") {
  const cuerpo = JSON.stringify({ referencia: pagoId, estado, montoCentimos: monto });
  const res = await fetch(`http://127.0.0.1:5001/${PROYECTO}/${REGION}/webhookPagos`, {
    method: "POST",
    headers: { "content-type": "application/json", "x-mican-firma": createHmac("sha256", SECRETO).update(cuerpo).digest("hex") },
    body: cuerpo,
  });
  return res.status;
}

const consentimientos = { versionTerminos: "2026-11-01", versionPrivacidad: "2026-11-01", aceptaTerminos: true, aceptaPrivacidad: true };
const MIRAFLORES = { lat: -12.1211, lng: -77.0297, direccion: "Parque Kennedy" };

jest.setTimeout(60_000);

test("flujo completo de un paseo", async () => {
  const dueno = await cliente("+51911111111");
  const cuidador = await cliente("+51931945511");
  const admin = await cliente("+51999999999", { admin: true });
  const carlos = cuidador.uid;

  // HU-28: menores de edad no pueden registrarse.
  await expect(
    dueno.llamar("completarRegistro", { ...consentimientos, nombre: "Ana", rol: "dueno", fechaNacimiento: "2012-01-01" }),
  ).rejects.toThrow(/18/);
  await dueno.llamar("completarRegistro", { ...consentimientos, nombre: "Ana", rol: "dueno", fechaNacimiento: "1995-04-10" });
  await cuidador.llamar("completarRegistro", {
    ...consentimientos, nombre: "Carlos Quispe", rol: "cuidador", fechaNacimiento: "2002-05-10", aceptaDatosSensibles: true,
  });

  // HU-06: 1 mascota sin Premium.
  const { id: mascotaId } = await dueno.llamar("crearMascota", { nombre: "Firulais", especie: "perro", tamano: "mediano", temperamento: ["Reactivo con perros"] });
  await expect(dueno.llamar("crearMascota", { nombre: "Michi", especie: "gato", tamano: "pequeno" })).rejects.toThrow(/Premium/);

  // HU-03 / HU-04: verificación (simulamos que los archivos ya se subieron).
  await expect(cuidador.llamar("enviarAVerificacion", { dni: "79512536" })).rejects.toThrow(/Faltan/);
  await db.doc(`verificaciones/${carlos}`).update({
    "documentos.dniFrente": "subido", "documentos.dniReverso": "subido", "documentos.antecedentes": "subido", "documentos.selfie": "subido",
  });
  await cuidador.llamar("enviarAVerificacion", { dni: "79512536" });
  await expect(cuidador.llamar("revisarCuidador", { uid: carlos, aprobar: true })).rejects.toThrow(/administradores/);
  await admin.llamar("revisarCuidador", { uid: carlos, aprobar: true });
  await cuidador.llamar("cambiarDisponibilidad", { disponible: true });

  // HU-12: sin saldo, aviso para recargar.
  const sinSaldo = await cuidador.llamar("listarSolicitudesCercanas", MIRAFLORES);
  expect(sinSaldo.recargar).toBe(true);

  // HU-21: recarga de S/ 20 por webhook (idempotente).
  const { pagoId } = await cuidador.llamar("iniciarRecarga", { monto: 2000 });
  expect(await webhook(pagoId, 2000)).toBe(200);
  expect(await webhook(pagoId, 2000)).toBe(200);
  expect((await db.doc(`billeteras/${carlos}`).get()).get("saldo")).toBe(2000);

  // HU-10: solicitud con precio dentro del rango.
  const { rango } = await dueno.llamar("cotizar", { tipo: "paseo", duracionMin: 60 });
  await expect(
    dueno.llamar("crearSolicitud", { mascotaId, tipo: "paseo", modalidad: "oferta", duracionMin: 60, precio: rango.piso - 100, origen: MIRAFLORES, metodoPago: "yape" }),
  ).rejects.toThrow(/bajo/);
  const { id: servicioId } = await dueno.llamar("crearSolicitud", {
    mascotaId, tipo: "paseo", modalidad: "oferta", duracionMin: 60, precio: 2500, origen: MIRAFLORES, metodoPago: "yape",
  });

  // HU-12 / HU-13: el cuidador la ve y contraoferta +S/ 3 = S/ 28.
  const cerca = await cuidador.llamar("listarSolicitudesCercanas", { lat: -12.122, lng: -77.03 });
  expect(cerca.solicitudes.map((s: any) => s.id)).toContain(servicioId);
  expect(cerca.solicitudes[0].mascota.alertas).toContain("Reactivo con perros");
  const oferta = await cuidador.llamar("enviarOferta", { servicioId, precio: 2800, lat: -12.122, lng: -77.03 });
  expect(oferta).toMatchObject({ comision: 336, recibes: 2464 });

  // HU-14: el dueño acepta; el teléfono queda visible.
  await dueno.llamar("aceptarOferta", { servicioId, cuidadorId: carlos });
  const contacto = await db.doc(`servicios/${servicioId}/privado/contacto`).get();
  expect(contacto.get("telefonoCuidador")).toBe("+51931945511");

  // HU-15: iniciar solo cerca del recojo.
  await expect(cuidador.llamar("iniciarServicio", { servicioId, lat: -12.13, lng: -77.03 })).rejects.toThrow(/100 m/);
  await cuidador.llamar("iniciarServicio", { servicioId, lat: -12.1212, lng: -77.0297 });
  await db.collection(`servicios/${servicioId}/ruta`).add({ lat: -12.125, lng: -77.03, registradoEn: new Date() });

  // HU-15 / HU-22: al finalizar se descuenta S/ 3.36 del saldo.
  const resumen = await cuidador.llamar("finalizarServicio", { servicioId });
  expect(resumen).toMatchObject({ precio: 2800, comision: 336, metodoPago: "yape", saldo: 2000 - 336 });
  const movs = await db.collection(`billeteras/${carlos}/movimientos`).orderBy("creadoEn").get();
  expect(movs.docs.map((m) => [m.get("tipo"), m.get("monto")])).toEqual([["recarga", 2000], ["comision", -336]]);

  // HU-24: la primera calificación queda oculta; con la segunda se revelan.
  const r1 = await dueno.llamar("calificar", { servicioId, estrellas: 5, etiquetas: ["Puntual", "Cariñoso"] });
  expect(r1.revelada).toBe(false);
  const r2 = await cuidador.llamar("calificar", { servicioId, estrellas: 5, etiquetas: ["Buena comunicación"] });
  expect(r2.revelada).toBe(true);
  const perfil = (await db.doc(`perfilesPublicos/${carlos}`).get()).data()!;
  expect(perfil).toMatchObject({ numResenas: 1, calificacionPromedio: 5, serviciosCompletados: 1, nivel: "nuevo" });
  expect(perfil.etiquetas).toMatchObject({ Puntual: 1, Cariñoso: 1 });

  // HU-30: Libro de Reclamaciones con número correlativo.
  const reclamo = await dueno.llamar("presentarReclamo", {
    tipo: "reclamo", nombre: "Ana", documento: "12345678", correo: "ana@example.com", servicioId, detalle: "Llegó tarde", pedido: "Descuento",
  });
  expect(reclamo.numero).toMatch(/^R-\d{4}-000001$/);

  // HU-32: con saldo, primero se ofrece la devolución.
  await expect(cuidador.llamar("eliminarCuenta", { confirmacion: "ELIMINAR" })).rejects.toThrow(/devolución/);
  const eliminada = await dueno.llamar("eliminarCuenta", { confirmacion: "ELIMINAR" });
  expect(eliminada.eliminarEn).toBeGreaterThan(Date.now());
  await dueno.llamar("recuperarCuenta");
});
