/**
 * Da (o quita) el rol de administrador a un usuario por su celular.
 *
 *   # Emulador
 *   FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 node scripts/asignar-admin.js +51999999999
 *   # Producción (con credenciales de servicio en GOOGLE_APPLICATION_CREDENTIALS)
 *   node scripts/asignar-admin.js +51999999999 [--quitar]
 */
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");

async function main() {
  const [telefono, flag] = process.argv.slice(2);
  if (!telefono) throw new Error("Uso: node scripts/asignar-admin.js +519XXXXXXXX [--quitar]");
  initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-mican" });
  const usuario = await getAuth().getUserByPhoneNumber(telefono);
  const admin = flag !== "--quitar";
  await getAuth().setCustomUserClaims(usuario.uid, { ...(usuario.customClaims || {}), admin });
  console.log(`${telefono} (${usuario.uid}) admin=${admin}. Debe cerrar sesión y volver a entrar.`);
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
