/** Recargas y comisiones del mes: lo que Mican cobra (12 %) por servicio completado. */
import { useEffect, useMemo, useState } from "react";
import { Aviso, Cargando, Indicador } from "../componentes/Base";
import { mensajeError, useApi } from "../datos/api";
import { fechaCorta, inicioDeMes, inicioMesSiguiente, nombreMes, soles } from "../dominio/formato";
import { resumirFinanzas } from "../dominio/finanzas";
import type { Recarga, ServicioCompletado } from "../dominio/tipos";

const TIPO = { paseo: "Paseo", visita: "Visita", transporte: "Transporte" } as const;

/** Los últimos 6 meses, empezando por el actual. */
function meses(hoy: Date): Date[] {
  const res: Date[] = [];
  let d = inicioDeMes(hoy);
  for (let i = 0; i < 6; i++) {
    res.push(d);
    d = inicioDeMes(new Date(d.getTime() - 86_400_000));
  }
  return res;
}

export function Comisiones() {
  const api = useApi();
  const opciones = useMemo(() => meses(new Date()), []);
  const [mes, setMes] = useState(0);
  const [datos, setDatos] = useState<{ servicios: ServicioCompletado[]; recargas: Recarga[]; truncado: boolean } | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const desde = opciones[mes]!;
    setDatos(null);
    setError(null);
    api
      .finanzas(desde, inicioMesSiguiente(desde))
      .then(setDatos)
      .catch((e) => setError(mensajeError(e)));
  }, [api, mes, opciones]);

  const r = datos ? resumirFinanzas(datos.servicios, datos.recargas) : null;

  return (
    <>
      <header className="encabezado">
        <div>
          <h1>Recargas y comisiones</h1>
          <p className="subtitulo">Comisión del 12 % por servicio completado, descontada del saldo del cuidador</p>
        </div>
        <label className="buscar selector">
          <span className="solo-lectores">Mes</span>
          <select value={mes} onChange={(e) => setMes(Number(e.target.value))}>
            {opciones.map((d, i) => (
              <option key={d.toISOString()} value={i}>
                {nombreMes(d)}
              </option>
            ))}
          </select>
        </label>
      </header>
      {error && <Aviso>{error}</Aviso>}
      {datos?.truncado && <Aviso tono="info">Hay más de 1 000 registros este mes; los totales son parciales.</Aviso>}
      <section className="indicadores">
        <Indicador tono="primario" valor={r ? soles(r.comision) : "–"} etiqueta="Comisión Mican" />
        <Indicador tono="exito" valor={r ? soles(r.movido) : "–"} etiqueta={`Movido en ${r?.servicios ?? 0} servicios`} />
        <Indicador tono="gris" valor={r ? soles(r.montoRecargado) : "–"} etiqueta={`Recargado (${r?.recargas ?? 0} recargas)`} />
        <Indicador tono="gris" valor={r ? soles(r.ticketPromedio) : "–"} etiqueta="Precio promedio por servicio" />
      </section>

      {r && (
        <p className="nota">
          Por tipo:{" "}
          {(Object.keys(TIPO) as (keyof typeof TIPO)[])
            .map((t) => `${TIPO[t]} ${r.porTipo[t].servicios} (${soles(r.porTipo[t].comision)})`)
            .join(" · ")}
        </p>
      )}

      <section className="tarjeta tabla-contenedor">
        <table className="tabla">
          <thead>
            <tr>
              <th>Finalizado</th>
              <th>Servicio</th>
              <th>Cuidador</th>
              <th>Dueño</th>
              <th>Pago</th>
              <th className="num">Precio</th>
              <th className="num">Comisión</th>
            </tr>
          </thead>
          <tbody>
            {(datos?.servicios ?? []).map((s) => (
              <tr key={s.id}>
                <td>{fechaCorta(s.finalizadoEn)}</td>
                <td>
                  {TIPO[s.tipo] ?? s.tipo} · {s.mascotaNombre}
                </td>
                <td>{s.cuidadorNombre}</td>
                <td>{s.duenoNombre}</td>
                <td className="capital">{s.metodoPago}</td>
                <td className="num">{soles(s.precioFinal)}</td>
                <td className="num">
                  {soles(s.comision)} <span className="detalle-tiempo">{Math.round(s.comisionTasa * 100)} %</span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {!datos && !error && <Cargando />}
        {datos && !datos.servicios.length && <p className="vacio">No hubo servicios completados en {nombreMes(opciones[mes]!).toLowerCase()}.</p>}
      </section>
    </>
  );
}
