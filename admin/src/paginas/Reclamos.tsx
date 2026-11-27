/**
 * Libro de Reclamaciones (HU-30): reclamos y quejas con su plazo legal de
 * 15 días hábiles. Solo lectura: la respuesta se envía por correo al consumidor.
 */
import { Fragment, useEffect, useMemo, useState } from "react";
import { Aviso, Cargando, Chip, Indicador, type TonoChip } from "../componentes/Base";
import { useAhora } from "../componentes/usarAhora";
import { mensajeError, useApi } from "../datos/api";
import { fechaCorta, soles } from "../dominio/formato";
import { textoPlazo, urgenciaReclamo, type Urgencia } from "../dominio/reclamos";
import type { Reclamo } from "../dominio/tipos";

const TONO: Record<Urgencia, TonoChip> = { a_tiempo: "primario", por_vencer: "acento", vencido: "error", atendido: "exito" };

export function Reclamos() {
  const api = useApi();
  const ahora = useAhora();
  const [reclamos, setReclamos] = useState<Reclamo[] | null>(null);
  const [abierto, setAbierto] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api.reclamos().then(setReclamos).catch((e) => setError(mensajeError(e)));
  }, [api]);

  const conteo = useMemo(() => {
    const c = { abiertos: 0, porVencer: 0, vencidos: 0, quejas: 0 };
    for (const r of reclamos ?? []) {
      const u = urgenciaReclamo(r, ahora);
      if (u !== "atendido") c.abiertos++;
      if (u === "por_vencer") c.porVencer++;
      if (u === "vencido") c.vencidos++;
      if (r.tipo === "queja") c.quejas++;
    }
    return c;
  }, [reclamos, ahora]);

  return (
    <>
      <header className="encabezado">
        <div>
          <h1>Libro de Reclamaciones</h1>
          <p className="subtitulo">Responde por correo en un máximo de 15 días hábiles (HU-30, Ley 29571)</p>
        </div>
      </header>
      {error && <Aviso>{error}</Aviso>}
      <section className="indicadores">
        <Indicador tono="primario" valor={reclamos ? conteo.abiertos : "–"} etiqueta="Sin atender" />
        <Indicador tono="error" valor={reclamos ? conteo.porVencer : "–"} etiqueta="Vencen en 3 días o menos" />
        <Indicador tono="error" valor={reclamos ? conteo.vencidos : "–"} etiqueta="Fuera de plazo" />
        <Indicador tono="gris" valor={reclamos ? conteo.quejas : "–"} etiqueta="Quejas (del total)" />
      </section>
      <section className="tarjeta tabla-contenedor">
        <table className="tabla">
          <thead>
            <tr>
              <th>Número</th>
              <th>Tipo</th>
              <th>Consumidor</th>
              <th>Detalle</th>
              <th>Presentado</th>
              <th>Plazo</th>
            </tr>
          </thead>
          <tbody>
            {(reclamos ?? []).map((r) => (
              <Fragment key={r.id}>
                <tr
                  className="fila-clic"
                  tabIndex={0}
                  aria-expanded={abierto === r.id}
                  onClick={() => setAbierto(abierto === r.id ? null : r.id)}
                  onKeyDown={(e) => e.key === "Enter" && setAbierto(abierto === r.id ? null : r.id)}
                >
                  <td>
                    <strong>{r.numero}</strong>
                  </td>
                  <td>{r.tipo === "queja" ? "Queja" : "Reclamo"}</td>
                  <td>{r.consumidor.nombre}</td>
                  <td className="recorte">{r.detalle}</td>
                  <td>{fechaCorta(r.creadoEn)}</td>
                  <td>
                    <Chip tono={TONO[urgenciaReclamo(r, ahora)]}>{textoPlazo(r, ahora)}</Chip>
                  </td>
                </tr>
                {abierto === r.id && (
                  <tr className="fila-detalle">
                    <td colSpan={6}>
                      <dl>
                        <dt>Documento</dt>
                        <dd>{r.consumidor.documento}</dd>
                        <dt>Correo</dt>
                        <dd>
                          <a href={`mailto:${r.consumidor.correo}?subject=${encodeURIComponent(`Respuesta a su ${r.tipo} ${r.numero}`)}`}>
                            {r.consumidor.correo}
                          </a>
                        </dd>
                        {r.consumidor.domicilio && (
                          <>
                            <dt>Domicilio</dt>
                            <dd>{r.consumidor.domicilio}</dd>
                          </>
                        )}
                        {r.servicioId && (
                          <>
                            <dt>Servicio</dt>
                            <dd>{r.servicioId}</dd>
                          </>
                        )}
                        {r.montoReclamado != null && (
                          <>
                            <dt>Monto reclamado</dt>
                            <dd>{soles(r.montoReclamado)}</dd>
                          </>
                        )}
                        <dt>Detalle</dt>
                        <dd>{r.detalle}</dd>
                        <dt>Pedido</dt>
                        <dd>{r.pedido}</dd>
                        <dt>Vence</dt>
                        <dd>{fechaCorta(r.venceEn)}</dd>
                      </dl>
                    </td>
                  </tr>
                )}
              </Fragment>
            ))}
          </tbody>
        </table>
        {!reclamos && !error && <Cargando />}
        {reclamos && !reclamos.length && <p className="vacio">Todavía no hay reclamos ni quejas.</p>}
      </section>
    </>
  );
}
