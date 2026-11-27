import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/entorno.dart';
import 'datos/proveedores.dart';
import 'rutas.dart';
import 'tema/tema.dart';

class AppMican extends ConsumerWidget {
  const AppMican({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Registra el token de notificaciones al iniciar sesión.
    ref.listen(uidProvider, (_, uid) {
      if (uid != null) _registrarDispositivo(ref, uid);
    });
    return MaterialApp.router(
      title: 'Mican',
      debugShowCheckedModeBanner: false,
      theme: temaMican(),
      routerConfig: ref.watch(rutasProvider),
      locale: const Locale('es', 'PE'),
      supportedLocales: const [Locale('es', 'PE'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}

/// Guarda el token FCM en `usuarios/{uid}/dispositivos/{token}` para que las
/// Cloud Functions puedan notificar ofertas, aceptaciones y fotos.
Future<void> _registrarDispositivo(WidgetRef ref, String uid) async {
  // Con emuladores no hay FCM real (no hay google-services.json).
  if (Entorno.usarEmuladores) return;
  try {
    final fcm = FirebaseMessaging.instance;
    await fcm.requestPermission();
    // ignore: deprecated_member_use
    final token = await fcm.getToken();
    if (token == null) return;
    await ref.read(firestoreProvider).doc('usuarios/$uid/dispositivos/$token').set({
      'plataforma': Platform.isIOS ? 'ios' : 'android',
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  } catch (_) {
    // Sin permiso o sin Google Play Services: la app funciona sin notificaciones.
  }
}
