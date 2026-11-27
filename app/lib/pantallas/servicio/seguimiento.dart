import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../componentes/base.dart';
import '../../componentes/estructura.dart';
import '../../componentes/mapa.dart';
import '../../componentes/tarjetas.dart';
import '../../datos/modelos.dart';
import '../../datos/proveedores.dart';
import '../../tema/colores.dart';
import '../../tema/iconos.dart';
import '../../tema/tipografia.dart';
import '../../util/formato.dart';
import '../../util/geo.dart';
import '../../util/ui.dart';
import 'emergencia.dart';
import 'fotos.dart';
import 'servicio.dart';

/// Lo que ve el dueño con el servicio confirmado o en curso:
/// 06 · Paseo en vivo, 21 · Visita a domicilio en curso, 22 · Transporte en curso.
class SeguimientoDueno extends ConsumerWidget {
  const SeguimientoDueno({super.key, required this.servicio});

  final Servicio servicio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (servicio.tipo) {
      TipoServicio.visita => _VisitaEnCurso(servicio: servicio),
      _ => _ConMapa(servicio: servicio),
    };
  }
}

/// Minutos transcurridos y texto "32:10" desde que inició.
(int, String) transcurrido(Servicio s, DateTime ahora) {
  if (s.iniciadoEn == null) return (0, '0:00');
  final d = ahora.difference(s.iniciadoEn!);
  return (d.inMinutes, '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}');
}

Future<void> _cancelarConfirmado(BuildContext context, WidgetRef ref, Servicio s) async {
  final ok = await confirmar(
    context,
    titulo: '¿Cancelar el servicio?',
    texto: '${s.cuidadorNombre ?? 'El cuidador'} ya aceptó y puede estar en camino.',
    si: 'Sí, cancelar',
    no: 'No, mantener',
    peligro: true,
  );
  if (ok && context.mounted) {
    await intentar(context, () => ref.read(apiProvider).cancelarServicio(s.id, 'Cancelado por el dueño'));
  }
}

class _TarjetaCuidador extends ConsumerWidget {
  const _TarjetaCuidador({required this.servicio, required this.titulo});

  final Servicio servicio;
  final String titulo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(perfilProvider(servicio.cuidadorId!)).value;
    return GestureDetector(
      onTap: () => context.push('/cuidador/${servicio.cuidadorId}'),
      child: TarjetaCuidadorEnCurso(
        titulo: titulo,
        nombre: servicio.cuidadorNombre ?? p?.nombre ?? '',
        fotoUrl: p?.fotoUrl,
        nota: p?.calificacionPromedio ?? 0,
        resenas: p?.numResenas ?? 0,
        alChatear: () => context.push('/chat/${servicio.id}'),
      ),
    );
  }
}

class _Acciones extends ConsumerWidget {
  const _Acciones({required this.servicio});

  final Servicio servicio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final confirmado = servicio.estado == EstadoServicio.confirmado;
    return Row(
      children: [
        Expanded(
          child: confirmado
              ? Boton(
                  'Cancelar',
                  tipo: TipoBoton.contorno,
                  alPresionar: () => _cancelarConfirmado(context, ref, servicio),
                )
              : Boton('Ver fotos', tipo: TipoBoton.contorno, alPresionar: () => verFotos(context, servicio.id)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Boton(
            'Emergencia',
            tipo: TipoBoton.peligro,
            alPresionar: () => mostrarEmergencia(context, ref, servicio, soyDueno: true),
          ),
        ),
      ],
    );
  }
}

class PildoraMapa extends StatelessWidget {
  const PildoraMapa({super.key, required this.texto, this.icono, this.punto});

  final String texto;
  final MicanIcono? icono;
  final Color? punto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const ShapeDecoration(
        color: MicanColores.superficieTarjeta,
        shape: StadiumBorder(),
        shadows: MicanSombras.tarjeta,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (punto != null)
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: punto, shape: BoxShape.circle),
            ),
          if (icono != null) Icono(icono!, tamano: 16),
          const SizedBox(width: 8),
          Text(texto, style: MicanTexto.etiqueta),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 06 · Paseo en vivo / 22 · Transporte en curso
// ---------------------------------------------------------------------------

class _ConMapa extends ConsumerWidget {
  const _ConMapa({required this.servicio});

