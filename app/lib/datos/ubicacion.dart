import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'modelos.dart';

/// Permiso y lectura de ubicación (HU-29). La pantalla "Permiso de
/// ubicación" explica el uso antes de pedir el permiso del sistema.
class ServicioUbicacion {
  /// Miraflores, Lima: punto por defecto si el usuario no da su ubicación.
  static final porDefecto = Lugar(lat: -12.1211, lng: -77.0297, direccion: 'Miraflores, Lima');

  /// Versión del aviso de ubicación en segundo plano. Si cambia el texto,
  /// se sube el número y el cuidador lo vuelve a ver.
  static const _claveAvisoSegundoPlano = 'aviso_ubicacion_segundo_plano_v1';

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

  /// HU-16: posiciones cada ~10 m durante un servicio en curso. Con
  /// [enSegundoPlano] siguen llegando con la pantalla apagada o la app en
  /// segundo plano (ver [ajustesSeguimiento]).
  Stream<Lugar> seguir({bool enSegundoPlano = false}) => Geolocator.getPositionStream(
    locationSettings: ajustesSeguimiento(defaultTargetPlatform, enSegundoPlano: enSegundoPlano),
  ).map((p) => Lugar(lat: p.latitude, lng: p.longitude));

  /// ¿El cuidador ya vio el aviso de ubicación en segundo plano?
  Future<bool> avisoSegundoPlanoVisto() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_claveAvisoSegundoPlano) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> marcarAvisoSegundoPlanoVisto() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_claveAvisoSegundoPlano, true);
    } catch (_) {
      // Si no se puede guardar, el aviso se vuelve a mostrar: es lo seguro.
    }
  }
}

/// Ajustes del GPS durante el paseo.
///
/// En segundo plano NO pedimos el permiso "Permitir todo el tiempo":
/// - **Android:** un servicio en primer plano (`foregroundServiceType=location`)
///   con una notificación fija "Paseo en curso" mientras dure el servicio. Así
///   basta el permiso "Mientras se usa la app" y Google Play no exige el
///   formulario de ubicación en segundo plano.
/// - **iOS:** `allowBackgroundLocationUpdates` con el indicador azul de
///   ubicación visible y `UIBackgroundModes = location` en Info.plist; también
///   funciona con "Al usar la app".
@visibleForTesting
LocationSettings ajustesSeguimiento(TargetPlatform plataforma, {required bool enSegundoPlano}) {
  const precision = LocationAccuracy.high;
  const cadaMetros = 10;
  switch (plataforma) {
    case TargetPlatform.android:
      return AndroidSettings(
        accuracy: precision,
        distanceFilter: cadaMetros,
        intervalDuration: const Duration(seconds: 10),
        foregroundNotificationConfig: enSegundoPlano
            ? const ForegroundNotificationConfig(
                notificationTitle: 'Paseo en curso',
                notificationText: 'Mican comparte tu ubicación con el dueño hasta que finalices el servicio.',
                notificationChannelName: 'Paseo en curso',
                notificationIcon: AndroidResource(name: 'ic_notificacion', defType: 'drawable'),
                color: Color(0xFF1F6F82),
                enableWakeLock: true,
                setOngoing: true,
              )
            : null,
      );
    case TargetPlatform.iOS:
      return AppleSettings(
        accuracy: precision,
        distanceFilter: cadaMetros,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: enSegundoPlano,
        showBackgroundLocationIndicator: enSegundoPlano,
      );
    default:
      return const LocationSettings(accuracy: precision, distanceFilter: cadaMetros);
  }
}
