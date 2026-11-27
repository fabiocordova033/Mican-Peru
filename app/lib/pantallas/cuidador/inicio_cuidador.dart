import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../componentes/base.dart';
import '../../componentes/tarjetas.dart';
import '../../datos/api.dart';
import '../../datos/modelos.dart';
import '../../datos/proveedores.dart';
import '../../datos/ubicacion.dart';
import '../../tema/colores.dart';
import '../../tema/iconos.dart';
import '../../tema/tipografia.dart';
import '../../util/formato.dart';
import '../../util/ui.dart';
import '../dueno/inicio_dueno.dart' show iconoServicio;

/// Pantalla 14 · Inicio (cuidador): disponibilidad, saldo, nivel y
/// solicitudes cercanas. La lista se refresca cada 15 s mientras está visible.
class InicioCuidador extends ConsumerStatefulWidget {
  const InicioCuidador({super.key});

  @override
  ConsumerState<InicioCuidador> createState() => _InicioCuidadorState();
}

class _InicioCuidadorState extends ConsumerState<InicioCuidador> {
  SolicitudesCercanas? _datos;
  Object? _error;
  Lugar? _ubicacion;
  Timer? _timer;
  TipoServicio? _filtro;
  String? _aceptando;
  bool _cambiando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _cargar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    final perfil = ref.read(miPerfilProvider).value;
    if (perfil != null && !perfil.verificado) return;
    try {
      final u = await ref.read(ubicacionProvider).actual() ?? ServicioUbicacion.porDefecto;
      final r = await ref.read(apiProvider).listarSolicitudesCercanas(u.lat, u.lng);
      if (!mounted) return;
      setState(() {
        _ubicacion = u;
        _datos = r;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _cambiarDisponibilidad(bool v) async {
    setState(() => _cambiando = true);
    await intentar(context, () => ref.read(apiProvider).cambiarDisponibilidad(v));
    if (!mounted) return;
    setState(() => _cambiando = false);
    await _cargar();
  }

  Future<void> _aceptar(SolicitudCercana s) async {
    final u = _ubicacion ?? await ref.read(ubicacionProvider).actual();
    if (u == null) {
      if (mounted) avisar(context, 'Activa tu ubicación para aceptar solicitudes.');
      return;
    }
    if (!mounted) return;
    setState(() => _aceptando = s.id);
    final api = ref.read(apiProvider);
    final ok = await intentar(context, () async {
      if (s.esPaquete) {
        await api.tomarPaquete(s.id, u.lat, u.lng);
      } else {
        await api.enviarOferta(servicioId: s.id, precio: s.precioOfrecido, lat: u.lat, lng: u.lng);
      }
    });
    if (!mounted) return;
    setState(() => _aceptando = null);
    if (ok) {
      context.push('/servicio/${s.id}');
    } else {
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(usuarioProvider).value;
    final perfil = ref.watch(miPerfilProvider).value;
    final saldo = ref.watch(saldoProvider).value ?? _datos?.saldo ?? 0;
    final servicios = ref.watch(serviciosCuidadorProvider).value ?? const <Servicio>[];
    final activos = servicios.where((s) => s.estado.activo).toList();
    final hoy = DateTime.now();
    final gananciaHoy = servicios
        .where(
          (s) =>
              s.estado == EstadoServicio.completado &&
              s.finalizadoEn != null &&
              DateUtils.isSameDay(s.finalizadoEn, hoy),
        )
        .fold<int>(0, (t, s) => t + (s.resumen?.recibeCuidador ?? s.precio - comision(s.precio)));
    final disponible = perfil?.disponible ?? false;
    final verificado = perfil?.verificado ?? false;
    final solicitudes = (_datos?.solicitudes ?? const <SolicitudCercana>[])
        .where((s) => _filtro == null || s.tipo == _filtro)
        .toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _cargar,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hola, ${usuario?.primerNombre ?? ''} 👋', style: MicanTexto.leyenda),
                        Text(disponible ? 'Estás disponible' : 'No estás disponible', style: MicanTexto.titulo2),
                      ],
                    ),
                  ),
                  if (_cambiando)
                    const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    Interruptor(activo: disponible, alCambiar: verificado ? _cambiarDisponibilidad : null),
                ],
              ),
              const SizedBox(height: 16),
              if (!verificado) ...[_AvisoVerificacion(), const SizedBox(height: 16)],
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.push('/billetera'),
                      child: CajaDato(icono: MicanIcono.billetera, valor: solesCortos(saldo), etiqueta: 'Saldo'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CajaDato(
                      icono: MicanIcono.calendario,
                      valor: solesCortos(gananciaHoy),
                      etiqueta: 'Ganado hoy',
                      colorValor: MicanColores.exito,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CajaDato(
                      icono: MicanIcono.estrella,
                      valor: InsigniaNivel.nombre(perfil?.nivel ?? 'nuevo').split(' ').first,
                      etiqueta: 'Nivel',
                      colorValor: MicanColores.acento,
                    ),
                  ),
                ],
              ),
              if (_datos?.recargar == true) ...[
                const SizedBox(height: 16),
                Tarjeta(
                  color: MicanColores.acentoSuave,
                  sombra: false,
                  alPresionar: () => context.push('/recargar'),
                  child: Row(
                    children: [
                      const Icono(MicanIcono.billetera, tamano: 22, color: MicanColores.acento),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Recarga para ver solicitudes', style: MicanTexto.cuerpoFuerte),
                            Text(
                              'Necesitas al menos S/ 10 de saldo para cubrir la comisión.',
                              style: MicanTexto.leyenda,
                            ),
                          ],
                        ),
                      ),
                      const Icono(MicanIcono.chevron, tamano: 20),
                    ],
                  ),
                ),
              ],
              for (final s in activos) ...[const SizedBox(height: 16), _ServicioAsignado(servicio: s)],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Text('Solicitudes cerca de ti', style: MicanTexto.subtitulo)),
                  Text('${solicitudes.length}', style: MicanTexto.etiqueta.copyWith(color: MicanColores.primario)),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChipEtiqueta(
                      'Todos',
                      seleccionado: _filtro == null,
                      alPresionar: () => setState(() => _filtro = null),
                    ),
                    for (final t in TipoServicio.values) ...[
                      const SizedBox(width: 8),
                      ChipEtiqueta(
                        t.nombre,
                        seleccionado: _filtro == t,
                        alPresionar: () => setState(() => _filtro = t),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (!verificado)
                const Vacio(
                  icono: MicanIcono.escudo,
                  titulo: 'Verifícate para recibir solicitudes',
                  texto: 'Revisamos tus documentos en menos de 48 horas.',
                )
              else if (!disponible)
                const Vacio(
                  icono: MicanIcono.huella,
                  titulo: 'Activa tu disponibilidad',
                  texto: 'Te mostraremos solicitudes a menos de 3 km.',
                )
              else if (_datos == null && _error == null)
                const Cargando()
              else if (_error != null && _datos == null)
                Vacio(icono: MicanIcono.ubicacion, titulo: 'No pudimos cargar', texto: mensajeDeError(_error!))
              else if (solicitudes.isEmpty)
                const Vacio(
                  icono: MicanIcono.huella,
                  titulo: 'Por ahora no hay solicitudes',
                  texto: 'Te avisaremos cuando llegue una cerca.',
                )
              else
                for (final s in solicitudes) ...[
                  TarjetaSolicitud(
                    icono: iconoServicio(s.tipo),
                    titulo: '${s.tipo.nombre} · ${duracion(s.duracionMin)}',
                    subtitulo: [
                      '${s.distanciaKm.toStringAsFixed(1)} km',
                      '${s.minutosLlegada} min',
                      if (s.destino != null && s.destino!.isNotEmpty) s.destino!,
                      if (s.esPaquete) 'Paquete fijo',
                    ].join(' · '),
                    precio: solesCortos(s.precioOfrecido),
                    metodoPago: metodoPago(s.metodoPago),
                    mascota: '${s.mascota.nombre} · ${s.mascota.raza}',
                    emojiMascota: s.mascota.emoji,
                    alertas: s.mascota.alertas,
                    esPaquete: s.esPaquete,
                    aceptando: _aceptando == s.id,
                    alAceptar: _aceptando == null ? () => _aceptar(s) : null,
                    alContraofertar: () => context.push('/contraoferta', extra: s),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AvisoVerificacion extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(verificacionProvider).value;
    final (titulo, texto) = switch (v?.estado) {
      'en_revision' => ('Documentos en revisión', 'Te avisaremos en menos de 48 horas.'),
      'rechazada' => ('Revisa tus documentos', v?.motivoRechazo ?? 'Vuelve a subir los documentos observados.'),
      'revocada' => ('Verificación suspendida', 'Escríbenos a soporte para revisar tu caso.'),
      _ => ('Completa tu verificación', 'Sube tu DNI, antecedentes y una selfie.'),
    };
    return Tarjeta(
      color: MicanColores.primarioSuave,
      sombra: false,
      alPresionar: () => context.push('/verificacion'),
      child: Row(
        children: [
          const Icono(MicanIcono.escudo, tamano: 22, color: MicanColores.primario),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: MicanTexto.cuerpoFuerte.copyWith(color: MicanColores.primarioOscuro)),
                Text(texto, style: MicanTexto.leyenda.copyWith(color: MicanColores.primario)),
              ],
            ),
          ),
          const Icono(MicanIcono.chevron, tamano: 20, color: MicanColores.primario),
        ],
      ),
    );
  }
}

class _ServicioAsignado extends StatelessWidget {
  const _ServicioAsignado({required this.servicio});

  final Servicio servicio;

  @override
  Widget build(BuildContext context) {
    final s = servicio;
    final enCurso = s.estado == EstadoServicio.enCurso;
    return Tarjeta(
      color: MicanColores.primario,
      alPresionar: () => context.push('/servicio/${s.id}'),
      child: Row(
        children: [
          CajaIcono(iconoServicio(s.tipo), fondo: MicanColores.primarioOscuro, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enCurso ? '${s.tipo.nombre} en curso' : '${s.tipo.nombre} confirmado',
                  style: MicanTexto.cuerpoFuerte.copyWith(color: Colors.white),
                ),
                Text(
                  '${s.mascota.nombre} · ${s.origen.direccion.isEmpty ? duracion(s.duracionMin) : s.origen.direccion}',
                  style: MicanTexto.leyenda.copyWith(color: MicanColores.primarioSuave),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(solesCortos(s.precio), style: MicanTexto.titulo2.copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}
