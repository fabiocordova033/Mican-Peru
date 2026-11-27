import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import { App } from "./App";
import { ContextoApi } from "./datos/api";
import { apiFirebase } from "./datos/apiFirebase";
import { ProveedorSesion } from "./datos/sesion";
import "./estilos.css";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <ProveedorSesion>
      <ContextoApi.Provider value={apiFirebase}>
        <BrowserRouter>
          <App />
        </BrowserRouter>
      </ContextoApi.Provider>
    </ProveedorSesion>
  </StrictMode>,
);
