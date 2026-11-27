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
import '../servicio/servicio.dart';

/// El cuidador envió su oferta y espera que el dueño elija (máx. 60 s).
class EsperandoRespuesta extends ConsumerWidget {
  const EsperandoRespuesta({super.key, required this.servicio});

  final Servicio servicio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = servicio;
    final oferta = ref.watch(miOfertaProvider(s.id)).value;
    final ahora = ref.watch(relojProvider).value ?? DateTime.now();
    final restante = oferta == null ? 0 : oferta.expiraEn.difference(ahora).inSeconds.clamp(0, 60);
    final vigente = oferta != null && oferta.estado == 'pendiente' && restante > 0;
    final rechazada = oferta != null && oferta.estado != 'pendiente';

    return PantallaMican(
      titulo: 'Tu oferta',
      alVolver: () => context.go('/app'),
      espacio: 16,
      barraAccion: BarraAccion(
        children: [
          Expanded(
            child: Boton(
              vigente ? 'Seguir viendo solicitudes' : 'Volver al inicio',
              tipo: vigente ? TipoBoton.contorno : TipoBoton.primario,
              alPresionar: () => context.go('/app'),
            ),
          ),
        ],
      ),
      children: [
        const SizedBox(height: 12),
        Center(
          child: SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: vigente ? restante / 60 : 0,
                    strokeWidth: 8,
                    backgroundColor: MicanColores.bordeSuave,
                    color: MicanColores.acento,
                  ),
                ),
                Text(vigente ? mmss(restante) : '0:00', style: MicanTexto.titulo1),
              ],
            ),
          ),
        ),
        Text(
          vigente
              ? 'Esperando a ${s.duenoNombre.split(' ').first}…'
              : rechazada
              ? 'El dueño eligió otra oferta'
              : 'Tu oferta venció',
          style: MicanTexto.titulo1,
          textAlign: TextAlign.center,
        ),
        Text(
          vigente
              ? 'Te avisaremos apenas acepte. Mientras tanto puedes ver otras solicitudes.'
              : 'No te preocupes: no se cobró nada. Hay más solicitudes cerca de ti.',
          style: MicanTexto.cuerpo.copyWith(color: MicanColores.textoSecundario),
          textAlign: TextAlign.center,
        ),
        if (oferta != null)
          ResumenSolicitud(
            titulo: 'Tu oferta: ${solesCortos(oferta.precio)}',
            subtitulo: '${s.tipo.nombre} de ${duracion(s.duracionMin)} · ${s.mascota.nombre}',
          ),
        if (oferta != null)
          Tarjeta(
            child: Column(
              children: [
                FilaResumen('Precio', soles(oferta.precio)),
                const SizedBox(height: 10),
                FilaResumen('Comisión Mican (12%)', soles(-comision(oferta.precio)), colorValor: MicanColores.error),
                const SizedBox(height: 10),
                FilaResumen(
                  'Recibirías',
                  soles(oferta.precio - comision(oferta.precio)),
                  colorValor: MicanColores.exito,
                  fuerte: true,
                ),
              ],
            ),
          ),
        const NotaConIcono(
          icono: MicanIcono.candado,
          texto: 'Verás la dirección exacta y el celular del dueño cuando acepte tu oferta.',
        ),
      ],
    );
  }
}
