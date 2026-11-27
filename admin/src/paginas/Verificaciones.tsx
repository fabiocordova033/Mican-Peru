/** Figma "04 · Panel admin (web)" → A · Verificaciones pendientes. */
import { useEffect, useMemo, useState } from "react";
import { Link, useLocation } from "react-router-dom";
import { Aviso, Avatar, Cargando, Chip, Indicador, type TonoChip } from "../componentes/Base";
import { IconoBuscar, IconoChevron } from "../componentes/Iconos";
import { useAhora } from "../componentes/usarAhora";
import { mensajeError, useApi } from "../datos/api";
import { fechaCorta, inicioDeMes } from "../dominio/formato";
import { DOCUMENTOS, type Cuidador, type EstadoVerificacion, type Verificacion } from "../dominio/tipos";
import {
  ETIQUETA_ESTADO,
  type EstadoFila,
  type Fila,
  estadoFila,
  estaEntregado,
  filtrarFilas,
  indicadoresDeLista,
  resumenDocumentos,
  textoTiempo,
} from "../dominio/verificacion";

export const TONO_ESTADO: Record<EstadoFila, TonoChip> = {
  pendiente: "primario",
  vence_pronto: "error",
  vencido: "error",
  incompleto: "gris",
  rechazado: "error",
  aprobado: "exito",
};

const PESTANAS: { estado: EstadoVerificacion; texto: string }[] = [
  { estado: "en_revision", texto: "Por revisar" },
  { estado: "incompleta", texto: "Incompletos" },
  { estado: "rechazada", texto: "Rechazados" },
];

function ordenar(estado: EstadoVerificacion, lista: Verificacion[]): Verificacion[] {
  const t = (d: Date | null) => d?.getTime() ?? 0;
  const copia = [...lista];
  // En revisión: primero los que llevan más tiempo esperando (vencen antes).
  if (estado === "en_revision") return copia.sort((a, b) => t(a.enviadoEn) - t(b.enviadoEn));
  if (estado === "rechazada") return copia.sort((a, b) => t(b.revisadoEn) - t(a.revisadoEn));
  // Incompletos: solo quienes ya empezaron a subir documentos.
  return copia
    .filter((v) => DOCUMENTOS.some((d) => estaEntregado(v, d)))
    .sort((a, b) => t(b.actualizadoEn) - t(a.actualizadoEn));
}

