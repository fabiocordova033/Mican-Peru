import {
  Timestamp,
  collection,
  doc,
  getCountFromServer,
  getDoc,
  getDocs,
  limit,
  onSnapshot,
  orderBy,
  query,
  where,
  type DocumentData,
} from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { getBlob, ref } from "firebase/storage";
import type { Cuidador, Reclamo, Recarga, ServicioCompletado, TipoDocumento, Verificacion } from "../dominio/tipos";
import type { ApiPanel } from "./api";
import { db, funciones, storage } from "./firebase";

const fecha = (v: unknown): Date | null => (v instanceof Timestamp ? v.toDate() : null);

export function aVerificacion(uid: string, d: DocumentData): Verificacion {
  return {
    uid,
    estado: d.estado ?? "incompleta",
    documentos: d.documentos ?? {},
    archivos: d.archivos ?? {},
    enviadoEn: fecha(d.enviadoEn),
    venceRevisionEn: fecha(d.venceRevisionEn),
    actualizadoEn: fecha(d.actualizadoEn) ?? fecha(d.creadoEn),
    revisadoEn: fecha(d.revisadoEn),
    motivoRechazo: d.motivoRechazo ?? null,
  };
}

const MAX_FINANZAS = 1000;

export const apiFirebase: ApiPanel = {
  observarVerificaciones(estado, cb, error) {
    const q = query(collection(db, "verificaciones"), where("estado", "==", estado), limit(200));
    return onSnapshot(q, (s) => cb(s.docs.map((d) => aVerificacion(d.id, d.data()))), error);
  },

  async contarRevisadas(estado, desde) {
    const q = query(
      collection(db, "verificaciones"),
      where("estado", "==", estado),
      where("revisadoEn", ">=", Timestamp.fromDate(desde)),
    );
    return (await getCountFromServer(q)).data().count;
  },

  async cuidadores(uids) {
    const res = new Map<string, Cuidador>();
    await Promise.all(
      [...new Set(uids)].map(async (uid) => {
        const [perfil, privado] = await Promise.all([
          getDoc(doc(db, "perfilesPublicos", uid)),
          getDoc(doc(db, "usuarios", uid)),
        ]);
        const p = perfil.data() ?? {};
        const u = privado.data() ?? {};
        res.set(uid, {
          uid,
          nombre: u.nombre ?? p.nombre ?? "Sin nombre",
          edad: typeof p.edad === "number" ? p.edad : null,
          distrito: p.distrito ?? u.distrito ?? null,
          fotoUrl: p.fotoUrl ?? null,
          dni: u.dni ?? null,
          telefono: u.telefono ?? null,
        });
      }),
    );
    return res;
  },

  observarVerificacion(uid, cb, error) {
    return onSnapshot(
      doc(db, "verificaciones", uid),
      (s) => cb(s.exists() ? aVerificacion(s.id, s.data()) : null),
      error,
    );
  },

  async enlacesDocumentos(v) {
    try {
      const r = await httpsCallable<{ uid: string }, { enlaces: Partial<Record<TipoDocumento, string>> }>(
        funciones,
        "enlacesDocumentosVerificacion",
      )({ uid: v.uid });
      return r.data.enlaces;
    } catch (e) {
      // En los emuladores no hay cuenta de servicio para firmar URLs: se descarga
      // el archivo con la sesión del admin (las reglas de Storage lo permiten).
      console.warn("Enlaces firmados no disponibles, se descargan los archivos", e);
      const enlaces: Partial<Record<TipoDocumento, string>> = {};
      await Promise.all(
        Object.entries(v.archivos).map(async ([tipo, ruta]) => {
          if (!ruta) return;
          try {
            enlaces[tipo as TipoDocumento] = URL.createObjectURL(await getBlob(ref(storage, ruta)));
          } catch (err) {
            console.warn(`No se pudo leer ${ruta}`, err);
          }
        }),
      );
      return enlaces;
    }
  },

  async revisarCuidador(d) {
    await httpsCallable(funciones, "revisarCuidador")(d);
  },

  async reclamos() {
    const s = await getDocs(query(collection(db, "reclamos"), orderBy("creadoEn", "desc"), limit(200)));
    return s.docs.map((d): Reclamo => {
      const r = d.data();
      return {
        id: d.id,
        numero: r.numero ?? d.id,
        tipo: r.tipo,
        consumidor: r.consumidor ?? { nombre: "", documento: "", correo: "", domicilio: "" },
        servicioId: r.servicioId ?? null,
        montoReclamado: r.montoReclamado ?? null,
        detalle: r.detalle ?? "",
        pedido: r.pedido ?? "",
        estado: r.estado ?? "recibido",
        creadoEn: fecha(r.creadoEn),
        venceEn: fecha(r.venceEn),
      };
    });
  },

  async finanzas(desde, hasta) {
    const rango = (campo: string) => [
      where(campo, ">=", Timestamp.fromDate(desde)),
      where(campo, "<", Timestamp.fromDate(hasta)),
    ];
    const [serv, pagos] = await Promise.all([
      getDocs(
        query(
          collection(db, "servicios"),
          where("estado", "==", "completado"),
          ...rango("finalizadoEn"),
          orderBy("finalizadoEn", "desc"),
          limit(MAX_FINANZAS),
        ),
      ),
      getDocs(
        query(
          collection(db, "pagos"),
          where("tipo", "==", "recarga"),
          where("estado", "==", "pagado"),
          ...rango("pagadoEn"),
          limit(MAX_FINANZAS),
        ),
      ),
    ]);
    const servicios = serv.docs.map((d): ServicioCompletado => {
      const s = d.data();
      return {
        id: d.id,
        tipo: s.tipo,
        duenoNombre: s.duenoNombre ?? "",
        cuidadorNombre: s.cuidadorNombre ?? "",
        mascotaNombre: s.mascota?.nombre ?? "",
        precioFinal: s.precioFinal ?? s.resumen?.precio ?? 0,
        comision: s.comision ?? s.resumen?.comision ?? 0,
        comisionTasa: s.comisionTasa ?? 0,
        metodoPago: s.metodoPago ?? "",
        finalizadoEn: fecha(s.finalizadoEn),
      };
    });
    const recargas = pagos.docs.map((d): Recarga => ({ id: d.id, monto: d.get("monto") ?? 0, pagadoEn: fecha(d.get("pagadoEn")) }));
    return { servicios, recargas, truncado: serv.size >= MAX_FINANZAS || pagos.size >= MAX_FINANZAS };
  },
};
