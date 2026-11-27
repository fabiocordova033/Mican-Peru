/**
 * Sesión del panel. Solo entra quien tiene el custom claim `admin: true`
 * (se asigna con functions/scripts/asignar-admin.js).
 */
import { onIdTokenChanged, signInWithEmailAndPassword, signOut, type User } from "firebase/auth";
import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import { auth } from "./firebase";

export type EstadoSesion =
  | { tipo: "cargando" }
  | { tipo: "fuera" }
  | { tipo: "sin_permiso"; usuario: User }
  | { tipo: "admin"; usuario: User };

export interface Sesion {
  estado: EstadoSesion;
  entrar(correo: string, clave: string): Promise<void>;
  salir(): Promise<void>;
  /** Vuelve a leer los claims (después de correr asignar-admin.js). */
  refrescar(): Promise<void>;
}

const ContextoSesion = createContext<Sesion | null>(null);

export function useSesion(): Sesion {
  const s = useContext(ContextoSesion);
  if (!s) throw new Error("Falta <ProveedorSesion>");
  return s;
}

export { ContextoSesion };

async function evaluar(u: User | null, forzar = false): Promise<EstadoSesion> {
  if (!u) return { tipo: "fuera" };
  const t = await u.getIdTokenResult(forzar);
  return t.claims.admin === true ? { tipo: "admin", usuario: u } : { tipo: "sin_permiso", usuario: u };
}

export function ProveedorSesion({ children }: { children: ReactNode }) {
  const [estado, setEstado] = useState<EstadoSesion>({ tipo: "cargando" });

  useEffect(() => onIdTokenChanged(auth, async (u) => setEstado(await evaluar(u))), []);

  const valor: Sesion = {
    estado,
    async entrar(correo, clave) {
      await signInWithEmailAndPassword(auth, correo.trim(), clave);
    },
    async salir() {
      await signOut(auth);
    },
    async refrescar() {
      setEstado(await evaluar(auth.currentUser, true));
    },
  };
  return <ContextoSesion.Provider value={valor}>{children}</ContextoSesion.Provider>;
}

export function mensajeErrorLogin(e: unknown): string {
  const code = (e as { code?: string })?.code ?? "";
  if (code === "auth/invalid-credential" || code === "auth/wrong-password" || code === "auth/user-not-found")
    return "Correo o contraseña incorrectos.";
  if (code === "auth/too-many-requests") return "Demasiados intentos. Espera unos minutos.";
  if (code === "auth/invalid-email") return "Escribe un correo válido.";
  if (code === "auth/network-request-failed") return "Sin conexión con Firebase.";
  return "No se pudo iniciar sesión.";
}
