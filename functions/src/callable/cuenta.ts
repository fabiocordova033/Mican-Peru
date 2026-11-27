/**
 * Épica 1 y 8: registro, roles, consentimientos y perfil.
 * HU-01, HU-02, HU-05, HU-28, HU-31 (rectificación).
 */
import { onCall } from "firebase-functions/v2/https";
import { VERSION_PRIVACIDAD, VERSION_TERMINOS } from "../config/reglas";
import { edadEnAnios } from "../dominio/fechas";
import { esCelularPeruano, esMayorDeEdad, textoRequerido } from "../dominio/validaciones";
import { datos, falla, requiereUsuario } from "../lib/errores";
import { COL, FieldValue, REGION, db } from "../lib/firebase";
import { refPerfil, refUsuario, usuarioActivo } from "../lib/usuarios";

type Rol = "dueno" | "cuidador";

interface EntradaRegistro {
  nombre: string;
  fechaNacimiento: string;
  rol: Rol;
  versionTerminos: string;
  versionPrivacidad: string;
  aceptaTerminos: boolean;
  aceptaPrivacidad: boolean;
  /** Opcional y separado (HU-28). */
  aceptaPublicidad?: boolean;
  /** Obligatorio para cuidadores: selfie y antecedentes (datos sensibles). */
  aceptaDatosSensibles?: boolean;
}

const consentimiento = (aceptado: boolean, version?: string) => ({
  aceptado,
  version: version ?? null,
  fecha: FieldValue.serverTimestamp(),
});

/** Documentos iniciales de un cuidador: verificación y billetera. */
function inicializarCuidador(tx: FirebaseFirestore.Transaction, uid: string) {
  tx.set(
    db.collection(COL.verificaciones).doc(uid),
    {
      estado: "incompleta",
      documentos: {
        dniFrente: "pendiente",
        dniReverso: "pendiente",
        antecedentes: "pendiente",
        selfie: "pendiente",
        cv: "pendiente",
      },
      creadoEn: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  tx.set(
    db.collection(COL.billeteras).doc(uid),
    { saldo: 0, creadoEn: FieldValue.serverTimestamp() },
    { merge: true },
  );
}

/**
 * HU-01 + HU-02 + HU-28. Se llama justo después de verificar el código SMS
 * con Firebase Auth (la app hace el envío y la verificación del código).
 */
export const completarRegistro = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const d = datos<EntradaRegistro>(req);
  const telefono = req.auth?.token.phone_number;
  if (!esCelularPeruano(telefono)) {
    falla("invalid-argument", "Usa un celular peruano de 9 dígitos que empiece con 9");
  }
  const nombre = textoRequerido(d.nombre, 80);
  if (!nombre) falla("invalid-argument", "Ingresa tu nombre");
  if (d.rol !== "dueno" && d.rol !== "cuidador") falla("invalid-argument", "Elige si eres dueño o cuidador");
  if (typeof d.fechaNacimiento !== "string") falla("invalid-argument", "Ingresa tu fecha de nacimiento");
  try {
    if (!esMayorDeEdad(d.fechaNacimiento)) falla("failed-precondition", "Mican es solo para mayores de 18 años");
  } catch (e) {
    if (e instanceof Error && e.message.startsWith("Fecha")) falla("invalid-argument", e.message);
    throw e;
  }
  if (d.aceptaTerminos !== true || d.aceptaPrivacidad !== true) {
    falla("failed-precondition", "Debes aceptar los términos y la política de privacidad");
  }
  if (d.versionTerminos !== VERSION_TERMINOS || d.versionPrivacidad !== VERSION_PRIVACIDAD) {
    falla("failed-precondition", "Hay una nueva versión de los términos. Vuelve a leerlos", {
      versionTerminos: VERSION_TERMINOS,
      versionPrivacidad: VERSION_PRIVACIDAD,
    });
  }
  const esCuidador = d.rol === "cuidador";
  if (esCuidador && d.aceptaDatosSensibles !== true) {
    falla("failed-precondition", "Para ser cuidador debes autorizar el uso de tu selfie y antecedentes");
  }

  await db.runTransaction(async (tx) => {
    const ref = refUsuario(uid);
    if ((await tx.get(ref)).exists) falla("already-exists", "Tu cuenta ya está registrada");
    tx.set(ref, {
      nombre,
      telefono,
      fechaNacimiento: d.fechaNacimiento,
      roles: { dueno: !esCuidador, cuidador: esCuidador },
      rolActivo: d.rol,
      plan: "gratis",
      premiumHasta: null,
      usoPruebaPremium: false,
      estadoCuenta: "activa",
      consentimientos: {
        terminos: consentimiento(true, VERSION_TERMINOS),
        privacidad: consentimiento(true, VERSION_PRIVACIDAD),
        publicidad: consentimiento(d.aceptaPublicidad === true),
        datosSensibles: consentimiento(esCuidador && d.aceptaDatosSensibles === true),
      },
      creadoEn: FieldValue.serverTimestamp(),
    });
    tx.set(refPerfil(uid), {
      nombre,
      fotoUrl: null,
      edad: edadEnAnios(d.fechaNacimiento!),
      esCuidador,
      verificado: false,
      disponible: false,
      nivel: "nuevo",
      calificacionPromedio: 0,
      sumaEstrellas: 0,
      numResenas: 0,
      serviciosCompletados: 0,
      etiquetas: {},
      experiencia: "",
      certificaciones: [],
      educacion: [],
      ultimoIncidenteEn: null,
      creadoEn: FieldValue.serverTimestamp(),
    });
    if (esCuidador) inicializarCuidador(tx, uid);
  });
  return { ok: true };
});

