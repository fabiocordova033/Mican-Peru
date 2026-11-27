/// Configuración por `--dart-define` (ver app/README.md).
abstract final class Entorno {
  /// Conecta Auth, Firestore, Functions y Storage a los emuladores locales.
  static const usarEmuladores = bool.fromEnvironment('USAR_EMULADORES', defaultValue: true);

  /// 10.0.2.2 es la máquina anfitriona vista desde el emulador de Android.
  /// En iOS Simulator o un celular real en la misma red, usa 127.0.0.1 o la IP de tu PC.
  static const hostEmulador = String.fromEnvironment('HOST_EMULADOR', defaultValue: '10.0.2.2');

  /// Con emuladores debe coincidir con el --project de `npm run serve` (demo-mican).
  static const proyectoFirebase = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'demo-mican');

  /// Región de las Cloud Functions (functions/src/lib/firebase.ts).
  static const regionFunciones = 'southamerica-east1';

  /// Mientras no haya API key de Google Maps se muestra el mapa ilustrado
  /// del diseño. Con la key configurada (ver README) se usa Google Maps.
  static const mapsHabilitado = bool.fromEnvironment('MAPS_HABILITADO', defaultValue: false);

  /// Teléfono de soporte para la hoja de emergencia.
  static const telefonoSoporte = String.fromEnvironment('TELEFONO_SOPORTE', defaultValue: '+51999999999');
}
