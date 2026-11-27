import { DocumentReference, DocumentSnapshot, Transaction } from "firebase-admin/firestore";
import { Nivel } from "../config/reglas";
import { calcularNivel } from "../dominio/niveles";
import { COL, FieldValue } from "./firebase";
import { refPerfil } from "./usuarios";

export interface ResultadoRevelado {
  /** Cuidadores que cambiaron de nivel. */
  cambiosNivel: { uid: string; antes: Nivel; despues: Nivel }[];
}

/**
 * HU-24 + HU-25: revela las calificaciones de un servicio (cuando ambas
 * partes calificaron o venció el plazo de 7 días), actualiza el promedio de
 * cada calificado y recalcula el nivel del cuidador.
 *
 * Hace todas sus lecturas primero; llámala antes de cualquier escritura de la
 * transacción. `pendiente` es una calificación aún no guardada (la que se
 * está creando en esta misma transacción), si la hay.
 */
export async function revelarCalificaciones(
  tx: Transaction,
  servicioRef: DocumentReference,
  existentes: DocumentSnapshot[],
  pendiente?: { ref: DocumentReference; data: FirebaseFirestore.DocumentData },
): Promise<() => ResultadoRevelado> {
  const todas = [
    ...existentes.map((s) => ({ ref: s.ref, data: s.data()! })),
    ...(pendiente ? [pendiente] : []),
  ].filter((c) => !c.data.visible);

  const calificados = [...new Set(todas.map((c) => c.data.calificadoId as string))];
  const perfiles = await Promise.all(calificados.map((uid) => tx.get(refPerfil(uid))));
  const ahora = new Date();

  return () => {
    const cambiosNivel: ResultadoRevelado["cambiosNivel"] = [];
    for (const perfilSnap of perfiles) {
      if (!perfilSnap.exists) continue;
      const suyas = todas.filter((c) => c.data.calificadoId === perfilSnap.id);
      const p = perfilSnap.data()!;
      const suma = (p.sumaEstrellas ?? 0) + suyas.reduce((a, c) => a + c.data.estrellas, 0);
      const num = (p.numResenas ?? 0) + suyas.length;
      const promedio = num ? Math.round((suma / num) * 100) / 100 : 0;
      const cambios: Record<string, unknown> = {
        sumaEstrellas: suma,
        numResenas: num,
        calificacionPromedio: promedio,
      };
      for (const c of suyas) {
        for (const e of c.data.etiquetas ?? []) cambios[`etiquetas.${e}`] = FieldValue.increment(1);
      }
      const comoCuidador = suyas.some((c) => c.data.rolCalificado === "cuidador");
      if (comoCuidador) {
        const antes = (p.nivel ?? "nuevo") as Nivel;
        const despues = calcularNivel(
          {
            serviciosCompletados: p.serviciosCompletados ?? 0,
            calificacionPromedio: promedio,
            ultimoIncidente: p.ultimoIncidenteEn?.toDate() ?? null,
          },
          ahora,
        );
        if (despues !== antes) {
          cambios.nivel = despues;
          cambiosNivel.push({ uid: perfilSnap.id, antes, despues });
        }
      }
      tx.update(perfilSnap.ref, cambios);
    }
    for (const c of todas) {
      if (c === pendiente) tx.set(c.ref, { ...c.data, visible: true, reveladaEn: FieldValue.serverTimestamp() });
      else tx.update(c.ref, { visible: true, reveladaEn: FieldValue.serverTimestamp() });
    }
    tx.update(servicioRef, { calificacionesReveladas: true });
    return { cambiosNivel };
  };
}

export const coleccionCalificaciones = (servicioRef: DocumentReference) =>
  servicioRef.collection(COL.calificaciones);
