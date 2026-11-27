import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../componentes/base.dart';
import '../../componentes/estructura.dart';
import '../../datos/modelos.dart';
import '../../datos/proveedores.dart';
import '../../tema/colores.dart';
import '../../tema/iconos.dart';
import '../../tema/tipografia.dart';
import '../../componentes/tarjetas.dart';
import '../../util/formato.dart';
import '../cuidador/esperando_respuesta.dart';
import '../cuidador/servicio_cuidador.dart';
import 'finalizado.dart';
import 'ofertas.dart';
import 'seguimiento.dart';

/// Reloj de 1 s para contadores (ofertas de 60 s, tiempo en curso...).
final relojProvider = StreamProvider<DateTime>(
  (ref) => Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
);

/// `/servicio/:id`: muestra la pantalla que corresponde al estado del
/// servicio y a quién lo mira (dueño o cuidador). Se actualiza en vivo.
class PantallaServicio extends ConsumerWidget {
  const PantallaServicio({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(uidProvider);
    final async = ref.watch(servicioProvider(id));
    return async.when(
      loading: () => const Scaffold(body: Cargando()),
      error: (e, _) =>
          const _SinServicio(texto: 'Esta solicitud ya no está disponible. Quizá otro cuidador la tomó primero.'),
      data: (s) {
        if (s == null) return const _SinServicio(texto: 'No encontramos este servicio.');
        final soyDueno = s.duenoId == uid;
        if (!soyDueno && s.cuidadorId != uid) {
          // Cuidador que ofertó y aún espera (o la solicitud se asignó a otro).
          return s.estado == EstadoServicio.buscando
              ? EsperandoRespuesta(servicio: s)
              : const _SinServicio(texto: 'El dueño eligió otra oferta. ¡Sigue atento a nuevas solicitudes!');
        }
        return switch (s.estado) {
          EstadoServicio.buscando => soyDueno ? PantallaOfertas(servicio: s) : EsperandoRespuesta(servicio: s),
          EstadoServicio.confirmado ||
          EstadoServicio.enCurso => soyDueno ? SeguimientoDueno(servicio: s) : ServicioCuidador(servicio: s),
          EstadoServicio.completado => PantallaFinalizado(servicio: s, soyDueno: soyDueno),
          EstadoServicio.cancelado || EstadoServicio.expirado => _Cerrado(servicio: s, soyDueno: soyDueno),
        };
      },
    );
  }
}

class _SinServicio extends StatelessWidget {
  const _SinServicio({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return PantallaMican(
      titulo: 'Servicio',
      alVolver: () => context.go('/app'),
      children: [
        Vacio(icono: MicanIcono.huella, titulo: 'Nada por aquí', texto: texto),
        Boton('Volver al inicio', alPresionar: () => context.go('/app')),
      ],
    );
  }
}

class _Cerrado extends StatelessWidget {
  const _Cerrado({required this.servicio, required this.soyDueno});

  final Servicio servicio;
  final bool soyDueno;

  @override
  Widget build(BuildContext context) {
    final s = servicio;
    final expirado = s.estado == EstadoServicio.expirado;
    final porQuien = switch (s.canceladoPor) {
      'dueno' => soyDueno ? 'Cancelaste' : 'El dueño canceló',
      'cuidador' => soyDueno ? 'El cuidador canceló' : 'Cancelaste',
      _ => 'Se canceló',
    };
    return PantallaMican(
      titulo: '${s.tipo.nombre} · ${s.mascota.nombre}',
      alVolver: () => context.go('/app'),
      children: [
        Vacio(
          icono: expirado ? MicanIcono.reloj : MicanIcono.cerrar,
          titulo: expirado ? 'Nadie tomó la solicitud a tiempo' : '$porQuien este servicio',
          texto: expirado
              ? 'Pasaron 15 minutos sin cuidador. Prueba con un precio un poco mayor.'
              : 'No se cobró ninguna comisión.',
        ),
        Tarjeta(
          child: Column(
            children: [
              FilaResumen('Servicio', '${s.tipo.nombre} · ${duracion(s.duracionMin)}'),
              const SizedBox(height: 10),
              FilaResumen('Precio ofrecido', solesCortos(s.precioOfrecido)),
              const SizedBox(height: 10),
              FilaResumen('Fecha', fechaRelativa(s.creadoEn)),
            ],
          ),
        ),
        if (soyDueno && expirado)
          Boton('Volver a solicitar', alPresionar: () => context.pushReplacement('/solicitar?tipo=${s.tipo.name}')),
        Boton('Ir al inicio', tipo: TipoBoton.fantasma, alPresionar: () => context.go('/app')),
      ],
    );
  }
}

/// Encabezado reutilizable "Tu oferta: S/ 25 · Paseo de 1 h".
class ResumenSolicitud extends StatelessWidget {
  const ResumenSolicitud({super.key, required this.titulo, required this.subtitulo});

  final String titulo;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: MicanColores.primarioSuave, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icono(MicanIcono.ruta, tamano: 20, color: MicanColores.primarioOscuro),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: MicanTexto.cuerpoFuerte.copyWith(color: MicanColores.primarioOscuro)),
                Text(subtitulo, style: MicanTexto.leyenda.copyWith(color: MicanColores.primario)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
