import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Subidas a Cloud Storage (ver storage.rules). Las imágenes se comprimen
/// en el celular antes de subir para ahorrar datos.
class Archivos {
  Archivos(this._storage);

  final FirebaseStorage _storage;
  final _picker = ImagePicker();

  Future<XFile?> elegirImagen({bool camara = true}) =>
      _picker.pickImage(source: camara ? ImageSource.camera : ImageSource.gallery, maxWidth: 1600, imageQuality: 80);

  Future<String> _subir(String ruta, XFile archivo, String tipo) async {
    final ref = _storage.ref(ruta);
    await ref.putFile(File(archivo.path), SettableMetadata(contentType: tipo));
    return ruta;
  }

  String _tipoImagen(XFile f) => f.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

  /// HU-17: foto durante el servicio. Un trigger la agrega al servicio y al chat.
  Future<String?> fotoServicio(String servicioId, {bool camara = true}) async {
    final f = await elegirImagen(camara: camara);
    if (f == null) return null;
    final nombre = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    return _subir('servicios/$servicioId/fotos/$nombre', f, _tipoImagen(f));
  }

  /// HU-03: documento de verificación (dniFrente, dniReverso, antecedentes, selfie, cv).
  Future<String?> documentoVerificacion(String uid, String tipo, {bool camara = true}) async {
    final f = await elegirImagen(camara: camara);
    if (f == null) return null;
    final ext = f.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    return _subir('verificaciones/$uid/$tipo.$ext', f, _tipoImagen(f));
  }

  /// Foto de mascota o de perfil. Devuelve la URL pública de descarga.
  Future<String?> fotoUsuario(String uid, String carpeta, {bool camara = false}) async {
    final f = await elegirImagen(camara: camara);
    if (f == null) return null;
    final ruta = 'usuarios/$uid/$carpeta/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _subir(ruta, f, _tipoImagen(f));
    return _storage.ref(ruta).getDownloadURL();
  }
}
