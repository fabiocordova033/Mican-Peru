import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../componentes/base.dart';
import '../../componentes/estructura.dart';
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

/// Pantalla 03 · Solicitar servicio (HU-09, HU-10, HU-11, HU-23).
class PantallaSolicitar extends ConsumerStatefulWidget {
  const PantallaSolicitar({super.key, required this.tipo});

  final TipoServicio tipo;

  @override
  ConsumerState<PantallaSolicitar> createState() => _PantallaSolicitarState();
}

class _PantallaSolicitarState extends ConsumerState<PantallaSolicitar> {
  final _recojo = TextEditingController();
  final _destino = TextEditingController();
  final _indicaciones = TextEditingController();
  String? _mascotaId;
  Lugar? _origen;
  int _duracion = 60;
  bool _personalizada = false;
  bool _paquete = false;
  int? _precio;
  String _metodoPago = 'yape';
  Cotizacion? _cotizacion;
  bool _cotizando = false;
  bool _enviando = false;
  Timer? _espera;

  @override
  void initState() {
    super.initState();
    _ubicar();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _recojo.dispose();
    _destino.dispose();
    super.dispose();
  }

  Future<void> _ubicar() async {
    final actual = await ref.read(ubicacionProvider).actual();
    if (!mounted) return;
    setState(() {
      _origen = actual ?? ServicioUbicacion.porDefecto;
      if (_recojo.text.isEmpty && actual == null) _recojo.text = ServicioUbicacion.porDefecto.direccion;
    });
    _cotizar();
  }

  Lugar get _lugarOrigen {
    final base = _origen ?? ServicioUbicacion.porDefecto;
    return Lugar(lat: base.lat, lng: base.lng, direccion: _recojo.text.trim());
  }

  /// Sin geocodificación (pendiente de la API key de Maps), el destino usa
  /// las coordenadas del recojo y la dirección escrita.
  Lugar? get _lugarDestino => widget.tipo == TipoServicio.transporte
      ? Lugar(lat: _lugarOrigen.lat, lng: _lugarOrigen.lng, direccion: _destino.text.trim())
      : null;

