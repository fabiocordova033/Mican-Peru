import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../componentes/base.dart';
import '../../componentes/mapa.dart';
import '../../componentes/tarjetas.dart';
import '../../datos/modelos.dart';
import '../../datos/proveedores.dart';
import '../../tema/colores.dart';
import '../../tema/iconos.dart';
import '../../tema/tipografia.dart';
import '../../util/formato.dart';

final ubicacionActualProvider = FutureProvider<Lugar?>((ref) => ref.watch(ubicacionProvider).actual());

/// Pantalla 02 · Inicio (dueño).
class InicioDueno extends ConsumerWidget {
  const InicioDueno({super.key});

  static const servicios = [
    (TipoServicio.paseo, MicanIcono.ruta, 'Perros · ruta en vivo'),
    (TipoServicio.visita, MicanIcono.casaVisita, 'Perros y gatos'),
    (TipoServicio.transporte, MicanIcono.auto, 'Al veterinario o groomer'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(usuarioProvider).value;
    final ubicacion = ref.watch(ubicacionActualProvider).value;
    final activos = (ref.watch(serviciosDuenoProvider).value ?? const <Servicio>[])
        .where((s) => s.estado.activo)
        .toList();
    final anuncios = ref.watch(anunciosProvider).value ?? const <Anuncio>[];
    final premium = usuario?.esPremium ?? false;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            bottom: null,
            child: SizedBox(
              height: 460,
              child: MapaMican(centro: ubicacion == null ? null : PuntoMapa(ubicacion.lat, ubicacion.lng)),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 9, 16, 0),
              child: _Buscador(
                direccion: ubicacion == null ? 'Elige tu punto de recojo' : 'Tu ubicación actual',
                alPresionar: () => context.push('/solicitar?tipo=paseo'),
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.55,
            maxChildSize: 0.9,
            builder: (context, scroll) => Container(
              decoration: const BoxDecoration(
                color: MicanColores.fondoApp,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: MicanSombras.flotante,
              ),
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(color: MicanColores.bordeSuave, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Hola, ${usuario?.primerNombre ?? ''} 👋', style: MicanTexto.leyenda),
                  const SizedBox(height: 2),
                  Text('¿Qué necesita tu mascota hoy?', style: MicanTexto.titulo2),
                  for (final s in activos) ...[const SizedBox(height: 16), _ServicioActivo(servicio: s)],
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    child: Row(
                      children: [
                        for (final (tipo, icono, sub) in servicios) ...[
                          TarjetaServicio(
                            icono: icono,
                            titulo: tipo.nombre,
                            subtitulo: sub,
                            seleccionado: tipo == TipoServicio.paseo,
                            alPresionar: () => context.push('/solicitar?tipo=${tipo.name}'),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ],
                    ),
                  ),
                  if (!premium) ...[
                    const SizedBox(height: 16),
                    if (anuncios.isEmpty)
                      BannerPatrocinado(
                        titulo: 'Prueba Mican Premium',
                        vigencia: '7 días gratis · sin anuncios',
                        alPresionar: () => context.push('/premium'),
                      )
                    else
                      for (final a in anuncios.take(1))
                        BannerPatrocinado(
                          titulo: a.titulo,
                          vigencia: a.vigencia,
                          alPresionar: a.url == null ? null : () => launchUrl(Uri.parse(a.url!)),
                        ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Buscador extends StatelessWidget {
  const _Buscador({required this.direccion, required this.alPresionar});

  final String direccion;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MicanColores.superficieTarjeta,
      shape: const StadiumBorder(),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: alPresionar,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const ShapeDecoration(shape: StadiumBorder(), shadows: MicanSombras.tarjeta),
          child: Row(
            children: [
              const Icono(MicanIcono.ubicacion, tamano: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(direccion, style: MicanTexto.cuerpo, overflow: TextOverflow.ellipsis),
              ),
              const Icono(MicanIcono.campana, tamano: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServicioActivo extends StatelessWidget {
  const _ServicioActivo({required this.servicio});

  final Servicio servicio;

  @override
  Widget build(BuildContext context) {
    final s = servicio;
    final (texto, color) = switch (s.estado) {
      EstadoServicio.buscando => ('Buscando cuidador · ${s.ofertasRecibidas} ofertas', MicanColores.acento),
      EstadoServicio.confirmado => ('${s.cuidadorNombre ?? 'Tu cuidador'} va en camino', MicanColores.primario),
      _ => ('En curso · ${solesCortos(s.precio)}', MicanColores.exito),
    };
    return Tarjeta(
      padding: const EdgeInsets.all(14),
      borde: BorderSide(color: color, width: 2),
      alPresionar: () => context.push('/servicio/${s.id}'),
      child: Row(
        children: [
          CajaIcono(iconoServicio(s.tipo), tamano: 44, tamanoIcono: 22, fondo: color.withValues(alpha: 0.15)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${s.tipo.nombre} de ${s.mascota.nombre}', style: MicanTexto.cuerpoFuerte),
                Text(texto, style: MicanTexto.leyenda.copyWith(color: color)),
              ],
            ),
          ),
          const Icono(MicanIcono.chevron, tamano: 20),
        ],
      ),
    );
  }
}

MicanIcono iconoServicio(TipoServicio t) => switch (t) {
  TipoServicio.paseo => MicanIcono.ruta,
  TipoServicio.visita => MicanIcono.casaVisita,
  TipoServicio.transporte => MicanIcono.auto,
};
