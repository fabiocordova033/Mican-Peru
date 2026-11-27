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
import 'fotos.dart';

/// Pantalla 18 · Servicio finalizado (dueño) y su equivalente del cuidador.
class PantallaFinalizado extends ConsumerWidget {
  const PantallaFinalizado({super.key, required this.servicio, required this.soyDueno});

  final Servicio servicio;
  final bool soyDueno;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = servicio;
    final r = s.resumen;
    final fotos = ref.watch(fotosServicioProvider(s.id)).value ?? const <FotoServicio>[];
    final yaCalifique = ref.watch(miCalificacionProvider(s.id)).value ?? false;
    final contacto = ref.watch(contactoProvider(s.id)).value;
    final cuidador = (s.cuidadorNombre ?? 'Tu cuidador').split(' ').first;
    final verbo = switch (s.tipo) {
      TipoServicio.paseo => 'el paseo',
      TipoServicio.visita => 'la visita',
      TipoServicio.transporte => 'el transporte',
    };
    final telCuidador = contacto?['telefonoCuidador'] as String?;
    final telOculto = telCuidador == null || telCuidador.length < 12
        ? null
        : '${telCuidador.substring(3, 6)} *** ${telCuidador.substring(telCuidador.length - 3)}';
    final puedeCalificar = s.puedeCalificar && !yaCalifique;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
          children: [
            Center(
              child: Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: MicanColores.exitoSuave, shape: BoxShape.circle),
                child: const Icono(MicanIcono.verificado, tamano: 48, color: MicanColores.exito),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              soyDueno ? '¡${s.mascota.nombre} ya está en casa!' : '¡Servicio completado!',
              style: MicanTexto.titulo1,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              soyDueno
                  ? '$cuidador finalizó $verbo a las ${hora(s.finalizadoEn)}'
                  : 'Terminaste $verbo con ${s.mascota.nombre} a las ${hora(s.finalizadoEn)}',
              style: MicanTexto.cuerpo.copyWith(color: MicanColores.textoSecundario),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Tarjeta(
              child: Column(
                children: [
                  FilaResumen('Servicio', '${s.tipo.nombre} · ${duracion(s.duracionMin)}'),
                  const SizedBox(height: 10),
                  FilaResumen('Duración real', '${r?.duracionRealMin ?? 0} min'),
                  if (s.tipo != TipoServicio.visita) ...[
                    const SizedBox(height: 10),
                    FilaResumen('Distancia', '${(r?.distanciaKm ?? 0).toStringAsFixed(1)} km'),
                  ],
                  const SizedBox(height: 10),
                  FilaResumen('Fotos', '${r?.fotos ?? fotos.length} fotos'),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: MicanColores.bordeSuave),
                  const SizedBox(height: 10),
                  if (soyDueno)
                    Row(
                      children: [
                        Expanded(child: Text('Total a pagar', style: MicanTexto.subtitulo)),
                        Text(soles(s.precio), style: MicanTexto.titulo2.copyWith(color: MicanColores.primario)),
                      ],
                    )
                  else ...[
                    FilaResumen('Precio cobrado', soles(s.precio)),
                    const SizedBox(height: 10),
                    FilaResumen(
                      'Comisión Mican (12%)',
                      soles(-(r?.comision ?? comision(s.precio))),
                      colorValor: MicanColores.error,
                    ),
                    const SizedBox(height: 10),
                    FilaResumen(
                      'Recibes',
                      soles(r?.recibeCuidador ?? s.precio - comision(s.precio)),
                      colorValor: MicanColores.exito,
                      fuerte: true,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: MicanColores.acentoSuave, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Icono(MicanIcono.billetera, tamano: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          soyDueno
                              ? 'Paga a $cuidador con ${metodoPago(s.metodoPago)}'
                              : 'Cobra a ${s.duenoNombre.split(' ').first} con ${metodoPago(s.metodoPago)}',
                          style: MicanTexto.cuerpoFuerte,
                        ),
                        Text(
                          soyDueno
                              ? (telOculto != null && s.metodoPago != 'efectivo'
                                    ? '${metodoPago(s.metodoPago)} a $telOculto'
                                    : 'Págale directamente al cuidador')
                              : 'La comisión ya se descontó de tu saldo',
                          style: MicanTexto.leyenda,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (fotos.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: fotos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => verFotos(context, s.id),
                    child: MiniaturaFoto(ruta: fotos[i].ruta),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: BarraAccion(
        children: [
          if (soyDueno) ...[
            Boton(
              'Reportar',
              tipo: TipoBoton.contorno,
              expandido: false,
              alPresionar: () => context.push('/reclamo?servicio=${s.id}'),
            ),
          ],
          Expanded(
            child: puedeCalificar
                ? Boton(
                    soyDueno ? 'Ya pagué, calificar' : 'Calificar al dueño',
                    alPresionar: () => context.push('/servicio/${s.id}/calificar'),
                  )
                : Boton('Volver al inicio', alPresionar: () => context.go('/app')),
          ),
        ],
      ),
    );
  }
}
