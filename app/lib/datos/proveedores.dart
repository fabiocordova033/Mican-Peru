import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/entorno.dart';
import 'api.dart';
import 'archivos.dart';
import 'modelos.dart';
import 'ubicacion.dart';

// ---------------------------------------------------------------------------
// Firebase
// ---------------------------------------------------------------------------

final authProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final storageProvider = Provider<FirebaseStorage>((ref) => FirebaseStorage.instance);
final apiProvider = Provider<MicanApi>(
  (ref) => MicanApi(FirebaseFunctions.instanceFor(region: Entorno.regionFunciones)),
);
final ubicacionProvider = Provider<ServicioUbicacion>((ref) => ServicioUbicacion());

// ---------------------------------------------------------------------------
// Sesión
// ---------------------------------------------------------------------------

final sesionProvider = StreamProvider<User?>((ref) => ref.watch(authProvider).authStateChanges());

final uidProvider = Provider<String?>((ref) => ref.watch(sesionProvider).value?.uid);

/// `usuarios/{uid}`. Es `null` si el usuario verificó su celular pero aún no
/// completó el registro (términos, fecha de nacimiento, rol).
final usuarioProvider = StreamProvider<Usuario?>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .doc('usuarios/$uid')
      .snapshots()
      .map((s) => s.exists ? Usuario.desde(uid, s.data()!) : null);
});

final perfilProvider = StreamProvider.family<Perfil?, String>((ref, uid) {
  return ref
      .watch(firestoreProvider)
      .doc('perfilesPublicos/$uid')
      .snapshots()
      .map((s) => s.exists ? Perfil.desde(uid, s.data()!) : null);
});

final miPerfilProvider = Provider<AsyncValue<Perfil?>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return const AsyncData(null);
  return ref.watch(perfilProvider(uid));
});

// ---------------------------------------------------------------------------
// Dueño
// ---------------------------------------------------------------------------

final mascotasProvider = StreamProvider<List<Mascota>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('mascotas')
      .where('duenoId', isEqualTo: uid)
      .where('activa', isEqualTo: true)
      .snapshots()
      .map((q) => q.docs.map((d) => Mascota.desde(d.id, d.data())).toList());
});

final mascotaProvider = Provider.family<Mascota?, String>((ref, id) {
  final lista = ref.watch(mascotasProvider).value ?? const [];
  for (final m in lista) {
    if (m.id == id) return m;
  }
  return null;
});

/// Servicios del dueño. Sin Premium, las reglas solo permiten leer los
/// últimos 30 días, así que la consulta filtra por `creadoEn` (HU-20).
final serviciosDuenoProvider = StreamProvider<List<Servicio>>((ref) {
  final uid = ref.watch(uidProvider);
  final premium = ref.watch(usuarioProvider).value?.esPremium ?? false;
  if (uid == null) return Stream.value(const []);
  Query<Json> q = ref
      .watch(firestoreProvider)
      .collection('servicios')
      .where('duenoId', isEqualTo: uid)
      .orderBy('creadoEn', descending: true);
  if (!premium) {
    q = q.where('creadoEn', isGreaterThan: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 30))));
  }
  return q.limit(50).snapshots().map((s) => s.docs.map((d) => Servicio.desde(d.id, d.data())).toList());
});

final serviciosCuidadorProvider = StreamProvider<List<Servicio>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('servicios')
      .where('cuidadorId', isEqualTo: uid)
      .orderBy('creadoEn', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map((d) => Servicio.desde(d.id, d.data())).toList());
});

final servicioProvider = StreamProvider.family<Servicio?, String>((ref, id) {
  return ref
      .watch(firestoreProvider)
      .doc('servicios/$id')
      .snapshots()
      .map((s) => s.exists ? Servicio.desde(s.id, s.data()!) : null);
});

final ofertasProvider = StreamProvider.family<List<Oferta>, String>((ref, servicioId) {
  return ref
      .watch(firestoreProvider)
      .collection('servicios/$servicioId/ofertas')
      .where('estado', isEqualTo: 'pendiente')
      .snapshots()
      .map(
        (q) => q.docs.map((d) => Oferta.desde(d.id, d.data())).toList()..sort((a, b) => a.precio.compareTo(b.precio)),
      );
});

