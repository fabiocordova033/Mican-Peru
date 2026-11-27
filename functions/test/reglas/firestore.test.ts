/**
 * Pruebas de las reglas de Firestore. Requieren el emulador:
 *   npm run test:reglas
 */
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import {
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import { Timestamp, doc, getDoc, serverTimestamp, setDoc, updateDoc } from "firebase/firestore";

let env: RulesTestEnvironment;
const ahora = () => Timestamp.now();
const haceDias = (d: number) => Timestamp.fromMillis(Date.now() - d * 86_400_000);
const enHoras = (h: number) => Timestamp.fromMillis(Date.now() + h * 3_600_000);

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-mican",
    firestore: { rules: readFileSync(resolve(__dirname, "../../../firestore.rules"), "utf8") },
  });
});
afterAll(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "usuarios/dueno"), { nombre: "Ana", telefono: "+51911111111", premiumHasta: null });
    await setDoc(doc(db, "usuarios/cuidador"), { nombre: "Carlos", telefono: "+51931945511", dni: "79512536" });
    await setDoc(doc(db, "perfilesPublicos/cuidador"), { nombre: "Carlos", verificado: true });
    await setDoc(doc(db, "perfilesPublicos/otro"), { nombre: "Luis", verificado: false });
    await setDoc(doc(db, "billeteras/cuidador"), { saldo: 5000 });
    await setDoc(doc(db, "servicios/s1"), {
      duenoId: "dueno",
      cuidadorId: "cuidador",
      participantes: ["dueno", "cuidador"],
      estado: "en_curso",
      creadoEn: ahora(),
    });
    await setDoc(doc(db, "servicios/s1/privado/contacto"), {
      participantes: ["dueno", "cuidador"],
      telefonoCuidador: "+51931945511",
      visibleHasta: null,
    });
    await setDoc(doc(db, "servicios/viejo"), {
      duenoId: "dueno",
      cuidadorId: "cuidador",
      participantes: ["dueno", "cuidador"],
      estado: "completado",
      creadoEn: haceDias(45),
    });
    await setDoc(doc(db, "servicios/abierta"), {
      duenoId: "dueno",
      cuidadorId: null,
      participantes: ["dueno"],
      estado: "buscando",
      creadoEn: ahora(),
    });
    await setDoc(doc(db, "chats/s1"), {
      participantes: ["dueno", "cuidador"],
      abierto: true,
      cierraEn: null,
      noLeidos: { dueno: 3, cuidador: 0 },
    });
    await setDoc(doc(db, "servicios/s1/calificaciones/dueno"), { visible: false, estrellas: 5 });
  });
});

const como = (uid: string) => env.authenticatedContext(uid).firestore();

describe("datos privados (HU-05)", () => {
  it("nadie más lee el documento privado del usuario (DNI, teléfono)", async () => {
    await assertSucceeds(getDoc(doc(como("cuidador"), "usuarios/cuidador")));
    await assertFails(getDoc(doc(como("dueno"), "usuarios/cuidador")));
  });
  it("el perfil público lo lee cualquier usuario autenticado", async () => {
    await assertSucceeds(getDoc(doc(como("dueno"), "perfilesPublicos/cuidador")));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), "perfilesPublicos/cuidador")));
  });
  it("el teléfono se ve durante el servicio", async () => {
    await assertSucceeds(getDoc(doc(como("dueno"), "servicios/s1/privado/contacto")));
    await assertFails(getDoc(doc(como("otro"), "servicios/s1/privado/contacto")));
  });
});

describe("billetera", () => {
  it("la app no puede cambiar el saldo", async () => {
    await assertSucceeds(getDoc(doc(como("cuidador"), "billeteras/cuidador")));
    await assertFails(updateDoc(doc(como("cuidador"), "billeteras/cuidador"), { saldo: 999999 }));
    await assertFails(getDoc(doc(como("dueno"), "billeteras/cuidador")));
  });
});

describe("servicios", () => {
  it("solo cuidadores verificados ven solicitudes buscando (HU-12)", async () => {
    await assertSucceeds(getDoc(doc(como("cuidador"), "servicios/abierta")));
    await assertFails(getDoc(doc(como("otro"), "servicios/abierta")));
  });
  it("sin Premium el dueño ve solo los últimos 30 días (HU-20)", async () => {
    await assertSucceeds(getDoc(doc(como("dueno"), "servicios/s1")));
    await assertFails(getDoc(doc(como("dueno"), "servicios/viejo")));
    await env.withSecurityRulesDisabled((ctx) =>
      updateDoc(doc(ctx.firestore(), "usuarios/dueno"), { premiumHasta: enHoras(24) }),
    );
    await assertSucceeds(getDoc(doc(como("dueno"), "servicios/viejo")));
  });
  it("la app no cambia el estado del servicio", async () => {
    await assertFails(updateDoc(doc(como("cuidador"), "servicios/s1"), { estado: "completado" }));
  });
  it("solo el cuidador asignado escribe la ruta en vivo (HU-16)", async () => {
    const punto = { lat: -12.12, lng: -77.03, registradoEn: serverTimestamp() };
    await assertSucceeds(setDoc(doc(como("cuidador"), "servicios/s1/ruta/p1"), punto));
    await assertFails(setDoc(doc(como("dueno"), "servicios/s1/ruta/p2"), punto));
    await assertFails(setDoc(doc(como("cuidador"), "servicios/s1/ruta/p3"), { ...punto, lat: 200 }));
  });
  it("la calificación queda oculta hasta revelarse (HU-24)", async () => {
    await assertSucceeds(getDoc(doc(como("dueno"), "servicios/s1/calificaciones/dueno")));
    await assertFails(getDoc(doc(como("cuidador"), "servicios/s1/calificaciones/dueno")));
  });
});

describe("chat (HU-19)", () => {
  const mensaje = (autorId: string) => ({ autorId, tipo: "texto", texto: "Hola", creadoEn: serverTimestamp() });
  it("los participantes escriben si el chat está abierto", async () => {
    await assertSucceeds(setDoc(doc(como("dueno"), "chats/s1/mensajes/m1"), mensaje("dueno")));
    await assertFails(setDoc(doc(como("otro"), "chats/s1/mensajes/m2"), mensaje("otro")));
    await assertFails(setDoc(doc(como("dueno"), "chats/s1/mensajes/m3"), mensaje("cuidador")));
  });
  it("no se escribe en un chat cerrado", async () => {
    await env.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), "chats/s1"), { abierto: false }));
    await assertFails(setDoc(doc(como("dueno"), "chats/s1/mensajes/m4"), mensaje("dueno")));
  });
  it("cada uno solo pone en 0 su propio contador de no leídos", async () => {
    await assertSucceeds(updateDoc(doc(como("dueno"), "chats/s1"), { "noLeidos.dueno": 0 }));
    await assertFails(updateDoc(doc(como("dueno"), "chats/s1"), { "noLeidos.cuidador": 7 }));
    await assertFails(updateDoc(doc(como("dueno"), "chats/s1"), { abierto: false }));
  });
});
