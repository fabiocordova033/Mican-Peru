import 'package:geolocator/geolocator.dart';

import 'modelos.dart';

/// Permiso y lectura de ubicación (HU-29). La pantalla "Permiso de
/// ubicación" explica el uso antes de pedir el permiso del sistema.
class ServicioUbicacion {
  /// Miraflores, Lima: punto por defecto si el usuario no da su ubicación.
  static final porDefecto = Lugar(lat: -12.1211, lng: -77.0297, direccion: 'Miraflores, Lima');

  Future<bool> tienePermiso() async {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  Future<bool> pedirPermiso() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  /// Ubicación actual o `null` si no hay permiso.
  Future<Lugar?> actual() async {
    if (!await tienePermiso()) return null;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      );
      return Lugar(lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      final ultima = await Geolocator.getLastKnownPosition();
      return ultima == null ? null : Lugar(lat: ultima.latitude, lng: ultima.longitude);
    }
  }

  /// Posiciones cada ~10 m durante un servicio en curso.
  Stream<Lugar> seguir() => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
  ).map((p) => Lugar(lat: p.latitude, lng: p.longitude));
}
