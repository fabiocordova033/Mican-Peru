import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/entorno.dart';
import '../tema/colores.dart';

class PuntoMapa {
  const PuntoMapa(this.lat, this.lng);
  final double lat;
  final double lng;
}

enum TipoMarcador { cuidador, mascota, destino }

class MarcadorMapa {
  const MarcadorMapa(this.punto, this.tipo);
  final PuntoMapa punto;
  final TipoMarcador tipo;
}

/// Componente "Mapa". Con `MAPS_HABILITADO=true` usa Google Maps; si no, el
/// mapa ilustrado del diseño, con la ruta y los marcadores proyectados encima.
class MapaMican extends StatelessWidget {
  const MapaMican({
    super.key,
    this.centro,
    this.ruta = const [],
    this.marcadores = const [],
    this.colorRuta = MicanColores.acento,
  });

  final PuntoMapa? centro;
  final List<PuntoMapa> ruta;
  final List<MarcadorMapa> marcadores;
  final Color colorRuta;

  @override
  Widget build(BuildContext context) {
    if (Entorno.mapsHabilitado && centro != null) {
      final c = centro!;
      return GoogleMap(
        initialCameraPosition: CameraPosition(target: LatLng(c.lat, c.lng), zoom: 15),
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        polylines: {
          if (ruta.length > 1)
            Polyline(
              polylineId: const PolylineId('ruta'),
              color: colorRuta,
              width: 5,
              points: [for (final p in ruta) LatLng(p.lat, p.lng)],
            ),
        },
        markers: {
          for (var i = 0; i < marcadores.length; i++)
            Marker(
              markerId: MarkerId('m$i'),
              position: LatLng(marcadores[i].punto.lat, marcadores[i].punto.lng),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                marcadores[i].tipo == TipoMarcador.cuidador ? BitmapDescriptor.hueCyan : BitmapDescriptor.hueOrange,
              ),
            ),
        },
      );
    }
    return CustomPaint(
      painter: _MapaIlustrado(ruta: ruta, marcadores: marcadores, colorRuta: colorRuta),
      child: const SizedBox.expand(),
    );
  }
}

/// Reproduce el componente "Mapa" de Figma (390×460): calles, parques, pines.
class _MapaIlustrado extends CustomPainter {
  _MapaIlustrado({required this.ruta, required this.marcadores, required this.colorRuta});

  final List<PuntoMapa> ruta;
  final List<MarcadorMapa> marcadores;
  final Color colorRuta;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 390;
    final sy = size.height / 460;
    Offset p(double x, double y) => Offset(x * sx, y * sy);

    canvas.drawRect(Offset.zero & size, Paint()..color = MicanColores.mapaFondo);

    final parque = Paint()..color = MicanColores.mapaParque;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromPoints(p(230, 40), p(360, 150)), Radius.circular(16 * sx)),
      parque,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromPoints(p(20, 300), p(130, 390)), Radius.circular(16 * sx)),
      parque,
    );

    void calle(Offset a, Offset b, double ancho) => canvas.drawLine(
      a,
      b,
      Paint()
        ..color = Colors.white
        ..strokeWidth = ancho * sx
        ..strokeCap = StrokeCap.butt,
    );
    calle(p(-10, 90), p(400, 120), 18);
    calle(p(-10, 300), p(400, 260), 22);
    calle(p(80, -10), p(140, 470), 16);
    calle(p(300, -10), p(250, 470), 14);
    calle(p(-10, 400), p(400, 360), 10);
    calle(p(190, -10), p(200, 470), 8);
    canvas.drawRect(Rect.fromPoints(p(0, 420), p(390, 460)), Paint()..color = MicanColores.mapaAgua);

    final proyectar = _proyeccion(size);

    if (ruta.length > 1 && proyectar != null) {
      final path = Path()..moveTo(proyectar(ruta.first).dx, proyectar(ruta.first).dy);
      for (final q in ruta.skip(1)) {
        final o = proyectar(q);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = colorRuta
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    void pin(Offset c, Color color, {double radio = 17, double borde = 4}) {
      canvas.drawCircle(c, radio, Paint()..color = Colors.white);
      canvas.drawCircle(c, radio - borde, Paint()..color = color);
    }

    if (marcadores.isEmpty) {
      // Cuidadores cercanos decorativos, como en el diseño.
      pin(p(127, 197), MicanColores.primario);
      pin(p(282, 232), MicanColores.primario);
      pin(p(337, 157), MicanColores.primario);
      pin(p(192, 347), MicanColores.acento);
    } else if (proyectar != null) {
      for (final m in marcadores) {
        pin(proyectar(m.punto), switch (m.tipo) {
          TipoMarcador.cuidador => MicanColores.primario,
          TipoMarcador.mascota => MicanColores.acento,
          TipoMarcador.destino => MicanColores.acento,
        });
      }
    }
    pin(p(201, 251), MicanColores.tuUbicacion, radio: 11, borde: 5);
  }

  /// Ajusta lat/lng de la ruta y los marcadores al rectángulo central del dibujo.
  Offset Function(PuntoMapa)? _proyeccion(Size size) {
    final puntos = [...ruta, ...marcadores.map((m) => m.punto)];
    if (puntos.isEmpty) return null;
    var minLat = puntos.first.lat, maxLat = minLat, minLng = puntos.first.lng, maxLng = minLng;
    for (final q in puntos) {
      minLat = math.min(minLat, q.lat);
      maxLat = math.max(maxLat, q.lat);
      minLng = math.min(minLng, q.lng);
      maxLng = math.max(maxLng, q.lng);
    }
    final dLat = math.max(maxLat - minLat, 0.002);
    final dLng = math.max(maxLng - minLng, 0.002);
    final area = Rect.fromLTRB(size.width * 0.18, size.height * 0.18, size.width * 0.82, size.height * 0.72);
    return (q) =>
        Offset(area.left + (q.lng - minLng) / dLng * area.width, area.bottom - (q.lat - minLat) / dLat * area.height);
  }

  @override
  bool shouldRepaint(_MapaIlustrado old) => old.ruta != ruta || old.marcadores != marcadores;
}