export function Verificaciones() {
  const api = useApi();
  const ahora = useAhora();
  const [pestana, setPestana] = useState<EstadoVerificacion>("en_revision");
  const [enRevision, setEnRevision] = useState<Verificacion[] | null>(null);
  const [otra, setOtra] = useState<Verificacion[] | null>(null);
  const [cuidadores, setCuidadores] = useState<Map<string, Cuidador>>(new Map());
  const [conteos, setConteos] = useState<{ aprobados: number; rechazados: number } | null>(null);
  const [busqueda, setBusqueda] = useState("");
  const [error, setError] = useState<string | null>(null);
  const aviso = (useLocation().state as { aviso?: string } | null)?.aviso;

  // La cola en revisión siempre está en vivo: alimenta los indicadores.
  useEffect(
    () => api.observarVerificaciones("en_revision", setEnRevision, (e) => setError(mensajeError(e))),
    [api],
  );

  useEffect(() => {
    if (pestana === "en_revision") return;
    setOtra(null);
    return api.observarVerificaciones(pestana, (l) => setOtra(l), (e) => setError(mensajeError(e)));
  }, [api, pestana]);

  useEffect(() => {
    const desde = inicioDeMes(new Date());
    Promise.all([api.contarRevisadas("aprobada", desde), api.contarRevisadas("rechazada", desde)])
      .then(([aprobados, rechazados]) => setConteos({ aprobados, rechazados }))
      .catch((e) => setError(mensajeError(e)));
  }, [api]);

  const lista = pestana === "en_revision" ? enRevision : otra;
  const visibles = useMemo(() => (lista ? ordenar(pestana, lista) : null), [lista, pestana]);

  // Datos de los cuidadores que aún no se cargaron.
  useEffect(() => {
    if (!visibles) return;
    const faltan = visibles.map((v) => v.uid).filter((uid) => !cuidadores.has(uid));
    if (!faltan.length) return;
    api
      .cuidadores(faltan)
      .then((m) => setCuidadores((prev) => new Map([...prev, ...m])))
      .catch((e) => setError(mensajeError(e)));
  }, [api, visibles, cuidadores]);

  const filas: Fila[] = useMemo(
    () => filtrarFilas((visibles ?? []).map((v) => ({ verificacion: v, cuidador: cuidadores.get(v.uid) ?? null })), busqueda),
    [visibles, cuidadores, busqueda],
  );
  const ind = enRevision ? indicadoresDeLista(enRevision, ahora) : null;

  return (
    <>
      <header className="encabezado">
        <div>
          <h1>Verificación de cuidadores</h1>
          <p className="subtitulo">Revisa los documentos en menos de 48 h (HU-04)</p>
        </div>
        <label className="buscar">
          <IconoBuscar tam={18} />
          <input
            type="search"
            placeholder="Buscar por nombre o DNI"
            aria-label="Buscar por nombre o DNI"
            value={busqueda}
            onChange={(e) => setBusqueda(e.target.value)}
          />
        </label>
      </header>

      {aviso && <Aviso tono="info">{aviso}</Aviso>}
      {error && <Aviso>{error}</Aviso>}

      <section className="indicadores" aria-label="Indicadores">
        <Indicador tono="primario" valor={ind?.pendientes ?? "–"} etiqueta="Pendientes" />
        <Indicador tono="error" valor={ind?.vencenPronto ?? "–"} etiqueta="Vencen hoy (más de 40 h)" />
        <Indicador tono="exito" valor={conteos?.aprobados ?? "–"} etiqueta="Aprobados este mes" />
        <Indicador tono="gris" valor={conteos?.rechazados ?? "–"} etiqueta="Rechazados este mes" />
      </section>

      <div className="pestanas" role="tablist">
        {PESTANAS.map((p) => (
          <button
            key={p.estado}
            role="tab"
            aria-selected={pestana === p.estado}
            className={`pestana${pestana === p.estado ? " activa" : ""}`}
            onClick={() => setPestana(p.estado)}
          >
            {p.texto}
            {p.estado === "en_revision" && enRevision ? ` (${enRevision.length})` : ""}
          </button>
        ))}
      </div>

      <section className="tarjeta tabla-contenedor">
        <table className="tabla">
          <thead>
            <tr>
              <th>Cuidador</th>
              <th>Distrito</th>
              <th>Documentos</th>
              <th>{pestana === "rechazada" ? "Rechazado" : pestana === "incompleta" ? "Actualizado" : "Enviado"}</th>
              <th>Tiempo</th>
              <th>Estado</th>
              <th>
                <span className="solo-lectores">Acción</span>
              </th>
            </tr>
          </thead>
          <tbody>
            {filas.map(({ verificacion: v, cuidador: c }) => {
              const est = estadoFila(v, ahora);
              const tiempo = textoTiempo(v, ahora);
              const nombre = c?.nombre ?? "…";
              const fecha = pestana === "rechazada" ? v.revisadoEn : pestana === "incompleta" ? v.actualizadoEn : v.enviadoEn;
              return (
                <tr key={v.uid}>
                  <td>
                    <span className="celda-cuidador">
                      <Avatar nombre={nombre} foto={c?.fotoUrl} />
                      <strong>{nombre}</strong>
                    </span>
                  </td>
                  <td>{c?.distrito ?? "—"}</td>
                  <td>{resumenDocumentos(v)}</td>
                  <td>{fechaCorta(fecha)}</td>
                  <td>
                    {tiempo.principal}
                    {tiempo.detalle && <span className="detalle-tiempo">{tiempo.detalle}</span>}
                  </td>
                  <td>
                    <Chip tono={TONO_ESTADO[est]}>{ETIQUETA_ESTADO[est]}</Chip>
                  </td>
                  <td>
                    <Link className="ir" to={`/verificaciones/${v.uid}`} aria-label={`Revisar a ${nombre}`}>
                      Revisar <IconoChevron tam={16} />
                    </Link>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
        {!visibles && <Cargando />}
        {visibles && !filas.length && (
          <p className="vacio">
            {busqueda
              ? "Nadie coincide con la búsqueda."
              : pestana === "en_revision"
                ? "No hay cuidadores esperando revisión. 🎉"
                : "No hay cuidadores en esta lista."}
          </p>
        )}
      </section>
    </>
  );
}
