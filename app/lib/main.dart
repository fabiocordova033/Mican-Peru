import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'config/entorno.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (Entorno.usarEmuladores) _conectarEmuladores();
  runApp(const ProviderScope(child: AppMican()));
}

/// Puertos de firebase.json (auth 9099, functions 5001, firestore 8080, storage 9199).
void _conectarEmuladores() {
  const host = Entorno.hostEmulador;
  FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  FirebaseFunctions.instanceFor(region: Entorno.regionFunciones).useFunctionsEmulator(host, 5001);
  FirebaseStorage.instance.useStorageEmulator(host, 9199);
}
