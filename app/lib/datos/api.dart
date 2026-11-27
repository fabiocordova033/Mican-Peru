import 'package:cloud_functions/cloud_functions.dart';

import 'modelos.dart';

/// Error legible que viene de `falla(...)` en las Cloud Functions.
class ErrorMican implements Exception {
  ErrorMican(this.mensaje, {this.codigo, this.detalles});

  final String mensaje;
  final String? codigo;
  final Object? detalles;

  Json get datos => mapa(detalles);

  @override
  String toString() => mensaje;
}

/// Envoltorio tipado de las Cloud Functions callables (functions/src/callable).
/// Todo lo que mueve dinero o cambia estados pasa por aquí.
class MicanApi {
  MicanApi(this._fn);

  final FirebaseFunctions _fn;

  Future<Json> _llamar(String nombre, [Json? datos]) async {
    try {
      final r = await _fn.httpsCallable(nombre).call<Object?>(datos ?? const {});
      return mapa(r.data);
    } on FirebaseFunctionsException catch (e) {
      throw ErrorMican(e.message ?? 'Algo salió mal. Inténtalo de nuevo.', codigo: e.code, detalles: e.details);
    }
  }

  // ---------- Cuenta ----------
  Future<Json> versionesLegales() => _llamar('versionesLegales');

  Future<void> completarRegistro({
    required String nombre,
    required String fechaNacimiento,
    required Rol rol,
    required String versionTerminos,
    required String versionPrivacidad,
    required bool aceptaPublicidad,
    required bool aceptaDatosSensibles,
  }) => _llamar('completarRegistro', {
    'nombre': nombre,
    'fechaNacimiento': fechaNacimiento,
    'rol': rol.name,
    'versionTerminos': versionTerminos,
    'versionPrivacidad': versionPrivacidad,
    'aceptaTerminos': true,
    'aceptaPrivacidad': true,
    'aceptaPublicidad': aceptaPublicidad,
    'aceptaDatosSensibles': aceptaDatosSensibles,
  });

  Future<void> aceptarNuevaVersion(String terminos, String privacidad) =>
      _llamar('aceptarNuevaVersion', {'versionTerminos': terminos, 'versionPrivacidad': privacidad});

  Future<void> activarRolCuidador() => _llamar('activarRolCuidador', {'aceptaDatosSensibles': true});

  Future<void> cambiarRolActivo(Rol rol) => _llamar('cambiarRolActivo', {'rol': rol.name});

  Future<void> actualizarConsentimiento(String tipo, bool aceptado) =>
      _llamar('actualizarConsentimiento', {'tipo': tipo, 'aceptado': aceptado});

  Future<void> actualizarPerfil(Json cambios) => _llamar('actualizarPerfil', cambios);

  Future<void> cambiarDisponibilidad(bool disponible) => _llamar('cambiarDisponibilidad', {'disponible': disponible});

  // ---------- Verificación ----------
  Future<void> enviarAVerificacion(String dni) => _llamar('enviarAVerificacion', {'dni': dni});

  // ---------- Mascotas ----------
  Future<String> crearMascota(Json mascota) async => (await _llamar('crearMascota', mascota))['id'] as String;

  Future<void> actualizarMascota(String id, Json cambios) => _llamar('actualizarMascota', {'id': id, ...cambios});

  Future<void> archivarMascota(String id) => _llamar('archivarMascota', {'id': id});

  // ---------- Solicitudes y ofertas ----------
  Future<Cotizacion> cotizar({
    required TipoServicio tipo,
    required int duracionMin,
    required Lugar origen,
    Lugar? destino,
  }) async {
    final r = await _llamar('cotizar', {
      'tipo': tipo.name,
      'duracionMin': duracionMin,
      'origen': origen.aJson(),
      'destino': ?destino?.aJson(),
    });
    return Cotizacion(
      rango: RangoSugerido.desde(mapa(r['rango'])),
      paquetes: mapa(r['paquetes']).map((k, v) => MapEntry(int.parse(k), entero(v))),
      distanciaKm: decimal(r['distanciaKm']),
    );
  }

  Future<({String id, String? aviso})> crearSolicitud({
    required String mascotaId,
    required TipoServicio tipo,
    required String modalidad,
    required int duracionMin,
    required int precio,
    required Lugar origen,
    Lugar? destino,
    required String metodoPago,
    String indicaciones = '',
  }) async {
    final r = await _llamar('crearSolicitud', {
      'mascotaId': mascotaId,
      'tipo': tipo.name,
      'modalidad': modalidad,
      'duracionMin': duracionMin,
      'precio': precio,
      'origen': origen.aJson(),
      'destino': ?destino?.aJson(),
      'metodoPago': metodoPago,
      'indicaciones': indicaciones,
    });
    return (id: r['id'] as String, aviso: r['aviso'] as String?);
  }