  final Servicio servicio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = servicio;
    final ahora = ref.watch(relojProvider).value ?? DateTime.now();
    final ruta = ref.watch(rutaProvider(s.id)).value ?? const <Lugar>[];
    final fotos = ref.watch(fotosServicioProvider(s.id)).value ?? const [];
    final enCurso = s.estado == EstadoServicio.enCurso;
    final (min, reloj) = transcurrido(s, ahora);
    final km = distanciaRutaKm(ruta);
    final cuidador = (s.cuidadorNombre ?? 'Tu cuidador').split(' ').first;
    final transporte = s.tipo == TipoServicio.transporte;

    final pildora = !enCurso
        ? PildoraMapa(texto: '$cuidador va en camino al recojo', punto: MicanColores.acento)
        : transporte
        ? PildoraMapa(texto: 'En camino · ${km.toStringAsFixed(1)} km', icono: MicanIcono.reloj)
        : PildoraMapa(texto: '${s.tipo.nombre} en curso · $reloj', punto: MicanColores.exito);

    final marcadores = [
      MarcadorMapa(PuntoMapa(s.origen.lat, s.origen.lng), TipoMarcador.mascota),
      if (ruta.isNotEmpty) MarcadorMapa(PuntoMapa(ruta.last.lat, ruta.last.lng), TipoMarcador.cuidador),
    ];

