import { useState, type FormEvent } from "react";
import { Aviso } from "../componentes/Base";
import { Logo } from "../componentes/Logo";
import { USAR_EMULADORES } from "../datos/firebase";
import { mensajeErrorLogin, useSesion } from "../datos/sesion";

export function Entrar() {
  const { entrar } = useSesion();
  const [correo, setCorreo] = useState("");
  const [clave, setClave] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [enviando, setEnviando] = useState(false);

  async function enviar(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setEnviando(true);
    try {
      await entrar(correo, clave);
    } catch (err) {
      setError(mensajeErrorLogin(err));
    } finally {
      setEnviando(false);
    }
  }

  return (
    <div className="pantalla-centro">
      <form className="tarjeta login" onSubmit={enviar}>
        <Logo />
        <h1>Panel de administración</h1>
        <p className="subtitulo">Solo para el equipo de Mican.</p>
        <label className="campo">
          <span>Correo</span>
          <input type="email" autoComplete="username" required value={correo} onChange={(e) => setCorreo(e.target.value)} />
        </label>
        <label className="campo">
          <span>Contraseña</span>
          <input
            type="password"
            autoComplete="current-password"
            required
            value={clave}
            onChange={(e) => setClave(e.target.value)}
          />
        </label>
        {error && <Aviso>{error}</Aviso>}
        <button className="boton boton-primario" disabled={enviando}>
          {enviando ? "Entrando…" : "Entrar"}
        </button>
        {USAR_EMULADORES && (
          <p className="nota">
            Emuladores: corre <code>npm run sembrar</code> y entra con admin@mican.pe / mican123.
          </p>
        )}
      </form>
    </div>
  );
}

export function SinPermiso() {
  const { estado, salir, refrescar } = useSesion();
  const quien = estado.tipo === "sin_permiso" ? estado.usuario.email ?? estado.usuario.phoneNumber : "";
  return (
    <div className="pantalla-centro">
      <div className="tarjeta login">
        <Logo />
        <h1>Sin acceso</h1>
        <p>
          La cuenta <strong>{quien}</strong> no es administradora. Pide que te asignen el rol con{" "}
          <code>node scripts/asignar-admin.js {quien}</code> y vuelve a intentarlo.
        </p>
        <div className="acciones">
          <button className="boton boton-borde" onClick={() => void salir()}>
            Cerrar sesión
          </button>
          <button className="boton boton-primario" onClick={() => void refrescar()}>
            Ya me lo asignaron
          </button>
        </div>
      </div>
    </div>
  );
}