/// La oferta del cuidador actual en una solicitud (cada cuidador ve solo la suya).
final miOfertaProvider = StreamProvider.family<Oferta?, String>((ref, servicioId) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .doc('servicios/$servicioId/ofertas/$uid')
      .snapshots()
      .map((s) => s.exists ? Oferta.desde(s.id, s.data()!) : null);
});

final rutaProvider = StreamProvider.family<List<Lugar>, String>((ref, servicioId) {
  return ref
      .watch(firestoreProvider)
      .collection('servicios/$servicioId/ruta')
      .orderBy('registradoEn')
      .snapshots()
      .map((q) => q.docs.map((d) => Lugar.desde(d.data())).toList());
});

final fotosServicioProvider = StreamProvider.family<List<FotoServicio>, String>((ref, servicioId) {
  return ref
      .watch(firestoreProvider)
      .collection('servicios/$servicioId/fotos')
      .orderBy('creadoEn')
      .snapshots()
      .map((q) => q.docs.map((d) => FotoServicio.desde(d.id, d.data())).toList());
});

/// URL de descarga de una ruta de Storage (fotos del servicio).
final urlFotoProvider = FutureProvider.family<String, String>(
  (ref, ruta) => ref.watch(storageProvider).ref(ruta).getDownloadURL(),
);

/// Teléfonos de ambos (visibles desde que se confirma hasta 24 h después).
final contactoProvider = StreamProvider.family<Json?, String>((ref, servicioId) {
  return ref
      .watch(firestoreProvider)
      .doc('servicios/$servicioId/privado/contacto')
      .snapshots()
      .map((s) => s.data())
      .handleError((_) {});
});

/// Mi calificación de un servicio (para no pedir calificar dos veces).
final miCalificacionProvider = StreamProvider.family<bool, String>((ref, servicioId) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(false);
  return ref.watch(firestoreProvider).doc('servicios/$servicioId/calificaciones/$uid').snapshots().map((s) => s.exists);
});

// ---------------------------------------------------------------------------
// Cuidador
// ---------------------------------------------------------------------------

final saldoProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(0);
  return ref.watch(firestoreProvider).doc('billeteras/$uid').snapshots().map((s) => entero(s.data()?['saldo']));
});

final movimientosProvider = StreamProvider<List<Movimiento>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('billeteras/$uid/movimientos')
      .orderBy('creadoEn', descending: true)
      .limit(30)
      .snapshots()
      .map((q) => q.docs.map((d) => Movimiento.desde(d.id, d.data())).toList());
});

final verificacionProvider = StreamProvider<Verificacion?>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .doc('verificaciones/$uid')
      .snapshots()
      .map((s) => s.exists ? Verificacion.desde(s.data()!) : null);
});

// ---------------------------------------------------------------------------
// Chat y anuncios
// ---------------------------------------------------------------------------

final chatsProvider = StreamProvider<List<Chat>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(firestoreProvider).collection('chats').where('participantes', arrayContains: uid).snapshots().map((
    q,
  ) {
    final chats = q.docs.map((d) => Chat.desde(d.id, d.data())).toList();
    chats.sort((a, b) => (b.actualizadoEn ?? DateTime(0)).compareTo(a.actualizadoEn ?? DateTime(0)));
    return chats;
  });
});

final noLeidosProvider = Provider<int>((ref) {
  final uid = ref.watch(uidProvider);
  final chats = ref.watch(chatsProvider).value ?? const [];
  return chats.fold(0, (t, c) => t + (c.noLeidos[uid] ?? 0));
});

final mensajesProvider = StreamProvider.family<List<Mensaje>, String>((ref, chatId) {
  return ref
      .watch(firestoreProvider)
      .collection('chats/$chatId/mensajes')
      .orderBy('creadoEn', descending: true)
      .limit(100)
      .snapshots()
      .map((q) => q.docs.map((d) => Mensaje.desde(d.id, d.data())).toList());
});

final anunciosProvider = StreamProvider<List<Anuncio>>((ref) {
  if (ref.watch(uidProvider) == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('anuncios')
      .limit(5)
      .snapshots()
      .map((q) => q.docs.map((d) => Anuncio.desde(d.id, d.data())).toList())
      .handleError((_) {});
});

final archivosProvider = Provider<Archivos>((ref) => Archivos(ref.watch(storageProvider)));
