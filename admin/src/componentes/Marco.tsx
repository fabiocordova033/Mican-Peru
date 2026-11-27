/** Menú lateral + área principal (frames "Menú lateral" y "Principal" de Figma). */
import type { ReactNode } from "react";
import { NavLink } from "react-router-dom";
import { useSesion } from "../datos/sesion";
import { IconoActividad, IconoBilletera, IconoCampana, IconoCuenta, IconoEscudo, IconoSalir } from "./Iconos";
import { Logo } from "./Logo";

const MENU = [
  { a: "/verificaciones", texto: "Verificaciones", Icono: IconoEscudo },
  { a: null, texto: "Usuarios", Icono: IconoCuenta },
  { a: null, texto: "Servicios", Icono: IconoActividad },
  { a: "/comisiones", texto: "Recargas y comisiones", Icono: IconoBilletera },
  { a: "/reclamos", texto: "Reportes y emergencias", Icono: IconoCampana },
] as const;

export function Marco({ children }: { children: ReactNode }) {
  const { estado, salir } = useSesion();
  const correo = estado.tipo === "admin" ? estado.usuario.email ?? estado.usuario.phoneNumber : null;
  return (
    <div className="marco">
      <aside className="menu">
        <Logo />
        <nav aria-label="Secciones">
          {MENU.map(({ a, texto, Icono }) =>
            a ? (
              <NavLink key={texto} to={a} className={({ isActive }) => `menu-item${isActive ? " activo" : ""}`}>
                <Icono />
                <span>{texto}</span>
              </NavLink>
            ) : (
              <span key={texto} className="menu-item deshabilitado" title="Próximamente" aria-disabled="true">
                <Icono />
                <span>{texto}</span>
              </span>
            ),
          )}
        </nav>
        <div className="menu-pie">
          {correo && <span className="menu-correo">{correo}</span>}
          <button className="menu-item boton-plano" onClick={() => void salir()}>
            <IconoSalir />
            <span>Cerrar sesión</span>
          </button>
        </div>
      </aside>
      <main className="principal">{children}</main>
    </div>
  );
}
