/**
 * Pruebas de las reglas de Storage. Requieren el emulador:
 *   npm run test:reglas
 */
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { RulesTestEnvironment, assertFails, assertSucceeds, initializeTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, setDoc } from "firebase/firestore";
import { getBytes, ref, uploadBytes } from "firebase/storage";

let env: RulesTestEnvironment;
const imagen = new Uint8Array([0xff, 0xd8, 0xff]);

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-mican",
    storage: { rules: readFileSync(resolve(__dirname, "../../../storage.rules"), "utf8") },
    firestore: { rules: "rules_version='2'; service cloud.firestore { match /{d=**} { allow read: if true; } }" },
  });
  await env.withSecurityRulesDisabled((ctx) =>
    setDoc(doc(ctx.firestore(), "servicios/s1"), {
      duenoId: "dueno",
      cuidadorId: "cuidador",
      participantes: ["dueno", "cuidador"],
      estado: "en_curso",
    }),
  );
});
afterAll(() => env.cleanup());

const como = (uid: string) => env.authenticatedContext(uid).storage();

describe("documentos de verificación (HU-03)", () => {
  it("el cuidador sube sus documentos pero no los puede leer nadie más que admin", async () => {
    await assertSucceeds(uploadBytes(ref(como("cuidador"), "verificaciones/cuidador/selfie.jpg"), imagen, { contentType: "image/jpeg" }));
    await assertFails(uploadBytes(ref(como("dueno"), "verificaciones/cuidador/selfie.jpg"), imagen, { contentType: "image/jpeg" }));
    await assertFails(uploadBytes(ref(como("cuidador"), "verificaciones/cuidador/otro.jpg"), imagen, { contentType: "image/jpeg" }));
    await assertFails(getBytes(ref(como("dueno"), "verificaciones/cuidador/selfie.jpg")));
    const admin = env.authenticatedContext("admin", { admin: true }).storage();
    await assertSucceeds(getBytes(ref(admin, "verificaciones/cuidador/selfie.jpg")));
  });
});

describe("fotos del servicio (HU-17)", () => {
  it("solo el cuidador asignado sube fotos y solo los participantes las ven", async () => {
    await assertSucceeds(uploadBytes(ref(como("cuidador"), "servicios/s1/fotos/a.jpg"), imagen, { contentType: "image/jpeg" }));
    await assertFails(uploadBytes(ref(como("dueno"), "servicios/s1/fotos/b.jpg"), imagen, { contentType: "image/jpeg" }));
    await assertSucceeds(getBytes(ref(como("dueno"), "servicios/s1/fotos/a.jpg")));
    await assertFails(getBytes(ref(como("intruso"), "servicios/s1/fotos/a.jpg")));
  });
});
