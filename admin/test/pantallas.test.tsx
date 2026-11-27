import { render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { Rutas } from "../src/App";
import { ContextoApi, type ApiPanel } from "../src/datos/api";
import type { Verificacion } from "../src/dominio/tipos";
import { cuidador, horasAntes, verificacion } from "./fabricas";

// Las pantallas importan Marco → sesión → firebase; aquí no se usa Firebase real.
vi.mock("../src/datos/firebase", () => ({ USAR_EMULADORES: true, auth: {}, db: {}, funciones: {}, storage: {} }));

function apiFalsa(cola: Verificacion[]): ApiPanel & { revisarCuidador: ReturnType<typeof vi.fn> } {
  const cuidadores = new Map([
    ["cq", cuidador()],
    ["lr", cuidador({ uid: "lr", nombre: "Lucía Ramos", distrito: "Surco", dni: "40112233" })],
  ]);
  return {
    observarVerificaciones: (estado, cb) => {
      cb(cola.filter((v) => v.estado === estado));
      return () => {};
    },
    contarRevisadas: async (estado) => (estado === "aprobada" ? 126 : 9),
    cuidadores: async (uids) => new Map(uids.map((u) => [u, cuidadores.get(u)!])),
    observarVerificacion: (uid, cb) => {
      cb(cola.find((v) => v.uid === uid) ?? null);
      return () => {};
    },
    enlacesDocumentos: async () => ({ dniFrente: "blob:dni", selfie: "blob:selfie" }),
    revisarCuidador: vi.fn(async () => {}),
    reclamos: async () => [],
    finanzas: async () => ({ servicios: [], recargas: [], truncado: false }),
  };
}

function montar(api: ApiPanel, ruta: string) {
  return render(
    <ContextoApi.Provider value={api}>
      <MemoryRouter initialEntries={[ruta]}>
        <Rutas />
      </MemoryRouter>
    </ContextoApi.Provider>,
  );
}

const COLA = [
  verificacion({ uid: "lr", enviadoEn: horasAntes(21) }),
  verificacion({ uid: "cq", enviadoEn: horasAntes(44) }),
];

beforeEach(() => {
  vi.useFakeTimers({ shouldAdvanceTime: true, now: new Date("2026-11-27T14:12:00Z") });
});
afterEach(() => vi.useRealTimers());

describe("Verificaciones pendientes", () => {
  it("muestra indicadores y la cola ordenada por antigüedad", async () => {
    montar(apiFalsa(COLA), "/verificaciones");
    expect(await screen.findByText("Carlos Quispe García")).toBeInTheDocument();
    expect(screen.getByText("126")).toBeInTheDocument();
    expect(screen.getByText("Vencen hoy (más de 40 h)").previousSibling).toHaveTextContent("1");

    const filas = screen.getAllByRole("row").slice(1);
    expect(within(filas[0]!).getByText("Carlos Quispe García")).toBeInTheDocument();
    expect(within(filas[0]!).getByText("Vence pronto")).toBeInTheDocument();
    expect(within(filas[0]!).getByText("quedan 4 h")).toBeInTheDocument();
    expect(within(filas[1]!).getByText("Pendiente")).toBeInTheDocument();
  });

  it("filtra por DNI", async () => {
    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });
    montar(apiFalsa(COLA), "/verificaciones");
    await screen.findByText("Lucía Ramos");
    await user.type(screen.getByRole("searchbox"), "4011");
    expect(screen.queryByText("Carlos Quispe García")).not.toBeInTheDocument();
    expect(screen.getByText("Lucía Ramos")).toBeInTheDocument();
  });
});

describe("Revisar cuidador", () => {
  it("aprueba solo con el checklist completo", async () => {
    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });
    const api = apiFalsa(COLA);
    montar(api, "/verificaciones/cq");
    expect(await screen.findByRole("heading", { name: "Carlos Quispe García" })).toBeInTheDocument();
    expect(screen.getByText(/DNI 7951\*\*\*\* · 24 años · Miraflores · enviado hace 44 h/)).toBeInTheDocument();

    const aprobar = screen.getByRole("button", { name: "Aprobar y notificar" });
    expect(aprobar).toBeDisabled();
    for (const c of screen.getAllByRole("checkbox")) await user.click(c);
    expect(aprobar).toBeEnabled();
    await user.click(aprobar);

    expect(api.revisarCuidador).toHaveBeenCalledWith({ uid: "cq", aprobar: true });
    expect(await screen.findByText("Carlos Quispe García quedó verificado.")).toBeInTheDocument();
  });

  it("rechaza con motivo y pide rehacer lo que no se marcó", async () => {
    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });
    const api = apiFalsa(COLA);
    montar(api, "/verificaciones/cq");
    await screen.findByRole("heading", { name: "Carlos Quispe García" });

    await user.click(screen.getByRole("button", { name: "Rechazar" }));
    expect(screen.getByRole("alert")).toHaveTextContent("Escribe el motivo del rechazo");
    expect(api.revisarCuidador).not.toHaveBeenCalled();

    await user.click(screen.getByLabelText("La foto del DNI coincide con la selfie"));
    await user.click(screen.getByLabelText("El DNI es legible y está vigente"));
    await user.click(screen.getByLabelText("El certificado de antecedentes no registra delitos"));
    await user.type(screen.getByLabelText(/Motivo de rechazo/), "El certificado está vencido");
    await user.click(screen.getByRole("button", { name: "Rechazar" }));

    await waitFor(() =>
      expect(api.revisarCuidador).toHaveBeenCalledWith({
        uid: "cq",
        aprobar: false,
        motivo: "El certificado está vencido",
        documentosARehacer: ["antecedentes"],
      }),
    );
  });

  it("muestra el error del backend", async () => {
    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });
    const api = apiFalsa(COLA);
    api.revisarCuidador.mockRejectedValueOnce({ code: "functions/failed-precondition", message: "No está en revisión" });
    montar(api, "/verificaciones/cq");
    await screen.findByRole("heading", { name: "Carlos Quispe García" });
    for (const c of screen.getAllByRole("checkbox")) await user.click(c);
    await user.click(screen.getByRole("button", { name: "Aprobar y notificar" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("No está en revisión");
  });

  it("no permite decidir si ya no está en revisión", async () => {
    montar(apiFalsa([verificacion({ uid: "cq", estado: "aprobada", revisadoEn: horasAntes(1) })]), "/verificaciones/cq");
    expect(await screen.findByText(/Verificación aprobada el/)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Rechazar" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Aprobar y notificar" })).toBeDisabled();
  });
});
