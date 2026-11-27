import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import 'servicio.dart';

/// Pantalla 04 · Ofertas recibidas (HU-13, HU-14).
class PantallaOfertas extends ConsumerStatefulWidget {
  const PantallaOfertas({super.key, required this.servicio});

  final Servicio servicio;

  @override
  ConsumerState<PantallaOfertas> createState() => _PantallaOfertasState();
}

class _PantallaOfertasState extends ConsumerState<PantallaOfertas> {
  /// "Rechazar" solo oculta la oferta en este dispositivo: la oferta vence
  /// sola a los 60 s y, al aceptar otra, el backend rechaza el resto.
  final _ocultas = <String>{};
  String? _aceptando;
  bool _subiendo = false;

  Servicio get s => widget.servicio;

  Future<void> _aceptar(Oferta o) async {
    setState(() => _aceptando = o.cuidadorId);
    await intentar(context, () => ref.read(apiProvider).aceptarOferta(s.id, o.cuidadorId));
    if (mounted) setState(() => _aceptando = null);
    // El servicio pasa a "confirmado" y PantallaServicio cambia sola.
  }

  Future<void> _subirPrecio(int delta) async {
    setState(() => _subiendo = true);
    await intentar(context, () => ref.read(apiProvider).subirPrecio(s.id, s.precioOfrecido + delta));
    if (mounted) setState(() => _subiendo = false);
  }

  Future<void> _cancelar() async {
    final ok = await confirmar(
      context,
      titulo: '¿Cancelar la solicitud?',
      texto: 'Los cuidadores dejarán de ver tu solicitud.',
      si: 'Sí, cancelar',
      no: 'Seguir buscando',
      peligro: true,
    );
    if (!ok || !mounted) return;
    await intentar(
      context,
      () => ref.read(apiProvider).cancelarServicio(s.id, 'Cancelada por el dueño mientras buscaba'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ahora = ref.watch(relojProvider).value ?? DateTime.now();
    final ofertas = (ref.watch(ofertasProvider(s.id)).value ?? const <Oferta>[])
        .where((o) => o.expiraEn.isAfter(ahora) && !_ocultas.contains(o.cuidadorId))
        .toList();
    final restante = s.expiraEn?.difference(ahora) ?? Duration.zero;
    const total = Duration(minutes: 15);
    final sinOfertasHace = s.creadoEn == null ? Duration.zero : ahora.difference(s.creadoEn!);
    final sugerirSubir = !s.esPaquete && (s.sugerenciaSubirPrecio || sinOfertasHace.inMinutes >= 3) && ofertas.isEmpty;

    return PantallaMican(
      titulo: 'Ofertas para ${s.mascota.nombre}',
      alVolver: () => context.go('/app'),
      accion: BotonCircular(icono: MicanIcono.cerrar, alPresionar: _cancelar),
      children: [
        ResumenSolicitud(
          titulo: s.esPaquete
              ? 'Paquete: ${solesCortos(s.precioOfrecido)} · ${s.tipo.nombre} de ${duracion(s.duracionMin)}'
              : 'Tu oferta: ${solesCortos(s.precioOfrecido)} · ${s.tipo.nombre} de ${duracion(s.duracionMin)}',
          subtitulo: s.esPaquete
              ? 'El primer cuidador que acepte queda asignado'
              : '${s.ofertasRecibidas} cuidador${s.ofertasRecibidas == 1 ? '' : 'es'} respondi${s.ofertasRecibidas == 1 ? 'ó' : 'eron'}',
        ),
        if (ofertas.isEmpty)
          Tarjeta(
            child: Column(
              children: [
                const SizedBox(height: 8),
                const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
                const SizedBox(height: 14),
                Text('Buscando cuidadores cerca…', style: MicanTexto.subtitulo),
                const SizedBox(height: 4),
                Text(
                  'Avisamos a los cuidadores verificados a menos de 3 km.',
                  style: MicanTexto.leyenda,
                  textAlign: TextAlign.center,
                ),
                if (sugerirSubir) ...[
                  const SizedBox(height: 16),
                  const Aviso(
                    icono: MicanIcono.actividad,
                    texto: 'Aún no hay ofertas. Subir un poco el precio ayuda a que te respondan.',
                    fondo: MicanColores.acentoSuave,
                    color: MicanColores.textoPrincipal,
                    colorIcono: MicanColores.acento,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final d in const [200, 500]) ...[
                        if (d != 200) const SizedBox(width: 10),
                        Expanded(
                          child: Boton(
                            'Subir a ${solesCortos(s.precioOfrecido + d)}',
                            tipo: TipoBoton.contorno,
                            cargando: _subiendo,
                            alPresionar: () => _subirPrecio(d),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        for (final o in ofertas)
          TarjetaOferta(
            nombre: o.nombre,
            fotoUrl: o.fotoUrl,
            nota: o.calificacionPromedio,
            resenas: o.numResenas,
            precio: solesCortos(o.precio),
            llegada: 'llega en ${o.minutosLlegada} min',
            esContraoferta: o.esContraoferta,
            segundosRestantes: o.expiraEn.difference(ahora).inSeconds,
            aceptando: _aceptando == o.cuidadorId,
            alAceptar: _aceptando == null ? () => _aceptar(o) : null,
            alRechazar: () => setState(() => _ocultas.add(o.cuidadorId)),
            alVerPerfil: () => context.push('/cuidador/${o.cuidadorId}?servicio=${s.id}&precio=${o.precio}'),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              restante.isNegative
                  ? 'Tu solicitud se está cerrando…'
                  : 'Tu solicitud se cierra en ${mmss(restante.inSeconds)} si nadie la toma',
              style: MicanTexto.leyenda,
            ),
            const SizedBox(height: 6),
            BarraProgreso(valor: restante.inSeconds / total.inSeconds),
          ],
        ),
      ],
    );
  }
}
