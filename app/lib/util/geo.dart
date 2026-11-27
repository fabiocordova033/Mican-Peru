import 'dart:math' as math;

import '../datos/modelos.dart';

/// Distancia en km entre dos puntos (Haversine), igual que el backend.
double distanciaKm(Lugar a, Lugar b) {
  const r = 6371.0;
  double rad(double g) => g * math.pi / 180;
  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final h =
      math.pow(math.sin(dLat / 2), 2) + math.cos(rad(a.lat)) * math.cos(rad(b.lat)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(h));
}

double distanciaRutaKm(List<Lugar> ruta) {
  var total = 0.0;
  for (var i = 1; i < ruta.length; i++) {
    total += distanciaKm(ruta[i - 1], ruta[i]);
  }
  return total;
}
