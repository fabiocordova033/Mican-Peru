import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelos de lectura de Firestore. Ver docs/modelo-de-datos.md.
/// Todos los montos están en CÉNTIMOS (enteros), igual que en el backend.

typedef Json = Map<String, dynamic>;

DateTime? fecha(Object? v) => switch (v) {
  Timestamp t => t.toDate(),
  int ms => DateTime.fromMillisecondsSinceEpoch(ms),
  _ => null,
};

int entero(Object? v) => v is num ? v.toInt() : 0;
double decimal(Object? v) => v is num ? v.toDouble() : 0;
List<String> textos(Object? v) => v is List ? v.map((e) => '$e').toList() : const [];
Json mapa(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

// ---------------------------------------------------------------------------

enum Rol { dueno, cuidador }

class Usuario {
  Usuario({
    required this.uid,
    required this.nombre,
    required this.telefono,
    required this.esDueno,
    required this.esCuidador,
    required this.rolActivo,
    required this.plan,
    required this.premiumHasta,
    required this.enPrueba,
    required this.renovacionAutomatica,
    required this.estadoCuenta,
    required this.eliminarEn,
    required this.aceptaPublicidad,
    required this.versionTerminos,
    required this.versionPrivacidad,
  });

  factory Usuario.desde(String uid, Json d) {
    final roles = mapa(d['roles']);
    final consent = mapa(d['consentimientos']);
    return Usuario(
      uid: uid,
      nombre: d['nombre'] as String? ?? '',
      telefono: d['telefono'] as String? ?? '',
      esDueno: roles['dueno'] == true,
      esCuidador: roles['cuidador'] == true,
      rolActivo: d['rolActivo'] == 'cuidador' ? Rol.cuidador : Rol.dueno,
      plan: d['plan'] as String? ?? 'gratis',
      premiumHasta: fecha(d['premiumHasta']),
      enPrueba: d['enPrueba'] == true,
      renovacionAutomatica: d['renovacionAutomatica'] == true,
      estadoCuenta: d['estadoCuenta'] as String? ?? 'activa',
      eliminarEn: fecha(d['eliminarEn']),
      aceptaPublicidad: mapa(consent['publicidad'])['aceptado'] == true,
      versionTerminos: mapa(consent['terminos'])['version'] as String?,
      versionPrivacidad: mapa(consent['privacidad'])['version'] as String?,
    );
  }

  final String uid;
  final String nombre;
  final String telefono;
  final bool esDueno;
  final bool esCuidador;
  final Rol rolActivo;
  final String plan;
  final DateTime? premiumHasta;
  final bool enPrueba;
  final bool renovacionAutomatica;
  final String estadoCuenta;
  final DateTime? eliminarEn;
  final bool aceptaPublicidad;
  final String? versionTerminos;
  final String? versionPrivacidad;

  bool get esPremium => premiumHasta != null && premiumHasta!.isAfter(DateTime.now());
  String get primerNombre => nombre.split(' ').first;
}

class Perfil {
  Perfil({
    required this.uid,
    required this.nombre,
    this.fotoUrl,
    this.edad,
    this.esCuidador = false,
    this.verificado = false,
    this.disponible = false,
    this.nivel = 'nuevo',
    this.calificacionPromedio = 0,
    this.numResenas = 0,
    this.serviciosCompletados = 0,
    this.etiquetas = const {},
    this.experiencia = '',
    this.certificaciones = const [],
    this.educacion = const [],
  });

  factory Perfil.desde(String uid, Json d) => Perfil(
    uid: uid,
    nombre: d['nombre'] as String? ?? '',
    fotoUrl: d['fotoUrl'] as String?,
    edad: d['edad'] is num ? entero(d['edad']) : null,
    esCuidador: d['esCuidador'] == true,
    verificado: d['verificado'] == true,
    disponible: d['disponible'] == true,
    nivel: d['nivel'] as String? ?? 'nuevo',
    calificacionPromedio: decimal(d['calificacionPromedio']),
    numResenas: entero(d['numResenas']),
    serviciosCompletados: entero(d['serviciosCompletados']),
    etiquetas: mapa(d['etiquetas']).map((k, v) => MapEntry(k, entero(v))),
    experiencia: d['experiencia'] as String? ?? '',
    certificaciones: textos(d['certificaciones']),
    educacion: textos(d['educacion']),
  );

  final String uid;
  final String nombre;
  final String? fotoUrl;
  final int? edad;
  final bool esCuidador;
  final bool verificado;
  final bool disponible;
  final String nivel;
  final double calificacionPromedio;
  final int numResenas;
  final int serviciosCompletados;
  final Map<String, int> etiquetas;
  final String experiencia;
  final List<String> certificaciones;
  final List<String> educacion;
}

class Vacuna {
  Vacuna({required this.nombre, required this.aplicada, required this.vence, this.estado = ''});

  factory Vacuna.desde(Json d) => Vacuna(
    nombre: d['nombre'] as String? ?? '',
    aplicada: d['aplicada'] as String? ?? '',
    vence: d['vence'] as String? ?? '',
    estado: d['estado'] as String? ?? '',
  );

  final String nombre;
  final String aplicada; // AAAA-MM-DD
  final String vence; // AAAA-MM-DD
  final String estado; // al_dia | por_vencer | vencida

  Json aJson() => {'nombre': nombre, 'aplicada': aplicada, 'vence': vence};
}

class Mascota {
  Mascota({
    required this.id,
    required this.nombre,
    required this.especie,
    this.raza = '',
    this.tamano = 'mediano',
    this.edadAnios,
    this.pesoKg,
    this.fotoUrl,
    this.vacunas = const [],
    this.vacunasAlDia = false,
    this.temperamento = const [],
    this.alertas = const [],
    this.notas = '',
  });

  factory Mascota.desde(String id, Json d) => Mascota(
    id: id,
    nombre: d['nombre'] as String? ?? '',
    especie: d['especie'] as String? ?? 'perro',
    raza: d['raza'] as String? ?? '',
    tamano: d['tamano'] as String? ?? 'mediano',
    edadAnios: d['edadAnios'] is num ? decimal(d['edadAnios']) : null,
    pesoKg: d['pesoKg'] is num ? decimal(d['pesoKg']) : null,
    fotoUrl: d['fotoUrl'] as String?,
    vacunas: (d['vacunas'] as List? ?? const []).map((v) => Vacuna.desde(mapa(v))).toList(),
    vacunasAlDia: d['vacunasAlDia'] == true,
    temperamento: textos(d['temperamento']),
    alertas: textos(d['alertas']),
    notas: d['notas'] as String? ?? '',
  );

  final String id;
  final String nombre;
  final String especie; // perro | gato
  final String raza;
  final String tamano; // pequeno | mediano | grande
  final double? edadAnios;
  final double? pesoKg;
  final String? fotoUrl;
  final List<Vacuna> vacunas;
  final bool vacunasAlDia;
  final List<String> temperamento;
  final List<String> alertas;
  final String notas;

  bool get esPerro => especie == 'perro';
  String get emoji => esPerro ? '🐶' : '🐱';
}

/// Copia de la mascota que viaja dentro de la solicitud.
class MascotaResumen {
  MascotaResumen({
    required this.nombre,
    required this.especie,
    this.raza = '',
    this.tamano = '',
    this.edadAnios,
    this.temperamento = const [],
    this.alertas = const [],
    this.notas = '',
    this.fotoUrl,
  });

  factory MascotaResumen.desde(Json d) => MascotaResumen(
    nombre: d['nombre'] as String? ?? '',
    especie: d['especie'] as String? ?? 'perro',
    raza: d['raza'] as String? ?? '',
    tamano: d['tamano'] as String? ?? '',
    edadAnios: d['edadAnios'] is num ? decimal(d['edadAnios']) : null,
    temperamento: textos(d['temperamento']),
    alertas: textos(d['alertas']),
    notas: d['notas'] as String? ?? '',
    fotoUrl: d['fotoUrl'] as String?,
  );

  final String nombre;
  final String especie;
  final String raza;
  final String tamano;
  final double? edadAnios;
  final List<String> temperamento;
  final List<String> alertas;
  final String notas;
  final String? fotoUrl;

  String get emoji => especie == 'perro' ? '🐶' : '🐱';
}

class Lugar {
  Lugar({required this.lat, required this.lng, this.direccion = ''});

  factory Lugar.desde(Json d) =>
      Lugar(lat: decimal(d['lat']), lng: decimal(d['lng']), direccion: d['direccion'] as String? ?? '');

  final double lat;
  final double lng;
  final String direccion;

  Json aJson() => {'lat': lat, 'lng': lng, 'direccion': direccion};
}

class RangoSugerido {
  RangoSugerido({required this.minimo, required this.maximo, required this.piso});

  factory RangoSugerido.desde(Json d) =>
      RangoSugerido(minimo: entero(d['minimo']), maximo: entero(d['maximo']), piso: entero(d['piso']));

  final int minimo;
  final int maximo;
  final int piso;
}

enum TipoServicio {
  paseo('Paseo'),
  visita('Visita a domicilio'),
  transporte('Transporte');

  const TipoServicio(this.nombre);
  final String nombre;

  static TipoServicio desde(Object? v) =>
      TipoServicio.values.firstWhere((t) => t.name == v, orElse: () => TipoServicio.paseo);
}

enum EstadoServicio {
  buscando,
  confirmado,
  enCurso,
  completado,
  cancelado,
  expirado;

  static EstadoServicio desde(Object? v) => switch (v) {
    'confirmado' => confirmado,
    'en_curso' => enCurso,
    'completado' => completado,
    'cancelado' => cancelado,
    'expirado' => expirado,
    _ => buscando,
  };

  bool get activo => this == buscando || this == confirmado || this == enCurso;
}

class ResumenServicio {
  ResumenServicio({
    required this.duracionRealMin,
    required this.distanciaKm,
    required this.precio,
    required this.metodoPago,
    required this.comision,
    required this.recibeCuidador,
    required this.fotos,
  });

  factory ResumenServicio.desde(Json d) => ResumenServicio(
    duracionRealMin: entero(d['duracionRealMin']),
    distanciaKm: decimal(d['distanciaKm']),
    precio: entero(d['precio']),
    metodoPago: d['metodoPago'] as String? ?? '',
    comision: entero(d['comision']),
    recibeCuidador: entero(d['recibeCuidador']),
    fotos: entero(d['fotos']),
  );

  final int duracionRealMin;
  final double distanciaKm;
  final int precio;
  final String metodoPago;
  final int comision;
  final int recibeCuidador;
  final int fotos;
}

class Servicio {
  Servicio({
    required this.id,
    required this.duenoId,
    required this.duenoNombre,
    required this.cuidadorId,
    required this.cuidadorNombre,
    required this.mascotaId,
    required this.mascota,
    required this.tipo,
    required this.modalidad,
    required this.duracionMin,
    required this.distanciaKm,
    required this.origen,
    required this.destino,
    required this.indicaciones,
    required this.metodoPago,
    required this.rangoSugerido,
    required this.precioOfrecido,
    required this.precioFinal,
    required this.estado,
    required this.ofertasRecibidas,
    required this.sugerenciaSubirPrecio,
    required this.creadoEn,
    required this.expiraEn,
    required this.iniciadoEn,
    required this.finalizadoEn,
    required this.resumen,
    required this.calificarHasta,
    required this.canceladoPor,
  });

  factory Servicio.desde(String id, Json d) => Servicio(
    id: id,
    duenoId: d['duenoId'] as String? ?? '',
    duenoNombre: d['duenoNombre'] as String? ?? '',
    cuidadorId: d['cuidadorId'] as String?,
    cuidadorNombre: d['cuidadorNombre'] as String?,
    mascotaId: d['mascotaId'] as String? ?? '',
    mascota: MascotaResumen.desde(mapa(d['mascota'])),
    tipo: TipoServicio.desde(d['tipo']),
    modalidad: d['modalidad'] as String? ?? 'oferta',
    duracionMin: entero(d['duracionMin']),
    distanciaKm: decimal(d['distanciaKm']),
    origen: Lugar.desde(mapa(d['origen'])),
    destino: d['destino'] is Map ? Lugar.desde(mapa(d['destino'])) : null,
    indicaciones: d['indicaciones'] as String? ?? '',
    metodoPago: d['metodoPago'] as String? ?? 'yape',
    rangoSugerido: d['rangoSugerido'] is Map ? RangoSugerido.desde(mapa(d['rangoSugerido'])) : null,
    precioOfrecido: entero(d['precioOfrecido']),
    precioFinal: d['precioFinal'] is num ? entero(d['precioFinal']) : null,
    estado: EstadoServicio.desde(d['estado']),
    ofertasRecibidas: entero(d['ofertasRecibidas']),
    sugerenciaSubirPrecio: d['sugerenciaSubirPrecioEnviada'] == true,
    creadoEn: fecha(d['creadoEn']),
    expiraEn: fecha(d['expiraEn']),
    iniciadoEn: fecha(d['iniciadoEn']),
    finalizadoEn: fecha(d['finalizadoEn']),
    resumen: d['resumen'] is Map ? ResumenServicio.desde(mapa(d['resumen'])) : null,
    calificarHasta: fecha(d['calificarHasta']),
    canceladoPor: d['canceladoPor'] as String?,
  );

  final String id;
  final String duenoId;
  final String duenoNombre;
  final String? cuidadorId;
  final String? cuidadorNombre;
  final String mascotaId;
  final MascotaResumen mascota;
  final TipoServicio tipo;
  final String modalidad; // oferta | paquete
  final int duracionMin;
  final double distanciaKm;
  final Lugar origen;
  final Lugar? destino;
  final String indicaciones;
  final String metodoPago;
  final RangoSugerido? rangoSugerido;
  final int precioOfrecido;
  final int? precioFinal;
  final EstadoServicio estado;
  final int ofertasRecibidas;
  final bool sugerenciaSubirPrecio;
  final DateTime? creadoEn;
  final DateTime? expiraEn;
  final DateTime? iniciadoEn;
  final DateTime? finalizadoEn;
  final ResumenServicio? resumen;
  final DateTime? calificarHasta;
  final String? canceladoPor;

  int get precio => precioFinal ?? precioOfrecido;
  bool get esPaquete => modalidad == 'paquete';
  bool get puedeCalificar =>
      estado == EstadoServicio.completado && calificarHasta != null && calificarHasta!.isAfter(DateTime.now());
}

class Oferta {
  Oferta({
    required this.cuidadorId,
    required this.nombre,
    this.fotoUrl,
    this.nivel = 'nuevo',
    this.calificacionPromedio = 0,
    this.numResenas = 0,
    required this.precio,
    this.esContraoferta = false,
    this.distanciaKm = 0,
    this.minutosLlegada = 0,
    required this.estado,
    required this.expiraEn,
    this.rechazadaPorDueno = false,
  });

  factory Oferta.desde(String id, Json d) => Oferta(
    cuidadorId: id,
    nombre: d['nombre'] as String? ?? '',
    fotoUrl: d['fotoUrl'] as String?,
    nivel: d['nivel'] as String? ?? 'nuevo',
    calificacionPromedio: decimal(d['calificacionPromedio']),
    numResenas: entero(d['numResenas']),
    precio: entero(d['precio']),
    esContraoferta: d['esContraoferta'] == true,
    distanciaKm: decimal(d['distanciaKm']),
    minutosLlegada: entero(d['minutosLlegada']),
    estado: d['estado'] as String? ?? 'pendiente',
    expiraEn: fecha(d['expiraEn']) ?? DateTime.now(),
    rechazadaPorDueno: d['rechazadaPorDueno'] == true,
  );

  final String cuidadorId;
  final String nombre;
  final String? fotoUrl;
  final String nivel;
  final double calificacionPromedio;
  final int numResenas;
  final int precio;
  final bool esContraoferta;
  final double distanciaKm;
  final int minutosLlegada;

  /// `true` si el dueño la rechazó con "Rechazar" (y no porque eligió otra).
  final bool rechazadaPorDueno;
  final String estado;
  final DateTime expiraEn;

  bool get vigente => estado == 'pendiente' && expiraEn.isAfter(DateTime.now());
}

/// Lo que devuelve `listarSolicitudesCercanas` (vista del cuidador).
class SolicitudCercana {
  SolicitudCercana({
    required this.id,
    required this.tipo,
    required this.modalidad,
    required this.mascota,
    required this.distanciaKm,
    required this.minutosLlegada,
    required this.duracionMin,
    required this.precioOfrecido,
    required this.metodoPago,
    required this.destino,
    required this.expiraEn,
  });

  factory SolicitudCercana.desde(Json d) => SolicitudCercana(
    id: d['id'] as String,
    tipo: TipoServicio.desde(d['tipo']),
    modalidad: d['modalidad'] as String? ?? 'oferta',
    mascota: MascotaResumen.desde(mapa(d['mascota'])),
    distanciaKm: decimal(d['distanciaKm']),
    minutosLlegada: entero(d['minutosLlegada']),
    duracionMin: entero(d['duracionMin']),
    precioOfrecido: entero(d['precioOfrecido']),
    metodoPago: d['metodoPago'] as String? ?? 'yape',
    destino: mapa(d['destino'])['direccion'] as String?,
    expiraEn: fecha(d['expiraEn']) ?? DateTime.now(),
  );

  final String id;
  final TipoServicio tipo;
  final String modalidad;
  final MascotaResumen mascota;
  final double distanciaKm;
  final int minutosLlegada;
  final int duracionMin;
  final int precioOfrecido;
  final String metodoPago;
  final String? destino;
  final DateTime expiraEn;

  bool get esPaquete => modalidad == 'paquete';
}

class Movimiento {
  Movimiento({
    required this.id,
    required this.tipo,
    required this.monto,
    required this.descripcion,
    this.mascotaNombre,
    this.creadoEn,
  });

  factory Movimiento.desde(String id, Json d) => Movimiento(
    id: id,
    tipo: d['tipo'] as String? ?? 'ajuste',
    monto: entero(d['monto']),
    descripcion: d['descripcion'] as String? ?? '',
    mascotaNombre: d['mascotaNombre'] as String?,
    creadoEn: fecha(d['creadoEn']),
  );

  final String id;
  final String tipo; // recarga | comision | devolucion | ajuste
  final int monto; // con signo
  final String descripcion;
  final String? mascotaNombre;
  final DateTime? creadoEn;
}

class Verificacion {
  Verificacion({required this.estado, required this.documentos, this.motivoRechazo});

  factory Verificacion.desde(Json d) => Verificacion(
    estado: d['estado'] as String? ?? 'incompleta',
    documentos: mapa(d['documentos']).map((k, v) => MapEntry(k, '$v')),
    motivoRechazo: d['motivoRechazo'] as String?,
  );

  final String estado; // incompleta | en_revision | aprobada | rechazada | revocada
  final Map<String, String> documentos; // pendiente | subido | aprobado | rechazado
  final String? motivoRechazo;
}

class Chat {
  Chat({
    required this.id,
    required this.participantes,
    required this.abierto,
    this.cierraEn,
    this.noLeidos = const {},
    this.ultimoMensaje,
    this.actualizadoEn,
  });

  factory Chat.desde(String id, Json d) => Chat(
    id: id,
    participantes: textos(d['participantes']),
    abierto: d['abierto'] == true,
    cierraEn: fecha(d['cierraEn']),
    noLeidos: mapa(d['noLeidos']).map((k, v) => MapEntry(k, entero(v))),
    ultimoMensaje: mapa(d['ultimoMensaje'])['texto'] as String?,
    actualizadoEn: fecha(d['actualizadoEn']) ?? fecha(d['creadoEn']),
  );

  final String id; // = servicioId
  final List<String> participantes;
  final bool abierto;
  final DateTime? cierraEn;
  final Map<String, int> noLeidos;
  final String? ultimoMensaje;
  final DateTime? actualizadoEn;

  bool get puedeEscribir => abierto && (cierraEn == null || cierraEn!.isAfter(DateTime.now()));
}

class Mensaje {
  Mensaje({required this.id, required this.autorId, required this.tipo, required this.texto, this.ruta, this.creadoEn});

  factory Mensaje.desde(String id, Json d) => Mensaje(
    id: id,
    autorId: d['autorId'] as String? ?? '',
    tipo: d['tipo'] as String? ?? 'texto',
    texto: d['texto'] as String? ?? '',
    ruta: d['ruta'] as String?,
    creadoEn: fecha(d['creadoEn']),
  );

  final String id;
  final String autorId;
  final String tipo; // texto | foto
  final String texto;
  final String? ruta;
  final DateTime? creadoEn;
}

class FotoServicio {
  FotoServicio({required this.id, required this.ruta, this.creadoEn});

  factory FotoServicio.desde(String id, Json d) =>
      FotoServicio(id: id, ruta: d['ruta'] as String? ?? '', creadoEn: fecha(d['creadoEn']));

  final String id;
  final String ruta;
  final DateTime? creadoEn;
}

class Anuncio {
  Anuncio({required this.id, required this.titulo, required this.vigencia, this.url});

  factory Anuncio.desde(String id, Json d) => Anuncio(
    id: id,
    titulo: d['titulo'] as String? ?? '',
    vigencia: d['vigencia'] as String? ?? '',
    url: d['url'] as String?,
  );

  final String id;
  final String titulo;
  final String vigencia;
  final String? url;
}

/// Reseña pública de un cuidador: `perfilesPublicos/{uid}/resenas/{servicioId}`.
/// La escribe el backend al revelar las calificaciones (HU-24).
class Resena {
  Resena({
    required this.id,
    required this.autorNombre,
    this.autorFotoUrl,
    required this.estrellas,
    this.etiquetas = const [],
    this.comentario = '',
    this.tipoServicio,
    this.mascotaNombre,
    this.creadoEn,
  });

  factory Resena.desde(String id, Json d) => Resena(
    id: id,
    autorNombre: d['autorNombre'] as String? ?? 'Dueño de Mican',
    autorFotoUrl: d['autorFotoUrl'] as String?,
    estrellas: entero(d['estrellas']).clamp(1, 5),
    etiquetas: textos(d['etiquetas']),
    comentario: d['comentario'] as String? ?? '',
    tipoServicio: d['tipoServicio'] == null ? null : TipoServicio.desde(d['tipoServicio']),
    mascotaNombre: d['mascotaNombre'] as String?,
    creadoEn: fecha(d['creadoEn']),
  );

  final String id;
  final String autorNombre;
  final String? autorFotoUrl;
  final int estrellas;
  final List<String> etiquetas;
  final String comentario;
  final TipoServicio? tipoServicio;
  final String? mascotaNombre;
  final DateTime? creadoEn;

  /// "Paseo con Rocky", "Visita a domicilio" o vacío.
  String get contexto {
    final t = tipoServicio?.nombre;
    if (t == null) return '';
    return mascotaNombre == null || mascotaNombre!.isEmpty ? t : '$t con $mascotaNombre';
  }
}
