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
import '../dueno/inicio_dueno.dart' show iconoServicio;

/// Pantalla 15 · Contraoferta (cuidador). La oferta dura 60 s y no puede
/// ser menor que el precio del dueño.
class PantallaContraoferta extends ConsumerStatefulWidget {
  const PantallaContraoferta({super.key, required this.solicitud});

  final SolicitudCercana solicitud;

  @override
  ConsumerState<PantallaContraoferta> createState() => _PantallaContraofertaState();
}

class _PantallaContraofertaState extends ConsumerState<PantallaContraoferta> {
  static const _rapidos = [200, 500, 800];
  int _extra = 500;
  bool _otro = false;
  bool _enviando = false;

  int get _precio => widget.solicitud.precioOfrecido + _extra;

  Future<void> _elegirOtro() async {
    final t = await pedirTexto(
      context,
      titulo: '¿Cuánto quieres cobrar?',
      etiqueta: 'Precio total (soles enteros)',
      teclado: TextInputType.number,
      prefijo: 'S/ ',
      boton: 'Usar este precio',
    );
    final soles = int.tryParse(t ?? '');
    if (soles == null || !mounted) return;
    final centimos = soles * 100;
    if (centimos < widget.solicitud.precioOfrecido) {
      return avisar(context, 'Tu oferta no puede ser menor a ${solesCortos(widget.solicitud.precioOfrecido)}.');
    }
    setState(() {
      _otro = true;
      _extra = centimos - widget.solicitud.precioOfrecido;
    });
  }

  Future<void> _enviar() async {
    final u = await ref.read(ubicacionProvider).actual();
    if (!mounted) return;
    if (u == null) return avisar(context, 'Activa tu ubicación para ofertar.');
    setState(() => _enviando = true);
    final ok = await intentar(
      context,
      () =>
          ref.read(apiProvider).enviarOferta(servicioId: widget.solicitud.id, precio: _precio, lat: u.lat, lng: u.lng),
    );
    if (!mounted) return;
    setState(() => _enviando = false);
    if (ok) context.pushReplacement('/servicio/${widget.solicitud.id}');
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.solicitud;
    final com = comision(_precio);
    return PantallaMican(
      titulo: 'Contraoferta',
      espacio: 16,
      barraAccion: BarraAccion(
        children: [
          Expanded(
            child: Boton('Enviar ${solesCortos(_precio)}', cargando: _enviando, alPresionar: _enviar),
          ),
        ],
      ),
      children: [
        Tarjeta(
          child: Row(
            children: [
              CajaIcono(iconoServicio(s.tipo), tamanoIcono: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${s.tipo.nombre} · ${duracion(s.duracionMin)}', style: MicanTexto.cuerpoFuerte),
                    Text(
                      '${s.mascota.emoji} ${s.mascota.nombre} · ${s.distanciaKm.toStringAsFixed(1)} km · ${metodoPago(s.metodoPago)}',
                      style: MicanTexto.leyenda,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('El dueño ofrece', style: MicanTexto.leyenda),
                  Text(solesCortos(s.precioOfrecido), style: MicanTexto.titulo2.copyWith(color: MicanColores.primario)),
                ],
              ),
            ],
          ),
        ),
        Center(
          child: Column(
            children: [
              Text('Tu oferta', style: MicanTexto.etiqueta.copyWith(color: MicanColores.textoSecundario)),
              const SizedBox(height: 4),
              Text(
                solesCortos(_precio),
                style: MicanTexto.display.copyWith(fontSize: 44, height: 1.1, color: MicanColores.primario),
              ),
            ],
          ),
        ),
        Text('Sube el precio', style: MicanTexto.subtitulo),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in _rapidos)
              ChipEtiqueta(
                '+ ${solesCortos(r)}',
                seleccionado: !_otro && _extra == r,
                alPresionar: () => setState(() {
                  _otro = false;
                  _extra = r;
                }),
              ),
            ChipEtiqueta(
              _otro ? 'Otro: ${solesCortos(_precio)}' : 'Otro',
              seleccionado: _otro,
              alPresionar: _elegirOtro,
            ),
          ],
        ),
        Tarjeta(
          child: Column(
            children: [
              FilaResumen('Precio de tu oferta', soles(_precio)),
              const SizedBox(height: 10),
              FilaResumen('Comisión Mican (12%)', soles(-com), colorValor: MicanColores.error),
              const SizedBox(height: 10),
              const Divider(height: 1, color: MicanColores.bordeSuave),
              const SizedBox(height: 10),
              FilaResumen('Recibes', soles(_precio - com), colorValor: MicanColores.exito, fuerte: true),
            ],
          ),
        ),
        const Aviso(
          icono: MicanIcono.reloj,
          texto: 'Tu oferta vence en 60 segundos. La comisión se descuenta de tu saldo solo si completas el servicio.',
        ),
      ],
    );
  }
}
