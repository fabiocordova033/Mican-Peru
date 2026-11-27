import { Navigate, Route, Routes } from "react-router-dom";
import { Cargando } from "./componentes/Base";
import { Marco } from "./componentes/Marco";
import { useSesion } from "./datos/sesion";
import { Comisiones } from "./paginas/Comisiones";
import { Entrar, SinPermiso } from "./paginas/Entrar";
import { Reclamos } from "./paginas/Reclamos";
import { RevisarCuidador } from "./paginas/RevisarCuidador";
import { Verificaciones } from "./paginas/Verificaciones";

export function App() {
  const { estado } = useSesion();
  if (estado.tipo === "cargando") return <Cargando />;
  if (estado.tipo === "fuera") return <Entrar />;
  if (estado.tipo === "sin_permiso") return <SinPermiso />;
  return (
    <Marco>
      <Rutas />
    </Marco>
  );
}

export function Rutas() {
  return (
    <Routes>
      <Route path="/verificaciones" element={<Verificaciones />} />
      <Route path="/verificaciones/:uid" element={<RevisarCuidador />} />
      <Route path="/comisiones" element={<Comisiones />} />
      <Route path="/reclamos" element={<Reclamos />} />
      <Route path="*" element={<Navigate to="/verificaciones" replace />} />
    </Routes>
  );
}