/** HU-02: "Puedo cambiar a ser cuidador más tarde desde Cuenta". */
export const activarRolCuidador = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const d = datos<{ aceptaDatosSensibles: boolean }>(req);
  if (d.aceptaDatosSensibles !== true) {
    falla("failed-precondition", "Para ser cuidador debes autorizar el uso de tu selfie y antecedentes");
  }
  await db.runTransaction(async (tx) => {
    const u = await usuarioActivo(uid, tx);
    if (u.roles?.cuidador) return;
    tx.update(refUsuario(uid), {
      "roles.cuidador": true,
      rolActivo: "cuidador",
      "consentimientos.datosSensibles": consentimiento(true),
    });
    tx.update(refPerfil(uid), { esCuidador: true });
    inicializarCuidador(tx, uid);
  });
  return { ok: true };
});

/** Cambia la vista entre dueño y cuidador (si tiene ambos roles). */
export const cambiarRolActivo = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const { rol } = datos<{ rol: Rol }>(req);
  const u = await usuarioActivo(uid);
  if (rol === "cuidador" && !u.roles?.cuidador) falla("failed-precondition", "Activa primero tu perfil de cuidador");
  if (rol !== "dueno" && rol !== "cuidador") falla("invalid-argument", "Rol inválido");
  await refUsuario(uid).update({ rolActivo: rol, [`roles.${rol}`]: true });
  return { ok: true };
});

/** HU-28: aceptar de nuevo cuando cambia la versión de términos o privacidad. */
export const aceptarNuevaVersion = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const d = datos<{ versionTerminos: string; versionPrivacidad: string }>(req);
  if (d.versionTerminos !== VERSION_TERMINOS || d.versionPrivacidad !== VERSION_PRIVACIDAD) {
    falla("failed-precondition", "La versión no es la vigente", {
      versionTerminos: VERSION_TERMINOS,
      versionPrivacidad: VERSION_PRIVACIDAD,
    });
  }
  await usuarioActivo(uid);
  await refUsuario(uid).update({
    "consentimientos.terminos": consentimiento(true, VERSION_TERMINOS),
    "consentimientos.privacidad": consentimiento(true, VERSION_PRIVACIDAD),
  });
  return { ok: true };
});

/** Versiones vigentes, para saber si la app debe pedir aceptar de nuevo. */
export const versionesLegales = onCall({ region: REGION }, async () => ({
  versionTerminos: VERSION_TERMINOS,
  versionPrivacidad: VERSION_PRIVACIDAD,
}));

