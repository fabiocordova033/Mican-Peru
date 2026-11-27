import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../componentes/base.dart';
import '../../componentes/estructura.dart';
import '../../componentes/tarjetas.dart';
import '../../datos/modelos.dart';
import '../../datos/proveedores.dart';
import '../../tema/colores.dart';
import '../../tema/iconos.dart';
import '../../tema/tipografia.dart';
import '../../util/formato.dart';
import '../../util/ui.dart';

/// Pantalla 08 · Billetera (cuidador).
class PantallaBilletera extends ConsumerWidget {
  const PantallaBilletera({super.key});

  Future<void> _devolucion(BuildContext context, WidgetRef ref, int saldo) async {
    if (saldo <= 0) return avisar(context, 'No tienes saldo para devolver.');
    final cuenta = await pedirTexto(
      context,
      titulo: 'Devolver mi saldo (${soles(saldo)})',
      etiqueta: 'Número de Yape, Plin o cuenta bancaria',
      teclado: TextInputType.text,
      boton: 'Solicitar devolución',
    );
    if (cuenta == null || cuenta.isEmpty || !context.mounted) return;
    final ok = await intentar(context, () => ref.read(apiProvider).solicitarDevolucionSaldo(cuenta));
    if (ok && context.mounted) avisar(context, 'Listo. Te depositaremos en un plazo de 5 días hábiles.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saldo = ref.watch(saldoProvider).value ?? 0;
    final movimientos = ref.watch(movimientosProvider).value;
    final servicios = ref.watch(serviciosCuidadorProvider).value ?? const <Servicio>[];
    final inicioSemana = DateUtils.dateOnly(DateTime.now()).subtract(Duration(days: DateTime.now().weekday - 1));
    final semana = servicios.where(
      (s) => s.estado == EstadoServicio.completado && s.finalizadoEn != null && !s.finalizadoEn!.isBefore(inicioSemana),
    );
    final ganado = semana.fold<int>(0, (t, s) => t + (s.resumen?.recibeCuidador ?? s.precio - comision(s.precio)));
    final comisiones = semana.fold<int>(0, (t, s) => t + (s.resumen?.comision ?? comision(s.precio)));

    return PantallaMican(
      titulo: 'Billetera',
      children: [
        TarjetaSaldo(saldo: soles(saldo), alRecargar: () => context.push('/recargar')),
        if (saldo < 1000)
          const Aviso(
            icono: MicanIcono.billetera,
            texto: 'Con menos de S/ 10 no podrás ver solicitudes nuevas.',
            fondo: MicanColores.acentoSuave,
            color: MicanColores.textoPrincipal,
            colorIcono: MicanColores.acento,
          ),
        const TituloSeccion('Esta semana'),
        Row(
          children: [
            Expanded(
              child: CajaDato(valor: '${semana.length}', etiqueta: 'servicios'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: CajaDato(valor: solesCortos(ganado), etiqueta: 'ganado', colorValor: MicanColores.exito),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: CajaDato(valor: solesCortos(comisiones), etiqueta: 'comisiones', colorValor: MicanColores.error),
            ),
          ],
        ),
        const TituloSeccion('Movimientos'),
        if (movimientos == null)
          const Cargando()
        else if (movimientos.isEmpty)
          const Vacio(
            icono: MicanIcono.billetera,
            titulo: 'Aún no hay movimientos',
            texto: 'Tus recargas y comisiones aparecerán aquí.',
          )
        else
          ListaTarjeta(
            children: [
              for (final m in movimientos)
                FilaLista(
                  icono: m.monto >= 0 ? MicanIcono.mas : MicanIcono.huella,
                  fondoIcono: m.monto >= 0 ? MicanColores.exitoSuave : MicanColores.superficieGris,
                  colorIcono: m.monto >= 0 ? MicanColores.exito : MicanColores.textoPrincipal,
                  titulo: _titulo(m),
                  subtitulo: fechaRelativa(m.creadoEn),
                  final_: Text(
                    '${m.monto >= 0 ? '+' : '−'} ${soles(m.monto.abs())}',
                    style: MicanTexto.cuerpoFuerte.copyWith(
                      color: m.monto >= 0 ? MicanColores.exito : MicanColores.textoPrincipal,
                    ),
                  ),
                ),
            ],
          ),
        Boton(
          'Solicitar devolución de saldo',
          tipo: TipoBoton.fantasma,
          alPresionar: () => _devolucion(context, ref, saldo),
        ),
      ],
    );
  }

  String _titulo(Movimiento m) => switch (m.tipo) {
    'recarga' => 'Recarga',
    'comision' => m.mascotaNombre == null ? 'Comisión' : 'Comisión · ${m.mascotaNombre}',
    'devolucion' => 'Devolución de saldo',
    _ => m.descripcion.isEmpty ? 'Ajuste' : m.descripcion,
  };
}

/// Pantalla 16 · Recargar saldo. El pago se hace en el checkout de Mercado
/// Pago (se abre en el navegador) y un webhook acredita el saldo; la pantalla
/// de billetera escucha el saldo en Firestore y se actualiza sola.
class PantallaRecargar extends ConsumerStatefulWidget {
  const PantallaRecargar({super.key});

  @override
  ConsumerState<PantallaRecargar> createState() => _PantallaRecargarState();
}

class _PantallaRecargarState extends ConsumerState<PantallaRecargar> {
  static const _montos = [2000, 3000, 5000, 10000];
  int _monto = 3000;
  bool _otro = false;
  bool _enviando = false;

  Future<void> _elegirOtro() async {
    final t = await pedirTexto(
      context,
      titulo: '¿Cuánto quieres recargar?',
      etiqueta: 'Entre S/ 10 y S/ 500',
      teclado: TextInputType.number,
      prefijo: 'S/ ',
      boton: 'Usar este monto',
    );
    final soles = int.tryParse(t ?? '');
    if (soles == null || !mounted) return;
    if (soles < 10 || soles > 500) return avisar(context, 'La recarga va de S/ 10 a S/ 500.');
    setState(() {
      _otro = true;
      _monto = soles * 100;
    });
  }

  Future<void> _pagar() async {
    setState(() => _enviando = true);
    final ok = await intentar(context, () async {
      final r = await ref.read(apiProvider).iniciarRecarga(_monto);
      await launchUrl(Uri.parse(r.urlPago), mode: LaunchMode.externalApplication);
    });
    if (!mounted) return;
    setState(() => _enviando = false);
    if (ok) {
      avisar(context, 'Tu saldo se actualizará apenas se confirme el pago.');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final saldo = ref.watch(saldoProvider).value ?? 0;
    return PantallaMican(
      titulo: 'Recargar saldo',
      espacio: 16,
      barraAccion: BarraAccion(
        children: [
          Expanded(
            child: Boton('Pagar ${soles(_monto)}', cargando: _enviando, alPresionar: _pagar),
          ),
        ],
      ),
      children: [
        Tarjeta(
          child: Row(
            children: [
              const CajaIcono(MicanIcono.billetera),
              const SizedBox(width: 12),
              Expanded(child: Text('Saldo actual', style: MicanTexto.cuerpo)),
              Text(soles(saldo), style: MicanTexto.titulo2.copyWith(color: MicanColores.primario)),
            ],
          ),
        ),
        Text('¿Cuánto quieres recargar?', style: MicanTexto.subtitulo),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.6,
          children: [
            for (final m in _montos)
              _Monto(
                texto: solesCortos(m),
                seleccionado: !_otro && _monto == m,
                alPresionar: () => setState(() {
                  _otro = false;
                  _monto = m;
                }),
              ),
          ],
        ),
        _Monto(
          texto: _otro ? 'Otro: ${solesCortos(_monto)}' : 'Otro monto',
          seleccionado: _otro,
          alPresionar: _elegirOtro,
        ),
        Tarjeta(
          child: Column(
            children: [
              FilaResumen('Recarga', soles(_monto)),
              const SizedBox(height: 10),
              FilaResumen('Saldo después', soles(saldo + _monto), colorValor: MicanColores.exito, fuerte: true),
              const SizedBox(height: 10),
              FilaResumen('Alcanza para', '≈ ${(_monto / 300).floor()} paseos de S/ 25'),
            ],
          ),
        ),
        const NotaConIcono(
          icono: MicanIcono.candado,
          texto: 'Pagas con Yape, tarjeta o PagoEfectivo en Mercado Pago. Mican no guarda los datos de tu tarjeta.',
        ),
      ],
    );
  }
}

class _Monto extends StatelessWidget {
  const _Monto({required this.texto, required this.seleccionado, required this.alPresionar});

  final String texto;
  final bool seleccionado;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      padding: const EdgeInsets.symmetric(vertical: 14),
      alPresionar: alPresionar,
      borde: BorderSide(color: seleccionado ? MicanColores.primario : MicanColores.superficieTarjeta, width: 2),
      color: seleccionado ? MicanColores.primarioSuave : MicanColores.superficieTarjeta,
      child: Center(
        child: Text(
          texto,
          style: MicanTexto.titulo2.copyWith(color: seleccionado ? MicanColores.primario : MicanColores.textoPrincipal),
        ),
      ),
    );
  }
}