  Future<SolicitudesCercanas> listarSolicitudesCercanas(double lat, double lng) async {
    final r = await _llamar('listarSolicitudesCercanas', {'lat': lat, 'lng': lng});
    return SolicitudesCercanas(
      disponible: r['disponible'] == true,
      recargar: r['recargar'] == true,
      saldo: r['saldo'] is num ? entero(r['saldo']) : null,
      solicitudes: (r['solicitudes'] as List? ?? const []).map((s) => SolicitudCercana.desde(mapa(s))).toList(),
    );
  }

  Future<Json> enviarOferta({
    required String servicioId,
    required int precio,
    required double lat,
    required double lng,
  }) => _llamar('enviarOferta', {'servicioId': servicioId, 'precio': precio, 'lat': lat, 'lng': lng});

  Future<void> aceptarOferta(String servicioId, String cuidadorId) =>
      _llamar('aceptarOferta', {'servicioId': servicioId, 'cuidadorId': cuidadorId});

  Future<void> tomarPaquete(String servicioId, double lat, double lng) =>
      _llamar('tomarPaquete', {'servicioId': servicioId, 'lat': lat, 'lng': lng});

  Future<void> cancelarServicio(String servicioId, String motivo) =>
      _llamar('cancelarServicio', {'servicioId': servicioId, 'motivo': motivo});

  Future<void> subirPrecio(String servicioId, int precio) =>
      _llamar('subirPrecio', {'servicioId': servicioId, 'precio': precio});

  // ---------- Ejecución ----------
  Future<void> iniciarServicio(String servicioId, double lat, double lng) =>
      _llamar('iniciarServicio', {'servicioId': servicioId, 'lat': lat, 'lng': lng});

  Future<Json> finalizarServicio(String servicioId) => _llamar('finalizarServicio', {'servicioId': servicioId});

  Future<Json> reportarEmergencia(String servicioId, {String detalle = '', double? lat, double? lng}) =>
      _llamar('reportarEmergencia', {'servicioId': servicioId, 'detalle': detalle, 'lat': ?lat, 'lng': ?lng});

  // ---------- Pagos ----------
  Future<({String pagoId, String urlPago})> iniciarRecarga(int monto) async {
    final r = await _llamar('iniciarRecarga', {'monto': monto});
    return (pagoId: r['pagoId'] as String, urlPago: r['urlPago'] as String);
  }

  Future<Json> suscribirPremium() => _llamar('suscribirPremium');

  Future<Json> cancelarPremium() => _llamar('cancelarPremium');

  Future<Json> solicitarDevolucionSaldo(String cuentaDestino) =>
      _llamar('solicitarDevolucionSaldo', {'cuentaDestino': cuentaDestino});

  // ---------- Calificaciones ----------
  Future<Json> calificar({
    required String servicioId,
    required int estrellas,
    required List<String> etiquetas,
    String comentario = '',
    String? motivo,
  }) => _llamar('calificar', {
    'servicioId': servicioId,
    'estrellas': estrellas,
    'etiquetas': etiquetas,
    'comentario': comentario,
    'motivo': ?motivo,
  });

  Future<Json> miProgresoNivel() => _llamar('miProgresoNivel');

  // ---------- Legal ----------
  Future<Json> datosEmpresa() => _llamar('datosEmpresa');

  Future<Json> presentarReclamo(Json reclamo) => _llamar('presentarReclamo', reclamo);

  Future<Json> solicitarArco(String derecho, String detalle) =>
      _llamar('solicitarArco', {'derecho': derecho, 'detalle': detalle});

  Future<Json> exportarMisDatos() => _llamar('exportarMisDatos');

  Future<Json> eliminarCuenta({required String confirmacion, bool renunciarSaldo = false}) =>
      _llamar('eliminarCuenta', {'confirmacion': confirmacion, 'renunciarSaldo': renunciarSaldo});

  Future<void> recuperarCuenta() => _llamar('recuperarCuenta');
}

class Cotizacion {
  Cotizacion({required this.rango, required this.paquetes, required this.distanciaKm});

  final RangoSugerido rango;

  /// Duración en minutos (30, 60, 120) → precio en céntimos.
  final Map<int, int> paquetes;
  final double distanciaKm;
}

class SolicitudesCercanas {
  SolicitudesCercanas({required this.disponible, required this.recargar, this.saldo, required this.solicitudes});

  final bool disponible;
  final bool recargar;
  final int? saldo;
  final List<SolicitudCercana> solicitudes;
}