  void _cotizar() {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 250), () async {
      setState(() => _cotizando = true);
      try {
        final c = await ref
            .read(apiProvider)
            .cotizar(tipo: widget.tipo, duracionMin: _duracion, origen: _lugarOrigen, destino: _lugarDestino);
        if (!mounted) return;
        setState(() {
          _cotizacion = c;
          // Precio inicial: el medio del rango sugerido, en soles enteros.
          final medio = ((c.rango.minimo + c.rango.maximo) / 2 / 100).round() * 100;
          if (_precio == null || _precio! < c.rango.piso) _precio = medio;
        });
      } catch (e) {
        if (mounted) mostrarError(context, e);
      } finally {
        if (mounted) setState(() => _cotizando = false);
      }
    });
  }

  void _elegirDuracion(int minutos, {bool personalizada = false}) {
    setState(() {
      _duracion = minutos;
      _personalizada = personalizada;
      _precio = null;
      if (personalizada) _paquete = false;
    });
    _cotizar();
  }

  Future<void> _duracionPersonalizada() async {
    final t = await pedirTexto(
      context,
      titulo: 'Duración personalizada',
      etiqueta: 'Minutos',
      pista: '45',
      teclado: TextInputType.number,
    );
    final m = int.tryParse(t ?? '');
    if (m == null) return;
    if (m < 15 || m > 600) {
      if (mounted) avisar(context, 'Elige entre 15 y 600 minutos.');
      return;
    }
    _elegirDuracion(m, personalizada: true);
  }

  Future<void> _elegirMascota(List<Mascota> mascotas) async {
    final id = await mostrarHoja<String>(
      context,
      builder: (c) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('¿Para quién es?', style: MicanTexto.titulo2),
          const SizedBox(height: 12),
          for (final m in mascotas) ...[
            TarjetaMascota(
              nombre: m.nombre,
              detalle: _detalleMascota(m),
              emoji: m.emoji,
              fotoUrl: m.fotoUrl,
              alPresionar: () => Navigator.pop(c, m.id),
            ),
            const SizedBox(height: 10),
          ],
          Boton(
            'Agregar mascota',
            tipo: TipoBoton.contorno,
            icono: MicanIcono.mas,
            alPresionar: () {
              Navigator.pop(c);
              context.push('/mascotas/nueva');
            },
          ),
        ],
      ),
    );
    if (id != null) setState(() => _mascotaId = id);
  }

  Future<void> _elegirPago() async {
    final m = await mostrarHoja<String>(
      context,
      builder: (c) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('¿Cómo le pagarás al cuidador?', style: MicanTexto.titulo2),
          const SizedBox(height: 4),
          Text('Le pagas directamente al terminar el servicio.', style: MicanTexto.leyenda),
          const SizedBox(height: 12),
          for (final op in const ['yape', 'plin', 'efectivo'])
            FilaLista(
              titulo: metodoPago(op),
              inicio: RadioMican(marcado: op == _metodoPago),
              alPresionar: () => Navigator.pop(c, op),
            ),
        ],
      ),
    );
    if (m != null) setState(() => _metodoPago = m);
  }

  Future<void> _buscar(Mascota mascota) async {
    if (_recojo.text.trim().isEmpty) return avisar(context, 'Escribe el punto de recojo.');
    if (widget.tipo == TipoServicio.transporte && _destino.text.trim().isEmpty) {
      return avisar(context, 'Escribe a dónde lo llevamos (veterinaria o groomer).');
    }
    if (widget.tipo == TipoServicio.paseo && !mascota.esPerro) {
      return avisar(context, 'El paseo es solo para perros. Prueba con una visita a domicilio.');
    }
    final precio = _paquete ? _cotizacion?.paquetes[_duracion] : _precio;
    if (precio == null) return;
    setState(() => _enviando = true);
    try {
      final r = await ref
          .read(apiProvider)
          .crearSolicitud(
            mascotaId: mascota.id,
            tipo: widget.tipo,
            modalidad: _paquete ? 'paquete' : 'oferta',
            duracionMin: _duracion,
            precio: precio,
            origen: _lugarOrigen,
            destino: _lugarDestino,
            metodoPago: _metodoPago,
            indicaciones: _indicaciones.text.trim(),
          );
      if (!mounted) return;
      if (r.aviso == 'MENOS_OFERTAS') {
        avisar(context, 'Tu precio está por debajo del sugerido: podrías recibir menos ofertas.');
      }
      context.pushReplacement('/servicio/${r.id}');
    } catch (e) {
      if (!mounted) return;
      if (e is ErrorMican && e.mensaje.contains('Ya tienes una solicitud')) {
        avisar(context, e.mensaje);
        context.go('/app');
      } else {
        mostrarError(context, e);
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  static String _detalleMascota(Mascota m) =>
      [if (m.raza.isNotEmpty) m.raza, tamano(m.tamano), if (m.edadAnios != null) edad(m.edadAnios)].join(' · ');

  @override
  Widget build(BuildContext context) {
    final mascotas = ref.watch(mascotasProvider).value ?? const <Mascota>[];
    final mascota =
        mascotas.where((m) => m.id == _mascotaId).firstOrNull ??
        (widget.tipo == TipoServicio.paseo ? mascotas.where((m) => m.esPerro).firstOrNull : null) ??
        mascotas.firstOrNull;
    final c = _cotizacion;
    final precioPaquete = c?.paquetes[_duracion];

    final titulo = switch (widget.tipo) {
      TipoServicio.paseo => 'Solicitar paseo',
      TipoServicio.visita => 'Solicitar visita',
      TipoServicio.transporte => 'Solicitar transporte',
    };

    return PantallaMican(
      titulo: titulo,
      barraAccion: BarraAccion(
        children: [
          Expanded(
            child: Boton(
              _paquete ? 'Publicar paquete' : 'Buscar cuidadores',
              cargando: _enviando,
              alPresionar: mascota == null || c == null || (_paquete && precioPaquete == null)
                  ? null
                  : () => _buscar(mascota),
            ),
          ),
        ],
      ),
      children: [
        if (mascota == null)
          Tarjeta(
            alPresionar: () => context.push('/mascotas/nueva'),
            child: Row(
              children: [
                const CajaIcono(MicanIcono.mas, tamano: 56, tamanoIcono: 26, radio: 999, color: MicanColores.primario),
                const SizedBox(width: 12),
                Expanded(child: Text('Agrega a tu mascota para continuar', style: MicanTexto.subtitulo)),
                const Icono(MicanIcono.chevron, tamano: 20),
              ],
            ),
          )
        else
          TarjetaMascota(
            nombre: mascota.nombre,
            detalle: _detalleMascota(mascota),
            emoji: mascota.emoji,
            fotoUrl: mascota.fotoUrl,
            vacunasAlDia: mascota.vacunasAlDia,
            alPresionar: () => _elegirMascota(mascotas),
          ),
        CampoTexto(
          etiqueta: 'Punto de recojo',
          controlador: _recojo,
          pista: _origen == null ? 'Buscando tu ubicación…' : 'Av. Larco 123, Miraflores',
        ),
        if (widget.tipo == TipoServicio.transporte)
          CampoTexto(etiqueta: 'Destino', controlador: _destino, pista: 'Vet San Borja'),
        CampoTexto(
          etiqueta: widget.tipo == TipoServicio.visita
              ? 'Tareas de la visita (una por línea)'
              : 'Indicaciones (opcional)',
          controlador: _indicaciones,
          lineas: 3,
          maxCaracteres: 500,
          pista: widget.tipo == TipoServicio.visita
              ? 'Servir comida y agua\nLimpiar el arenero\nJugar 15 min'
              : 'Ej. Toca el intercomunicador del 302',
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Duración', style: MicanTexto.etiqueta),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (m, t) in const [(30, '30 min'), (60, '1 h'), (120, '2 h')])
                  ChipEtiqueta(
                    t,
                    seleccionado: !_personalizada && _duracion == m,
                    alPresionar: () => _elegirDuracion(m),
                  ),
                ChipEtiqueta(
                  _personalizada ? duracion(_duracion) : 'Personalizado',
                  seleccionado: _personalizada,
                  alPresionar: _duracionPersonalizada,
                ),
              ],
            ),
          ],
        ),
        SelectorSegmentado(
          opciones: const ['Ofrecer mi precio', 'Paquete fijo'],
          indice: _paquete ? 1 : 0,
          alCambiar: (i) {
            if (i == 1 && _personalizada) {
              avisar(context, 'Los paquetes son de 30 min, 1 h o 2 h.');
              return;
            }
            setState(() => _paquete = i == 1);
          },
        ),
        if (c == null)
          const Tarjeta(child: SizedBox(height: 100, child: Cargando()))
        else if (_paquete)
          _TarjetaPaquete(precio: precioPaquete, duracionMin: _duracion)
        else
          _TarjetaPrecio(
            cotizacion: c,
            duracionMin: _duracion,
            precio: _precio ?? c.rango.minimo,
            cargando: _cotizando,
            alCambiar: (p) => setState(() => _precio = p),
          ),
        Tarjeta(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          alPresionar: _elegirPago,
          child: Row(
            children: [
              const Icono(MicanIcono.billetera),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pago al cuidador: ${metodoPago(_metodoPago)}', style: MicanTexto.cuerpoFuerte),
                    Text(
                      _metodoPago == 'efectivo'
                          ? 'También Yape o Plin al terminar'
                          : 'También efectivo o ${_metodoPago == 'yape' ? 'Plin' : 'Yape'} al terminar',
                      style: MicanTexto.leyenda,
                    ),
                  ],
                ),
              ),
              const Icono(MicanIcono.chevron),
            ],
          ),
        ),
      ],
    );
  }
}

