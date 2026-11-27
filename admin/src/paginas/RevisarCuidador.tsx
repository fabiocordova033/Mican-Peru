/** Figma "04 · Panel admin (web)" → B · Revisar cuidador. */
import { useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { Aviso, Avatar, Cargando, Chip } from "../componentes/Base";
import { IconoAtras, IconoCamara, IconoCerrar, IconoDocumento, IconoVerificado } from "../componentes/Iconos";
import { useAhora } from "../componentes/usarAhora";
import { mensajeError, useApi } from "../datos/api";
import { enmascararDni, fechaCorta, hace } from "../dominio/formato";
import { DOCUMENTOS_OBLIGATORIOS, type Cuidador, type TipoDocumento, type Verificacion } from "../dominio/tipos";
import {
  CHECKLIST,
  ETIQUETA_ESTADO,
  NOMBRE_DOCUMENTO,
  checklistCompleto,
  documentoConforme,
  esPdf,
  estaEntregado,
  estadoFila,
  prepararDecision,
  textoTiempo,
  type Marcas,
} from "../dominio/verificacion";
import { TONO_ESTADO } from "./Verificaciones";

type Enlaces = Partial<Record<TipoDocumento, string>>;

export function RevisarCuidador() {
  const { uid = "" } = useParams();
  const api = useApi();
  const navegar = useNavigate();
  const ahora = useAhora();
  const [v, setV] = useState<Verificacion | null | undefined>(undefined);
  const [cuidador, setCuidador] = useState<Cuidador | null>(null);
  const [enlaces, setEnlaces] = useState<Enlaces | null>(null);
  const [marcas, setMarcas] = useState<Marcas>({});
  const [motivo, setMotivo] = useState("");
  const [enviando, setEnviando] = useState<"aprobar" | "rechazar" | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [grande, setGrande] = useState<TipoDocumento | null>(null);

  useEffect(() => api.observarVerificacion(uid, setV, (e) => setError(mensajeError(e))), [api, uid]);
  useEffect(() => {
    api
      .cuidadores([uid])
      .then((m) => setCuidador(m.get(uid) ?? null))
      .catch((e) => setError(mensajeError(e)));
  }, [api, uid]);

  // Los enlaces se piden una vez que se conocen los archivos.
  const claveArchivos = v ? JSON.stringify(v.archivos) : "";
  useEffect(() => {
    if (!v || !Object.keys(v.archivos).length) {
      setEnlaces({});
      return;
    }
    let vivo = true;
    api
      .enlacesDocumentos(v)
      .then((e) => vivo && setEnlaces(e))
      .catch((e) => vivo && setError(mensajeError(e)));
    return () => {
      vivo = false;
    };
  }, [api, claveArchivos]);

  if (v === undefined) return <Cargando />;
  if (v === null)
    return (
      <>
        <Volver />
        <Aviso>Este cuidador no tiene una verificación iniciada.</Aviso>
      </>
    );

  const est = estadoFila(v, ahora);
  const enRevision = v.estado === "en_revision";
  const nombre = cuidador?.nombre ?? "…";
  const tiempo = textoTiempo(v, ahora);

  async function decidir(aprobar: boolean) {
    setError(null);
    const d = prepararDecision(uid, aprobar, marcas, motivo);
    if (!d.ok) {
      setError(d.error);
      return;
    }
    setEnviando(aprobar ? "aprobar" : "rechazar");
    try {
      await api.revisarCuidador(d.datos);
      navegar("/verificaciones", {
        state: { aviso: aprobar ? `${nombre} quedó verificado.` : `Se pidió a ${nombre} corregir sus documentos.` },
      });
    } catch (e) {
      setError(mensajeError(e));
    } finally {
      setEnviando(null);
    }
  }

  const detalle = [
    `DNI ${enmascararDni(cuidador?.dni ?? null)}`,
    cuidador?.edad != null ? `${cuidador.edad} años` : null,
    cuidador?.distrito,
    v.enviadoEn ? `enviado ${hace(v.enviadoEn, ahora)}` : null,
  ].filter(Boolean);

  return (
    <>
      <Volver />
      <header className="encabezado encabezado-cuidador">
        <Avatar nombre={nombre} foto={cuidador?.fotoUrl} tam={64} />
        <div className="crece">
          <h1>{nombre}</h1>
          <p className="subtitulo">{detalle.join(" · ")}</p>
        </div>
        <div className="estado-cabecera">
          <Chip tono={enRevision ? "acento" : TONO_ESTADO[est]}>{enRevision ? "En revisión" : ETIQUETA_ESTADO[est]}</Chip>
          {enRevision && tiempo.detalle && <span className="detalle-tiempo">{tiempo.detalle}</span>}
        </div>
      </header>

      {!enRevision && (
        <Aviso tono="info">
          {v.estado === "aprobada" && `Verificación aprobada el ${fechaCorta(v.revisadoEn)}.`}
          {v.estado === "rechazada" && `Rechazada el ${fechaCorta(v.revisadoEn)}: “${v.motivoRechazo ?? ""}”. Esperando que el cuidador vuelva a enviar.`}
          {v.estado === "incompleta" && "El cuidador todavía no envió sus documentos a revisión."}
          {v.estado === "revocada" && "La verificación fue revocada."}
        </Aviso>
      )}

      <section className="documentos" aria-label="Documentos">
        {DOCUMENTOS_OBLIGATORIOS.map((t) => (
          <TarjetaDocumento
            key={t}
            tipo={t}
            entregado={estaEntregado(v, t)}
            ruta={v.archivos[t]}
            enlace={enlaces?.[t]}
            cargando={enlaces === null}
            conforme={documentoConforme(t, marcas)}
            antecedentesBorrados={t === "antecedentes" && v.estado === "aprobada"}
            onVer={() => setGrande(t)}
          />
        ))}
      </section>
      {v.archivos.cv && enlaces?.cv && (
        <p className="nota">
          También subió su{" "}
          <a href={enlaces.cv} target="_blank" rel="noreferrer">
            CV (opcional)
          </a>
          .
        </p>
      )}

      <section className="detalle-revision">
        <div className="tarjeta panel">
          <h2>Checklist de revisión</h2>
          {CHECKLIST.map((p) => (
            <label key={p.id} className="casilla">
              <input
                type="checkbox"
                checked={marcas[p.id] === true}
                disabled={!enRevision}
                onChange={(e) => setMarcas((m) => ({ ...m, [p.id]: e.target.checked }))}
              />
              <span className="casilla-caja" aria-hidden="true" />
              {p.texto}
            </label>
          ))}
          <p className="nota">Lo que no marques se le pedirá al cuidador volver a subir si lo rechazas.</p>
        </div>

        <div className="tarjeta panel">
          <h2>Decisión</h2>
          <label className="campo">
            <span>Motivo de rechazo (obligatorio si rechazas)</span>
            <textarea
              rows={2}
              maxLength={500}
              value={motivo}
              disabled={!enRevision}
              onChange={(e) => setMotivo(e.target.value)}
              placeholder="Ej.: El certificado de antecedentes está vencido. Sube uno emitido en los últimos 3 meses."
            />
          </label>
          {error && <Aviso>{error}</Aviso>}
          <div className="acciones">
            <button
              className="boton boton-borde-error"
              disabled={!enRevision || enviando !== null}
              onClick={() => void decidir(false)}
            >
              {enviando === "rechazar" ? "Rechazando…" : "Rechazar"}
            </button>
            <button
              className="boton boton-primario"
              disabled={!enRevision || enviando !== null || !checklistCompleto(marcas)}
              title={checklistCompleto(marcas) ? undefined : "Marca todo el checklist para aprobar"}
              onClick={() => void decidir(true)}
            >
              {enviando === "aprobar" ? "Aprobando…" : "Aprobar y notificar"}
            </button>
          </div>
          <p className="nota">Al aprobar, el cuidador recibe la insignia Verificado y una notificación.</p>
        </div>
      </section>

      {grande && enlaces?.[grande] && (
        <VisorDocumento titulo={NOMBRE_DOCUMENTO[grande]} url={enlaces[grande]!} pdf={esPdf(v.archivos[grande])} onCerrar={() => setGrande(null)} />
      )}
    </>
  );
}

function Volver() {
  return (
    <Link to="/verificaciones" className="volver">
      <IconoAtras tam={16} /> Verificaciones
    </Link>
  );
}

function TarjetaDocumento(p: {
  tipo: TipoDocumento;
  entregado: boolean;
  ruta?: string;
  enlace?: string;
  cargando: boolean;
  conforme: boolean;
  antecedentesBorrados: boolean;
  onVer: () => void;
}) {
  const Icono = p.tipo === "selfie" ? IconoCamara : IconoDocumento;
  const imagen = p.enlace && !esPdf(p.ruta);
  let vacio = "Ver en grande";
  if (!p.entregado) vacio = "No lo subió";
  else if (p.antecedentesBorrados) vacio = "Eliminado al aprobar";
  else if (!p.enlace) vacio = p.cargando ? "Cargando…" : "No disponible";
  return (
    <article className="tarjeta documento">
      <button
        className="vista-previa"
        disabled={!p.enlace}
        onClick={p.onVer}
        aria-label={`Ver ${NOMBRE_DOCUMENTO[p.tipo]} en grande`}
      >
        {imagen ? (
          <img src={p.enlace} alt="" />
        ) : (
          <>
            <Icono tam={36} />
            <span>{p.enlace ? (esPdf(p.ruta) ? "Abrir PDF" : "Ver en grande") : vacio}</span>
          </>
        )}
      </button>
      <footer className="documento-pie">
        <span>{NOMBRE_DOCUMENTO[p.tipo]}</span>
        {!p.entregado ? (
          <Chip tono="error">Falta</Chip>
        ) : p.conforme ? (
          <IconoVerificado tam={22} className="texto-exito" aria-label="Conforme" />
        ) : (
          <Chip tono="acento">Revisar</Chip>
        )}
      </footer>
    </article>
  );
}

function VisorDocumento({ titulo, url, pdf, onCerrar }: { titulo: string; url: string; pdf: boolean; onCerrar: () => void }) {
  useEffect(() => {
    const tecla = (e: KeyboardEvent) => e.key === "Escape" && onCerrar();
    window.addEventListener("keydown", tecla);
    return () => window.removeEventListener("keydown", tecla);
  }, [onCerrar]);
  return (
    <div className="visor" role="dialog" aria-modal="true" aria-label={titulo} onClick={onCerrar}>
      <div className="visor-caja" onClick={(e) => e.stopPropagation()}>
        <header>
          <strong>{titulo}</strong>
          <a href={url} target="_blank" rel="noreferrer">
            Abrir en otra pestaña
          </a>
          <button className="boton-plano" onClick={onCerrar} aria-label="Cerrar">
            <IconoCerrar />
          </button>
        </header>
        {pdf ? <iframe src={url} title={titulo} /> : <img src={url} alt={titulo} />}
      </div>
    </div>
  );
}
