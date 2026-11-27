/**
 * Épica 2: mascotas. HU-06, HU-07.
 * Se crean por función (y no directo desde la app) para poder aplicar el
 * límite de 1 mascota sin Premium y 5 con Premium.
 */
import { onCall } from "firebase-functions/v2/https";
import { Especie, MASCOTAS_MAX_GRATIS, MASCOTAS_MAX_PREMIUM } from "../config/reglas";
import { Vacuna, estadoVacuna, vacunasAlDia } from "../dominio/vacunas";
import { textoRequerido } from "../dominio/validaciones";
import { datos, falla, requiereUsuario } from "../lib/errores";
import { COL, FieldValue, REGION, db } from "../lib/firebase";
import { esPremium, refUsuario } from "../lib/usuarios";

const TAMANOS = ["pequeno", "mediano", "grande"] as const;

/** Etiquetas de temperamento que se resaltan como alerta al cuidador (HU-08). */
export const ETIQUETAS_ALERTA = [
  "Reactivo con perros",
  "Reactivo con gatos",
  "Reactivo con personas",
  "Muerde",
  "Se escapa",
];

interface EntradaMascota {
  nombre: string;
  especie: Especie;
  raza: string;
  tamano: (typeof TAMANOS)[number];
  edadAnios: number;
  pesoKg: number;
  fotoUrl: string;
  vacunas: Vacuna[];
  temperamento: string[];
  notas: string;
}

/** Valida y normaliza. `parcial` permite omitir obligatorios (para editar). */
function normalizar(d: Partial<EntradaMascota>, parcial: boolean): Record<string, unknown> {
  const r: Record<string, unknown> = {};
  if (!parcial || d.nombre !== undefined) {
    const n = textoRequerido(d.nombre, 40);
    if (!n) falla("invalid-argument", "El nombre es obligatorio");
    r.nombre = n;
  }
  if (!parcial || d.especie !== undefined) {
    if (d.especie !== "perro" && d.especie !== "gato") falla("invalid-argument", "Elige perro o gato");
    r.especie = d.especie;
  }
  if (!parcial || d.tamano !== undefined) {
    if (!TAMANOS.includes(d.tamano as never)) falla("invalid-argument", "Elige el tamaño");
    r.tamano = d.tamano;
  }
  if (d.raza !== undefined) r.raza = typeof d.raza === "string" ? d.raza.trim().slice(0, 60) : "";
  if (d.edadAnios !== undefined) {
    if (typeof d.edadAnios !== "number" || d.edadAnios < 0 || d.edadAnios > 40) falla("invalid-argument", "Edad inválida");
    r.edadAnios = d.edadAnios;
  }
  if (d.pesoKg !== undefined) {
    if (typeof d.pesoKg !== "number" || d.pesoKg <= 0 || d.pesoKg > 120) falla("invalid-argument", "Peso inválido");
    r.pesoKg = d.pesoKg;
  }
  if (d.fotoUrl !== undefined) r.fotoUrl = typeof d.fotoUrl === "string" ? d.fotoUrl : null;
  if (d.temperamento !== undefined) {
    if (!Array.isArray(d.temperamento) || d.temperamento.some((t) => typeof t !== "string")) {
      falla("invalid-argument", "Temperamento inválido");
    }
    r.temperamento = d.temperamento.slice(0, 10);
    r.alertas = d.temperamento.filter((t) => ETIQUETAS_ALERTA.includes(t));
  }
  if (d.notas !== undefined) r.notas = typeof d.notas === "string" ? d.notas.slice(0, 500) : "";
  if (d.vacunas !== undefined) {
    if (!Array.isArray(d.vacunas)) falla("invalid-argument", "Vacunas inválidas");
    try {
      const vacunas = d.vacunas.map((v) => ({
        nombre: String(v.nombre).slice(0, 60),
        aplicada: String(v.aplicada),
        vence: String(v.vence),
        estado: estadoVacuna(v),
      }));
      r.vacunas = vacunas;
      r.vacunasAlDia = vacunasAlDia(vacunas);
    } catch {
      falla("invalid-argument", "Revisa las fechas de las vacunas (AAAA-MM-DD)");
    }
  }
  return r;
}

/** HU-06. */
export const crearMascota = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const valores = normalizar(datos<EntradaMascota>(req), false);
  const ref = db.collection(COL.mascotas).doc();
  await db.runTransaction(async (tx) => {
    const usuario = await tx.get(refUsuario(uid));
    if (!usuario.exists) falla("failed-precondition", "Completa tu registro primero");
    const premium = esPremium(usuario.data());
    const max = premium ? MASCOTAS_MAX_PREMIUM : MASCOTAS_MAX_GRATIS;
    const actuales = await tx.get(
      db.collection(COL.mascotas).where("duenoId", "==", uid).where("activa", "==", true),
    );
    if (actuales.size >= max) {
      falla("resource-exhausted", premium ? `Puedes registrar hasta ${max} mascotas` : "Con Premium puedes registrar más mascotas", {
        invitarPremium: !premium,
      });
    }
    tx.set(ref, {
      raza: "",
      edadAnios: null,
      pesoKg: null,
      fotoUrl: null,
      vacunas: [],
      vacunasAlDia: false,
      temperamento: [],
      alertas: [],
      notas: "",
      ...valores,
      duenoId: uid,
      activa: true,
      creadoEn: FieldValue.serverTimestamp(),
    });
  });
  return { id: ref.id };
});

export const actualizarMascota = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const d = datos<EntradaMascota & { id: string }>(req);
  if (typeof d.id !== "string") falla("invalid-argument", "Falta la mascota");
  const ref = db.collection(COL.mascotas).doc(d.id);
  const snap = await ref.get();
  if (!snap.exists || snap.get("duenoId") !== uid) falla("not-found", "Mascota no encontrada");
  const { id: _id, ...resto } = d;
  await ref.update({ ...normalizar(resto, true), actualizadoEn: FieldValue.serverTimestamp() });
  return { ok: true };
});

/** Se archiva (no se borra) para no romper el historial de servicios. */
export const archivarMascota = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const { id } = datos<{ id: string }>(req);
  if (typeof id !== "string") falla("invalid-argument", "Falta la mascota");
  const ref = db.collection(COL.mascotas).doc(id);
  const snap = await ref.get();
  if (!snap.exists || snap.get("duenoId") !== uid) falla("not-found", "Mascota no encontrada");
  await ref.update({ activa: false });
  return { ok: true };
});