    return Scaffold(
      body: Stack(
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.58,
            child: MapaMican(
              centro: PuntoMapa(s.origen.lat, s.origen.lng),
              ruta: [for (final p in ruta) PuntoMapa(p.lat, p.lng)],
              marcadores: marcadores,
              colorRuta: transporte ? MicanColores.primario : MicanColores.acento,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  BotonCircular(icono: MicanIcono.atras, alPresionar: () => context.go('/app')),
                  const SizedBox(width: 10),
                  Flexible(child: pildora),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              child: PanelInferior(
                children: [
                  if (transporte)
                    _Etapas(servicio: s, ahora: ahora)
                  else ...[
                    _TarjetaCuidador(
                      servicio: s,
                      titulo: enCurso
                          ? '$cuidador paseando a ${s.mascota.nombre}'
                          : '$cuidador va por ${s.mascota.nombre}',
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: CajaDato(
                            icono: MicanIcono.reloj,
                            valor: '$min min',
                            etiqueta: 'de ${s.duracionMin} min',
                            colorValor: MicanColores.textoPrincipal,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CajaDato(
                            icono: MicanIcono.ruta,
                            valor: '${km.toStringAsFixed(1)} km',
                            etiqueta: 'recorridos',
                            colorValor: MicanColores.textoPrincipal,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CajaDato(
                            icono: MicanIcono.camara,
                            valor: '${fotos.length}',
                            etiqueta: fotos.length == 1 ? 'foto' : 'fotos',
                            colorValor: MicanColores.textoPrincipal,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (transporte) _TarjetaCuidador(servicio: s, titulo: '$cuidador lleva a ${s.mascota.nombre}'),
                  _Acciones(servicio: s),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Línea de tiempo del transporte (22).
class _Etapas extends StatelessWidget {
  const _Etapas({required this.servicio, required this.ahora});

  final Servicio servicio;
  final DateTime ahora;

  @override
  Widget build(BuildContext context) {
    final s = servicio;
    final enCurso = s.estado == EstadoServicio.enCurso;
    final destino = s.destino?.direccion.isNotEmpty == true ? s.destino!.direccion : 'el destino';
    final regreso = s.iniciadoEn?.add(Duration(minutes: s.duracionMin));
    final etapas = [
      (enCurso ? 'Recogido en casa' : 'Recojo en casa', enCurso ? hora(s.iniciadoEn) : 'pronto', enCurso ? 2 : 1),
      ('En camino a $destino', enCurso ? 'ahora' : '', enCurso ? 1 : 0),
      ('Regreso a casa', regreso == null ? '' : '≈ ${hora(regreso)}', 0),
    ];
    return Tarjeta(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          for (var i = 0; i < etapas.length; i++)
            _Etapa(texto: etapas[i].$1, hora: etapas[i].$2, estado: etapas[i].$3, ultima: i == etapas.length - 1),
        ],
      ),
    );
  }
}

class _Etapa extends StatelessWidget {
  const _Etapa({required this.texto, required this.hora, required this.estado, required this.ultima});

  final String texto;
  final String hora;

  /// 2 = hecha, 1 = actual, 0 = pendiente.
  final int estado;
  final bool ultima;

  @override
  Widget build(BuildContext context) {
    final color = switch (estado) {
      2 => MicanColores.exito,
      1 => MicanColores.acento,
      _ => MicanColores.bordeSuave,
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 16,
            child: Column(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: estado == 0 ? Colors.white : color,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 3),
                  ),
                ),
                if (!ultima)
                  Expanded(
                    child: Container(width: 2, color: estado == 2 ? MicanColores.exito : MicanColores.bordeSuave),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: ultima ? 0 : 14),
              child: Text(
                texto,
                style: estado == 1
                    ? MicanTexto.cuerpoFuerte
                    : MicanTexto.cuerpo.copyWith(
                        color: estado == 0 ? MicanColores.textoSecundario : MicanColores.textoPrincipal,
                      ),
              ),
            ),
          ),
          Text(hora, style: MicanTexto.leyenda.copyWith(color: estado == 1 ? MicanColores.acento : null)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 21 · Visita a domicilio en curso
// ---------------------------------------------------------------------------

class _VisitaEnCurso extends ConsumerWidget {
  const _VisitaEnCurso({required this.servicio});

  final Servicio servicio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = servicio;
    final ahora = ref.watch(relojProvider).value ?? DateTime.now();
    final fotos = ref.watch(fotosServicioProvider(s.id)).value ?? const <FotoServicio>[];
    final enCurso = s.estado == EstadoServicio.enCurso;
    final (min, _) = transcurrido(s, ahora);
    final cuidador = (s.cuidadorNombre ?? 'Tu cuidador').split(' ').first;
    final tareas = s.indicaciones.split('\n').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

    return PantallaMican(
      titulo: 'Visita a ${s.mascota.nombre}',
      alVolver: () => context.go('/app'),
      children: [
        Tarjeta(
          color: MicanColores.primario,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icono(MicanIcono.casaVisita, tamano: 22, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          enCurso ? 'Visita en curso · $min de ${s.duracionMin} min' : '$cuidador va en camino',
                          style: MicanTexto.cuerpoFuerte.copyWith(color: Colors.white),
                        ),
                        Text(
                          enCurso
                              ? '$cuidador llegó a las ${hora(s.iniciadoEn)} · ${s.origen.direccion}'
                              : 'Visita de ${duracion(s.duracionMin)} · ${s.origen.direccion}',
                          style: MicanTexto.leyenda.copyWith(color: MicanColores.primarioSuave),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              BarraProgreso(valor: enCurso ? min / s.duracionMin : 0, fondo: MicanColores.primarioOscuro, alto: 8),
            ],
          ),
        ),
        Tarjeta(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tareas de la visita', style: MicanTexto.subtitulo),
              for (final t in tareas) ...[const SizedBox(height: 10), _Tarea(texto: t, hecha: false)],
              const SizedBox(height: 10),
              _Tarea(texto: 'Enviar al menos 1 foto', hecha: fotos.isNotEmpty),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Fotos de ${s.mascota.nombre}', style: MicanTexto.subtitulo)),
                if (fotos.isEmpty)
                  Text('Obligatoria antes de terminar', style: MicanTexto.leyenda.copyWith(color: MicanColores.acento)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: fotos.isEmpty
                  ? Text('Aún no hay fotos.', style: MicanTexto.leyenda)
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: fotos.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => MiniaturaFoto(ruta: fotos[i].ruta, alto: 72),
                    ),
            ),
          ],
        ),
        _TarjetaCuidador(servicio: s, titulo: '$cuidador está con ${s.mascota.nombre}'),
        _Acciones(servicio: s),
      ],
    );
  }
}

class _Tarea extends StatelessWidget {
  const _Tarea({required this.texto, required this.hecha});

  final String texto;
  final bool hecha;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Casilla(marcada: hecha, redonda: true, colorMarcada: MicanColores.exito),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: MicanTexto.cuerpo.copyWith(
              color: hecha ? MicanColores.textoSecundario : MicanColores.textoPrincipal,
            ),
          ),
        ),
      ],
    );
  }
}
