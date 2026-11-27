/**
 * Datos de prueba para ver el panel con los emuladores (proyecto demo-mican).
 * NO usar contra un proyecto real: solo corre si apunta a los emuladores.
 *
 *   cd functions && npm run serve          # en otra terminal
 *   cd admin && npm run sembrar
 *
 * Crea:
 *  - admin@mican.pe / mican123 con el claim admin
 *  - 4 cuidadores en revisión (6 h, 21 h, 44 h y 50 h), 1 incompleto y 1 rechazado
 *  - 2 aprobados este mes, servicios completados con comisión, recargas y 2 reclamos
 */
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { Timestamp, getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";

const HOST = process.env.HOST_EMULADOR || "127.0.0.1";
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= `${HOST}:9099`;
process.env.FIRESTORE_EMULATOR_HOST ??= `${HOST}:8080`;
process.env.FIREBASE_STORAGE_EMULATOR_HOST ??= `${HOST}:9199`;
const PROYECTO = process.env.GCLOUD_PROJECT || "demo-mican";
if (!PROYECTO.startsWith("demo-")) throw new Error("Este script solo es para los emuladores (proyecto demo-*)");

initializeApp({ projectId: PROYECTO, storageBucket: `${PROYECTO}.appspot.com` });
const auth = getAuth();
const db = getFirestore();
const bucket = getStorage().bucket();

const ahora = Date.now();
const hace = (h) => Timestamp.fromMillis(ahora - h * 3_600_000);
const en = (h) => Timestamp.fromMillis(ahora + h * 3_600_000);

/** Imagen SVG de relleno con el nombre del documento. */
function imagen(titulo, color) {
  return Buffer.from(
    `<svg xmlns="http://www.w3.org/2000/svg" width="640" height="420"><rect width="640" height="420" fill="${color}"/>` +
      `<rect x="30" y="30" width="580" height="360" rx="24" fill="#fff" opacity=".85"/>` +
      `<text x="320" y="215" font-family="sans-serif" font-size="34" text-anchor="middle" fill="#164F5D">${titulo}</text></svg>`,
  );
}

async function admin() {
  const correo = "admin@mican.pe";
  let u;
  try {
    u = await auth.getUserByEmail(correo);
  } catch {
    u = await auth.createUser({ email: correo, password: "mican123", displayName: "Equipo Mican" });
  }
  await auth.setCustomUserClaims(u.uid, { admin: true });
}

const CUIDADORES = [
  { uid: "demo-cq", nombre: "Carlos Quispe García", dni: "79512345", edad: 24, distrito: "Miraflores", horas: 6, cv: true },
  { uid: "demo-lr", nombre: "Lucía Ramos", dni: "40112233", edad: 31, distrito: "Surco", horas: 21 },
  { uid: "demo-ds", nombre: "Diego Salas", dni: "45667788", edad: 27, distrito: "San Borja", horas: 44 },
  { uid: "demo-ap", nombre: "Andrea Paz", dni: "70998877", edad: 22, distrito: "Barranco", horas: 50 },
  { uid: "demo-mt", nombre: "Mateo Torres", dni: "71234567", edad: 20, distrito: "Lince", estado: "incompleta" },
  { uid: "demo-vr", nombre: "Valeria Rojas", dni: "72345678", edad: 26, distrito: "Jesús María", estado: "rechazada" },
  { uid: "demo-jc", nombre: "Jorge Castillo", dni: "73456789", edad: 35, distrito: "La Molina", estado: "aprobada" },
  { uid: "demo-sm", nombre: "Sofía Medina", dni: "74567890", edad: 29, distrito: "San Isidro", estado: "aprobada" },
];

async function cuidador(c) {
  const estado = c.estado ?? "en_revision";
  const tipos = ["dniFrente", "dniReverso", "antecedentes", "selfie", ...(c.cv ? ["cv"] : [])];
  const subidos = estado === "incompleta" ? ["dniFrente", "dniReverso"] : tipos;
  const archivos = {};
  for (const t of subidos) {
    const ruta = `verificaciones/${c.uid}/${t}`;
    const color = t === "selfie" ? "#FDE6D3" : t === "antecedentes" ? "#D8F1E4" : "#D3E7ED";
    await bucket.file(ruta).save(imagen(`${t} · ${c.nombre}`, color), { contentType: "image/svg+xml" });
    archivos[t] = ruta;
  }
  const docEstado = (t) => {
    if (!subidos.includes(t)) return "pendiente";
    if (estado === "en_revision") return "en_revision";
    if (estado === "aprobada") return "listo";
    if (estado === "rechazada") return t === "antecedentes" ? "rechazado" : "subido";
    return "subido";
  };
  const documentos = Object.fromEntries(["dniFrente", "dniReverso", "antecedentes", "selfie", "cv"].map((t) => [t, docEstado(t)]));
  const enviado = c.horas ?? 70;
  await db.doc(`verificaciones/${c.uid}`).set({
    estado,
    documentos,
    archivos,
    creadoEn: hace(enviado + 2),
    actualizadoEn: hace(estado === "incompleta" ? 3 : enviado),
    enviadoEn: estado === "incompleta" ? null : hace(enviado),
    venceRevisionEn: estado === "incompleta" ? null : en(48 - enviado),
    motivoRechazo: estado === "rechazada" ? "El certificado de antecedentes está vencido." : null,
    revisadoEn: estado === "aprobada" || estado === "rechazada" ? hace(20) : null,
  });
  await db.doc(`usuarios/${c.uid}`).set({
    nombre: c.nombre,
    dni: c.dni,
    telefono: `+519${c.dni.slice(0, 8)}`,
    roles: { dueno: false, cuidador: true },
    estadoCuenta: "activa",
  });
  await db.doc(`perfilesPublicos/${c.uid}`).set({
    nombre: c.nombre,
    edad: c.edad,
    distrito: c.distrito,
    fotoUrl: null,
    esCuidador: true,
    verificado: estado === "aprobada",
  });
}

async function finanzas() {
  const servicios = [
    ["paseo", "Firulais", 2800, 30],
    ["paseo", "Luna", 2000, 50],
    ["visita", "Michi", 3500, 70],
    ["transporte", "Rocky", 4500, 90],
    ["paseo", "Toby", 2500, 110],
  ];
  for (const [i, [tipo, mascota, precio, h]] of servicios.entries()) {
    const comision = Math.round(precio * 0.12);
    await db.doc(`servicios/demo-s${i}`).set({
      tipo,
      estado: "completado",
      duenoNombre: "Ana Torres",
      cuidadorNombre: "Jorge Castillo",
      cuidadorId: "demo-jc",
      duenoId: "demo-dueno",
      participantes: ["demo-jc", "demo-dueno"],
      mascota: { nombre: mascota },
      precioFinal: precio,
      comision,
      comisionTasa: 0.12,
      metodoPago: i % 2 ? "efectivo" : "yape",
      creadoEn: hace(h + 2),
      finalizadoEn: hace(h),
    });
  }
  for (const [i, monto] of [2000, 5000, 10000].entries()) {
    await db.doc(`pagos/demo-p${i}`).set({ uid: "demo-jc", tipo: "recarga", monto, estado: "pagado", creadoEn: hace(100 + i), pagadoEn: hace(100 + i) });
  }
}

async function reclamos() {
  const base = {
    uid: "demo-dueno",
    consumidor: { nombre: "Ana Torres", documento: "DNI 41234567", correo: "ana@example.com", domicilio: "Av. Larco 123, Miraflores" },
    servicioId: "demo-s0",
    estado: "recibido",
    respuesta: null,
  };
  await db.doc("reclamos/demo-r1").set({
    ...base,
    numero: "R-2026-000001",
    tipo: "reclamo",
    montoReclamado: 2800,
    detalle: "El paseo duró 20 minutos en vez de 30 y no se enviaron fotos.",
    pedido: "Devolución parcial del pago.",
    creadoEn: hace(24 * 18),
    venceEn: en(24 * 2),
  });
  await db.doc("reclamos/demo-r2").set({
    ...base,
    numero: "R-2026-000002",
    tipo: "queja",
    montoReclamado: null,
    detalle: "El soporte tardó mucho en responder en el chat.",
    pedido: "Mejorar los tiempos de respuesta.",
    creadoEn: hace(30),
    venceEn: en(24 * 19),
  });
}

await admin();
for (const c of CUIDADORES) await cuidador(c);
await finanzas();
await reclamos();
console.log("Listo. Entra a http://localhost:5173 con admin@mican.pe / mican123");