/**
 * HU-31: retirar o dar consentimientos opcionales.
 * Retirar "datosSensibles" desactiva el rol de cuidador (no puede trabajar
 * sin verificación).
 */
export const actualizarConsentimiento = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const d = datos<{ tipo: "publicidad" | "datosSensibles"; aceptado: boolean }>(req);
  if (d.tipo !== "publicidad" && d.tipo !== "datosSensibles") falla("invalid-argument", "Consentimiento inválido");
  if (typeof d.aceptado !== "boolean") falla("invalid-argument", "Indica si aceptas o no");
  await usuarioActivo(uid);
  const cambios: Record<string, unknown> = { [`consentimientos.${d.tipo}`]: consentimiento(d.aceptado) };
  if (d.tipo === "datosSensibles" && !d.aceptado) {
    cambios["roles.cuidador"] = false;
    cambios.rolActivo = "dueno";
    cambios["roles.dueno"] = true;
    await refPerfil(uid).update({ disponible: false, verificado: false, esCuidador: false });
    await db.collection(COL.verificaciones).doc(uid).set(
      { estado: "revocada", revocadaEn: FieldValue.serverTimestamp() },
      { merge: true },
    );
  }
  await refUsuario(uid).update(cambios);
  return { ok: true };
});

/**
 * HU-31 (rectificación) y perfil del cuidador (captura "Calificación -
 * Cuidador": experiencia, certificaciones, educación).
 * El DNI y el teléfono NO se exponen en el perfil público (HU-05).
 */
export const actualizarPerfil = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const d = datos<{
    nombre: string;
    fotoUrl: string | null;
    experiencia: string;
    certificaciones: string[];
    educacion: string[];
  }>(req);
  await usuarioActivo(uid);
  const perfil: Record<string, unknown> = {};
  const privado: Record<string, unknown> = {};
  if (d.nombre !== undefined) {
    const n = textoRequerido(d.nombre, 80);
    if (!n) falla("invalid-argument", "Nombre inválido");
    perfil.nombre = privado.nombre = n;
  }
  if (d.fotoUrl !== undefined) {
    if (d.fotoUrl !== null && typeof d.fotoUrl !== "string") falla("invalid-argument", "Foto inválida");
    perfil.fotoUrl = d.fotoUrl;
  }
  if (d.experiencia !== undefined) {
    if (typeof d.experiencia !== "string" || d.experiencia.length > 1000) {
      falla("invalid-argument", "La experiencia admite hasta 1000 caracteres");
    }
    perfil.experiencia = d.experiencia.trim();
  }
  for (const campo of ["certificaciones", "educacion"] as const) {
    const lista = d[campo];
    if (lista === undefined) continue;
    if (!Array.isArray(lista) || lista.length > 10 || lista.some((x) => typeof x !== "string" || x.length > 150)) {
      falla("invalid-argument", `${campo}: hasta 10 líneas de 150 caracteres`);
    }
    perfil[campo] = lista.map((x) => x.trim()).filter(Boolean);
  }
  const batch = db.batch();
  if (Object.keys(perfil).length) batch.update(refPerfil(uid), perfil);
  if (Object.keys(privado).length) batch.update(refUsuario(uid), privado);
  await batch.commit();
  return { ok: true };
});

/** HU-12: activar o desactivar "Disponible" (solo cuidadores verificados). */
export const cambiarDisponibilidad = onCall({ region: REGION }, async (req) => {
  const uid = requiereUsuario(req);
  const { disponible } = datos<{ disponible: boolean }>(req);
  if (typeof disponible !== "boolean") falla("invalid-argument", "Indica si estás disponible");
  const perfil = await refPerfil(uid).get();
  if (!perfil.get("esCuidador")) falla("failed-precondition", "Solo para cuidadores");
  if (disponible && !perfil.get("verificado")) {
    falla("failed-precondition", "Tu verificación aún no está aprobada");
  }
  await refPerfil(uid).update({ disponible });
  return { ok: true };
});