class _TarjetaPrecio extends StatelessWidget {
  const _TarjetaPrecio({
    required this.cotizacion,
    required this.duracionMin,
    required this.precio,
    required this.cargando,
    required this.alCambiar,
  });

  final Cotizacion cotizacion;
  final int duracionMin;
  final int precio;
  final bool cargando;
  final ValueChanged<int> alCambiar;

  @override
  Widget build(BuildContext context) {
    final r = cotizacion.rango;
    final km = cotizacion.distanciaKm > 0 ? ' · ${cotizacion.distanciaKm.toStringAsFixed(1)} km' : '';
    final bajo = precio < r.minimo;
    Widget paso(String s, int delta) => Material(
      color: MicanColores.primarioSuave,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: precio + delta < r.piso ? null : () => alCambiar(precio + delta),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Text(s, style: MicanTexto.titulo1.copyWith(color: MicanColores.primario)),
          ),
        ),
      ),
    );
    return Tarjeta(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Text(
            'Precio sugerido: S/ ${r.minimo ~/ 100} – ${r.maximo ~/ 100} (${duracion(duracionMin)}$km)',
            style: MicanTexto.leyenda,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(label: 'Bajar S/ 1', child: paso('−', -100)),
              const SizedBox(width: 24),
              AnimatedOpacity(
                opacity: cargando ? 0.4 : 1,
                duration: const Duration(milliseconds: 150),
                child: Text(solesCortos(precio), style: MicanTexto.display),
              ),
              const SizedBox(width: 24),
              Semantics(label: 'Subir S/ 1', child: paso('+', 100)),
            ],
          ),
          const SizedBox(height: 6),
          Pildora(
            texto: bajo ? 'Debajo del sugerido: quizá recibas menos ofertas' : 'Los cuidadores pueden contraofertar',
            fondo: MicanColores.acentoSuave,
            color: MicanColores.acento,
            compacta: true,
          ),
        ],
      ),
    );
  }
}

class _TarjetaPaquete extends StatelessWidget {
  const _TarjetaPaquete({required this.precio, required this.duracionMin});

  final int? precio;
  final int duracionMin;

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Text('Paquete de ${duracion(duracionMin)} · precio cerrado', style: MicanTexto.leyenda),
          const SizedBox(height: 6),
          Text(precio == null ? '—' : solesCortos(precio!), style: MicanTexto.display),
          const SizedBox(height: 6),
          const Pildora(
            texto: 'El primer cuidador que acepte queda asignado',
            fondo: MicanColores.primarioSuave,
            color: MicanColores.primario,
            compacta: true,
          ),
        ],
      ),
    );
  }
}
