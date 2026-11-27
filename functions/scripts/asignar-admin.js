/**
 * Da (o quita) el rol de administrador a un usuario por su celular o su correo.
 * El panel web (admin/) entra con correo y contraseña.
 *
 *   # Emulador
 *   FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 node scripts/asignar-admin.js +51999999999
 *   FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 node scripts/asignar-admin.js equipo@mican.pe
 *   # Producción (con credenciales de servicio en GOOGLE_APPLICATION_CREDENTIALS)
 *   node scripts/asignar-admin.js equipo@mican.pe [--quitar]
 */
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");

async function main() {
  const [cuenta, flag] = process.argv.slice(2);
  if (!cuenta) throw new Error("Uso: node scripts/asignar-admin.js <+519XXXXXXXX | correo> [--quitar]");
  initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-mican" });
  const usuario = cuenta.includes("@")
    ? await getAuth().getUserByEmail(cuenta)
    : await getAuth().getUserByPhoneNumber(cuenta);
  const admin = flag !== "--quitar";
  await getAuth().setCustomUserClaims(usuario.uid, { ...(usuario.customClaims || {}), admin });
  console.log(`${cuenta} (${usuario.uid}) admin=${admin}. Debe cerrar sesión y volver a entrar.`);
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
