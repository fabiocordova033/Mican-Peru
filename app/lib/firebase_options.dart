// Opciones de Firebase.
//
// Para un proyecto real, reemplaza este archivo con `flutterfire configure`
// (crea google-services.json y GoogleService-Info.plist). Mientras tanto,
// con los emuladores bastan valores de relleno: el SDK no los valida.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'config/entorno.dart';

abstract final class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => FirebaseOptions(
    apiKey: const String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'clave-de-relleno-para-emuladores'),
    appId: defaultTargetPlatform == TargetPlatform.iOS
        ? const String.fromEnvironment('FIREBASE_APP_ID_IOS', defaultValue: '1:000000000000:ios:0000000000000000')
        : const String.fromEnvironment(
            'FIREBASE_APP_ID_ANDROID',
            defaultValue: '1:000000000000:android:0000000000000000',
          ),
    messagingSenderId: const String.fromEnvironment('FIREBASE_SENDER_ID', defaultValue: '000000000000'),
    projectId: Entorno.proyectoFirebase,
    storageBucket: '${Entorno.proyectoFirebase}.appspot.com',
    iosBundleId: 'pe.mican.mican',
  );
}
