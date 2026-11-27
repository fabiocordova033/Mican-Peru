import { Transaction } from "firebase-admin/firestore";
import { Nivel, SALDO_MINIMO_CENTIMOS } from "../config/reglas";
import { calcularComision, formatearSoles, tasaComision } from "../dominio/dinero";
import { ESTADOS_ACTIVOS } from "../dominio/servicio";
import { leerSaldo } from "./billetera";
import { falla } from "./errores";
import { COL, db } from "./firebase";
import { refPerfil, refUsuario } from "./usuarios";

export interface CuidadorApto {
  perfil: FirebaseFirestore.DocumentData;
  saldo: number;
  tasa: number;
}

/**
 * Reglas para que un cuidador pueda ofertar o tomar un servicio
 * (HU-03, HU-12, HU-13):
 *  - cuenta activa, rol cuidador y verificación aprobada;
 *  - "Disponible" activado;
 *  - saldo de al menos S/ 10 y suficiente para la comisión de ese precio;
 *  - sin otro servicio confirmado o en curso (así el saldo nunca queda negativo).
 */
export async function validarCuidadorApto(
  tx: Transaction,
  uid: string,
  precioCentimos?: number,
): Promise<CuidadorApto> {
  const [usuario, perfil, saldo, activos] = await Promise.all([
    tx.get(refUsuario(uid)),
    tx.get(refPerfil(uid)),
    leerSaldo(tx, uid),
    tx.get(
      db
        .collection(COL.servicios)
        .where("cuidadorId", "==", uid)
        .where("estado", "in", ESTADOS_ACTIVOS)
        .limit(1),
    ),
  ]);
  if (!usuario.exists || usuario.get("estadoCuenta") !== "activa") falla("failed-precondition", "Tu cuenta no está activa");
  if (!usuario.get("roles.cuidador")) falla("permission-denied", "Solo para cuidadores");
  const p = perfil.data() ?? {};
  if (!p.verificado) falla("failed-precondition", "Tu verificación aún no está aprobada");
  if (!p.disponible) falla("failed-precondition", "Activa \"Disponible\" para recibir solicitudes");
  if (!activos.empty) falla("failed-precondition", "Ya tienes un servicio activo");
  const tasa = tasaComision((p.nivel as Nivel) ?? "nuevo");
  const requerido = Math.max(
    SALDO_MINIMO_CENTIMOS,
    precioCentimos !== undefined ? calcularComision(precioCentimos, tasa) : 0,
  );
  if (saldo < requerido) {
    falla("failed-precondition", `Recarga tu saldo: necesitas al menos ${formatearSoles(requerido)}`, {
      recargar: true,
      saldo,
      requerido,
    });
  }
  return { perfil: p, saldo, tasa };
}
