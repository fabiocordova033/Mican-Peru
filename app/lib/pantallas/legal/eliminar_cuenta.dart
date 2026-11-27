import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../componentes/base.dart';
import '../../componentes/estructura.dart';
import '../../datos/api.dart';
import '../../datos/proveedores.dart';
import '../../tema/colores.dart';
import '../../tema/iconos.dart';
import '../../tema/tipografia.dart';
import '../../util/formato.dart';
import '../../util/ui.dart';

/// Pantalla 27 · Eliminar cuenta (HU-32). 30 días de gracia para recuperarla.
class PantallaEliminarCuenta extends ConsumerStatefulWidget {
  const PantallaEliminarCuenta({super.key});

  @override
  ConsumerState<PantallaEliminarCuenta> createState() => _PantallaEliminarCuentaState();
}

class _PantallaEliminarCuentaState extends ConsumerState<PantallaEliminarCuenta> {
  final _confirmacion = TextEditingController();
  bool _renunciarSaldo = false;
  bool _enviando = false;

  Future<void> _eliminar() async {
    setState(() => _enviando = true);
    try {
      await ref
          .read(apiProvider)
          .eliminarCuenta(confirmacion: _confirmacion.text.trim(), renunciarSaldo: _renunciarSaldo);
      await ref.read(authProvider).signOut();
      if (mounted) context.go('/');
    } on ErrorMican catch (e) {
      if (!mounted) return;
      if (e.datos['ofrecerDevolucion'] == true) {
        final saldo = (e.datos['saldo'] as num?)?.toInt() ?? 0;
        final ir = await confirmar(
          context,
          titulo: 'Tienes ${soles(saldo)} de saldo',
          texto: 'Pide la devolución antes de eliminar tu cuenta, o marca que renuncias a ese saldo.',
          si: 'Ir a mi billetera',
          no: 'Cerrar',
        );
        if (ir && mounted) context.push('/billetera');
      } else {
        mostrarError(context, e);
      }
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esCuidador = ref.watch(usuarioProvider).value?.esCuidador ?? false;
    final listo = _confirmacion.text.trim() == 'ELIMINAR';
    return PantallaMican(
      titulo: 'Eliminar cuenta',
      espacio: 16,
      barraAccion: BarraAccion(
        vertical: true,
        children: [
          Boton(
            'Eliminar mi cuenta',
            tipo: TipoBoton.peligro,
            cargando: _enviando,
            alPresionar: listo ? _eliminar : null,
          ),
          Boton('Mejor no', tipo: TipoBoton.fantasma, alPresionar: () => context.pop()),
        ],
      ),
      children: [
        const Center(
          child: CajaIcono(
            MicanIcono.cerrar,
            tamano: 72,
            tamanoIcono: 34,
            radio: 999,
            fondo: MicanColores.errorSuave,
            color: MicanColores.error,
          ),
        ),
        Text('¿Seguro que quieres irte?', style: MicanTexto.titulo1, textAlign: TextAlign.center),
        Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Qué pasará', style: MicanTexto.subtitulo),
              const SizedBox(height: 10),
              for (final t in const [
                'Tu perfil se oculta de inmediato y se cierra tu sesión en todos tus celulares.',
                'Tienes 30 días para arrepentirte: entra con tu celular y recupérala.',
                'Luego borramos tus datos, mascotas, fotos y conversaciones.',
                'Conservamos comprobantes de pago (5 años) y reclamos (2 años) por ley.',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Icono(MicanIcono.huella, tamano: 14, color: MicanColores.primario),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t, style: MicanTexto.cuerpo)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (esCuidador)
          GestureDetector(
            onTap: () => setState(() => _renunciarSaldo = !_renunciarSaldo),
            child: Row(
              children: [
                Casilla(marcada: _renunciarSaldo),
                const SizedBox(width: 10),
                Expanded(child: Text('Renuncio a mi saldo de billetera, si lo hubiera', style: MicanTexto.cuerpo)),
              ],
            ),
          ),
        CampoTexto(
          etiqueta: 'Escribe ELIMINAR para confirmar',
          controlador: _confirmacion,
          mayusculas: TextCapitalization.characters,
          alCambiar: (_) => setState(() {}),
        ),
      ],
    );
  }
}

/// Cuenta en eliminación: se puede recuperar durante los 30 días de gracia.
class PantallaRecuperarCuenta extends ConsumerStatefulWidget {
  const PantallaRecuperarCuenta({super.key});

  @override
  ConsumerState<PantallaRecuperarCuenta> createState() => _PantallaRecuperarCuentaState();
}

class _PantallaRecuperarCuentaState extends ConsumerState<PantallaRecuperarCuenta> {
  bool _enviando = false;

  Future<void> _recuperar() async {
    setState(() => _enviando = true);
    final ok = await intentar(context, ref.read(apiProvider).recuperarCuenta);
    if (!mounted) return;
    setState(() => _enviando = false);
    if (ok) {
      avisar(context, '¡Qué bueno tenerte de vuelta!');
      context.go('/app');
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = ref.watch(usuarioProvider).value;
    return PantallaMican(
      titulo: 'Recuperar cuenta',
      mostrarAtras: false,
      espacio: 16,
      barraAccion: BarraAccion(
        vertical: true,
        children: [
          Boton('Recuperar mi cuenta', cargando: _enviando, alPresionar: _recuperar),
          Boton('Cerrar sesión', tipo: TipoBoton.fantasma, alPresionar: () => ref.read(authProvider).signOut()),
        ],
      ),
      children: [
        const SizedBox(height: 24),
        const Center(
          child: CajaIcono(MicanIcono.reloj, tamano: 80, tamanoIcono: 40, radio: 999, color: MicanColores.primario),
        ),
        Text('Tu cuenta está por eliminarse', style: MicanTexto.titulo1, textAlign: TextAlign.center),
        Text(
          u?.eliminarEn == null
              ? 'Aún estás a tiempo de recuperarla.'
              : 'Se eliminará el ${fechaRelativa(u!.eliminarEn, conHora: false).toLowerCase()}. Aún estás a tiempo de recuperarla.',
          style: MicanTexto.cuerpo.copyWith(color: MicanColores.textoSecundario),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
