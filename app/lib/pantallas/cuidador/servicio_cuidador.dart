import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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
import '../servicio/emergencia.dart';
import '../servicio/fotos.dart';
import '../servicio/seguimiento.dart' show PildoraMapa, transcurrido;
import '../servicio/servicio.dart';

/// Servicio confirmado o en curso, visto por el cuidador. Mientras está en
/// curso registra la ruta en `servicios/{id}/ruta` (HU-16) y permite enviar
/// fotos (HU-17) y finalizar.
class ServicioCuidador extends ConsumerStatefulWidget {
  const ServicioCuidador({super.key, required this.servicio});

  final Servicio servicio;

  @override
  ConsumerState<ServicioCuidador> createState() => _ServicioCuidadorState();
}

class _ServicioCuidadorState extends ConsumerState<ServicioCuidador> {
  StreamSubscription<Lugar>? _gps;
  bool _iniciando = false;
  bool _finalizando = false;
  bool _subiendo = false;

  Servicio get s => widget.servicio;
  bool get _enCurso => s.estado == EstadoServicio.enCurso;

  @override
  void initState() {
    super.initState();
    _sincronizarGps();
  }

  @override
  void didUpdateWidget(ServicioCuidador anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.servicio.estado != s.estado) _sincronizarGps();
  }

  @override
  void dispose() {
    _gps?.cancel();
    super.dispose();
  }

  /// La visita a domicilio no registra ruta: solo paseo y transporte.
  void _sincronizarGps() {
    final registrar = _enCurso && s.tipo != TipoServicio.visita;
    if (registrar && _gps == null) {
      final col = ref.read(firestoreProvider).collection('servicios/${s.id}/ruta');
      _gps = ref.read(ubicacionProvider).seguir().listen((p) {
        col.add({'lat': p.lat, 'lng': p.lng, 'registradoEn': FieldValue.serverTimestamp()}).ignore();
      }, onError: (_) {});
    } else if (!registrar) {
      _gps?.cancel();
      _gps = null;
    }
  }

  Future<void> _iniciar() async {
    setState(() => _iniciando = true);
    final ubicacion = ref.read(ubicacionProvider);
    if (!await ubicacion.tienePermiso()) await ubicacion.pedirPermiso();
    final u = await ubicacion.actual();
    if (!mounted) return;
    if (u == null) {
      setState(() => _iniciando = false);
      return avisar(context, 'Activa tu ubicación para iniciar el servicio.');
    }
    await intentar(context, () => ref.read(apiProvider).iniciarServicio(s.id, u.lat, u.lng));
    if (mounted) setState(() => _iniciando = false);
  }

  Future<void> _foto() async {
    final camara = await mostrarHoja<bool>(
      context,
      builder: (c) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Enviar foto de ${s.mascota.nombre}', style: MicanTexto.titulo2),
          const SizedBox(height: 14),
          Boton('Tomar foto', icono: MicanIcono.camara, alPresionar: () => Navigator.pop(c, true)),
          const SizedBox(height: 10),
          Boton('Elegir de la galería', tipo: TipoBoton.contorno, alPresionar: () => Navigator.pop(c, false)),
        ],
      ),
    );
    if (camara == null || !mounted) return;
    setState(() => _subiendo = true);
    final ok = await intentar(context, () async {
      final r = await ref.read(archivosProvider).fotoServicio(s.id, camara: camara);
      if (r != null && mounted) avisar(context, 'Foto enviada a ${s.duenoNombre.split(' ').first}.');
    });
    if (!ok && mounted) avisar(context, 'No pudimos subir la foto. Revisa tu conexión.');
    if (mounted) setState(() => _subiendo = false);
  }

  Future<void> _finalizar() async {
    final fotos = ref.read(fotosServicioProvider(s.id)).value ?? const [];
    if (s.tipo == TipoServicio.visita && fotos.isEmpty) {
      return avisar(context, 'Envía al menos 1 foto antes de finalizar la visita.');
    }
    final ok = await confirmar(
      context,
      titulo: '¿Finalizar el servicio?',
      texto: 'Confirma que ${s.mascota.nombre} ya está de vuelta y en buenas manos.',
      si: 'Sí, finalizar',
      no: 'Todavía no',
    );
    if (!ok || !mounted) return;
    setState(() => _finalizando = true);
    await intentar(context, () => ref.read(apiProvider).finalizarServicio(s.id));
    if (mounted) setState(() => _finalizando = false);
  }

  Future<void> _cancelar() async {
    final ok = await confirmar(
      context,
      titulo: '¿Cancelar este servicio?',
      texto: 'El dueño tendrá que buscar otro cuidador. Las cancelaciones frecuentes afectan tu nivel.',
      si: 'Sí, cancelar',
      no: 'No, mantener',
      peligro: true,
    );
    if (ok && mounted) {
      await intentar(context, () => ref.read(apiProvider).cancelarServicio(s.id, 'Cancelado por el cuidador'));
    }
  }

  void _abrirMapa() {
    final o = s.origen;
    launchUrl(
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${o.lat},${o.lng}'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ahora = ref.watch(relojProvider).value ?? DateTime.now();
    final ruta = ref.watch(rutaProvider(s.id)).value ?? const <Lugar>[];
    final fotos = ref.watch(fotosServicioProvider(s.id)).value ?? const <FotoServicio>[];
    final contacto = ref.watch(contactoProvider(s.id)).value;
    final telDueno = contacto?['telefonoDueno'] as String?;
    final (min, reloj) = transcurrido(s, ahora);
    final km = distanciaRutaKm(ruta);
    final dueno = s.duenoNombre.split(' ').first;
    final conMapa = s.tipo != TipoServicio.visita;

    final pildora = !_enCurso
        ? PildoraMapa(texto: 'Ve al punto de recojo', punto: MicanColores.acento)
        : PildoraMapa(texto: '${s.tipo.nombre} en curso · $reloj', punto: MicanColores.exito);

    final panel = <Widget>[
      if (_enCurso)
        Row(
          children: [
            Expanded(
              child: CajaDato(valor: reloj, etiqueta: 'de ${duracion(s.duracionMin)}'),
            ),
            const SizedBox(width: 10),
            if (conMapa) ...[
              Expanded(
                child: CajaDato(valor: '${km.toStringAsFixed(1)} km', etiqueta: 'recorridos'),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: CajaDato(valor: '${fotos.length}', etiqueta: 'fotos enviadas'),
            ),
          ],
        )
      else
        ResumenSolicitud(
          titulo: '${s.tipo.nombre} de ${duracion(s.duracionMin)} · ${solesCortos(s.precio)}',
          subtitulo: '${metodoPago(s.metodoPago)} · recibes ${solesCortos(s.precio - comision(s.precio))}',
        ),
      _TarjetaMascota(servicio: s),
      Tarjeta(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            FilaLista(
              icono: MicanIcono.ubicacion,
              titulo: s.origen.direccion.isEmpty ? 'Punto de recojo' : s.origen.direccion,
              subtitulo: s.destino != null && s.destino!.direccion.isNotEmpty
                  ? 'Destino: ${s.destino!.direccion}'
                  : 'Recojo',
              relleno: EdgeInsets.zero,
              final_: _enCurso ? null : const Icono(MicanIcono.chevron, tamano: 20),
              alPresionar: _abrirMapa,
            ),
            const SizedBox(height: 10),
            FilaLista(
              icono: MicanIcono.cuenta,
              titulo: s.duenoNombre,
              subtitulo: telDueno == null ? 'Dueño' : 'Llamar · ${telefonoLegible(telDueno)}',
              relleno: EdgeInsets.zero,
              alPresionar: telDueno == null ? null : () => launchUrl(Uri(scheme: 'tel', path: telDueno)),
              final_: BotonCircular(icono: MicanIcono.mensajes, alPresionar: () => context.push('/chat/${s.id}')),
            ),
          ],
        ),
      ),
      if (_enCurso && fotos.isNotEmpty)
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: fotos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => verFotos(context, s.id),
              child: MiniaturaFoto(ruta: fotos[i].ruta, alto: 72),
            ),
          ),
        ),
      if (_enCurso) ...[
        Row(
          children: [
            Expanded(
              child: Boton(
                'Enviar foto',
                icono: MicanIcono.camara,
                tipo: TipoBoton.contorno,
                cargando: _subiendo,
                alPresionar: _foto,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Boton(
                'Emergencia',
                tipo: TipoBoton.peligro,
                alPresionar: () => mostrarEmergencia(context, ref, s, soyDueno: false),
              ),
            ),
          ],
        ),
        Boton('Finalizar servicio', cargando: _finalizando, alPresionar: _finalizar),
        if (s.tipo == TipoServicio.visita && fotos.isEmpty)
          const NotaConIcono(icono: MicanIcono.camara, texto: 'En visitas, envía al menos 1 foto antes de finalizar.'),
      ] else ...[
        Boton('Llegué, iniciar servicio', cargando: _iniciando, alPresionar: _iniciar),
        Row(
          children: [
            Expanded(
              child: Boton('Cancelar', tipo: TipoBoton.fantasma, alPresionar: _cancelar),
            ),
            Expanded(
              child: Boton(
                'Emergencia',
                tipo: TipoBoton.fantasma,
                alPresionar: () => mostrarEmergencia(context, ref, s, soyDueno: false),
              ),
            ),
          ],
        ),
        const NotaConIcono(
          icono: MicanIcono.ubicacion,
          texto: 'Podrás iniciar cuando estés a menos de 100 m del punto de recojo.',
        ),
      ],
    ];

    if (!conMapa) {
      return PantallaMican(
        titulo: 'Visita a ${s.mascota.nombre}',
        alVolver: () => context.go('/app'),
        children: [
          if (_enCurso)
            Tarjeta(
              color: MicanColores.primario,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Visita en curso · $min de ${s.duracionMin} min',
                    style: MicanTexto.cuerpoFuerte.copyWith(color: Colors.white),
                  ),
                  Text(
                    'Llegaste a las ${hora(s.iniciadoEn)}',
                    style: MicanTexto.leyenda.copyWith(color: MicanColores.primarioSuave),
                  ),
                  const SizedBox(height: 12),
                  BarraProgreso(valor: min / s.duracionMin, fondo: MicanColores.primarioOscuro, alto: 8),
                ],
              ),
            ),
          ...panel,
        ],
      );
    }

    final posicion = ruta.isNotEmpty ? ruta.last : null;
    return Scaffold(
      body: Stack(
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.5,
            child: MapaMican(
              centro: PuntoMapa(s.origen.lat, s.origen.lng),
              ruta: [for (final p in ruta) PuntoMapa(p.lat, p.lng)],
              marcadores: [
                MarcadorMapa(PuntoMapa(s.origen.lat, s.origen.lng), TipoMarcador.mascota),
                if (s.destino != null) MarcadorMapa(PuntoMapa(s.destino!.lat, s.destino!.lng), TipoMarcador.destino),
                if (posicion != null) MarcadorMapa(PuntoMapa(posicion.lat, posicion.lng), TipoMarcador.cuidador),
              ],
              colorRuta: s.tipo == TipoServicio.transporte ? MicanColores.primario : MicanColores.acento,
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
          DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.45,
            maxChildSize: 0.92,
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
                  const SizedBox(height: 12),
                  Text(
                    _enCurso ? 'Con ${s.mascota.nombre} · $dueno te sigue en vivo' : 'Recoge a ${s.mascota.nombre}',
                    style: MicanTexto.titulo2,
                  ),
                  for (final w in panel) ...[const SizedBox(height: 14), w],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Datos de la mascota que el cuidador necesita: alertas, temperamento e indicaciones.
class _TarjetaMascota extends StatelessWidget {
  const _TarjetaMascota({required this.servicio});

  final Servicio servicio;

  @override
  Widget build(BuildContext context) {
    final m = servicio.mascota;
    final indicaciones = [m.notas, servicio.indicaciones].where((t) => t.trim().isNotEmpty).join('\n');
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(nombre: m.nombre, emoji: m.emoji, fotoUrl: m.fotoUrl, tamano: 44, fondo: MicanColores.acentoSuave),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.nombre, style: MicanTexto.cuerpoFuerte),
                    Text(
                      [
                        m.raza,
                        tamano(m.tamano),
                        if (m.edadAnios != null) edad(m.edadAnios),
                      ].where((t) => t.isNotEmpty).join(' · '),
                      style: MicanTexto.leyenda,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (m.alertas.isNotEmpty || m.temperamento.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final a in m.alertas)
                  Pildora(texto: a, fondo: MicanColores.acentoSuave, color: MicanColores.acento, compacta: true),
                for (final t in m.temperamento)
                  Pildora(texto: t, fondo: MicanColores.primarioSuave, color: MicanColores.primario, compacta: true),
              ],
            ),
          ],
          if (indicaciones.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Indicaciones', style: MicanTexto.etiqueta),
            const SizedBox(height: 2),
            Text(indicaciones, style: MicanTexto.cuerpo),
          ],
        ],
      ),
    );
  }
}
