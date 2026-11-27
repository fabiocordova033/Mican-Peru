import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../datos/modelos.dart';
import '../../datos/proveedores.dart';

class EstadoLogin {
  const EstadoLogin({
    this.rol = Rol.dueno,
    this.telefono = '',
    this.verificationId,
    this.reenvio,
    this.enviadoEn,
    this.enviando = false,
    this.intentosFallidos = 0,
    this.error,
  });

  final Rol rol;
  final String telefono; // 9 dígitos, sin +51
  final String? verificationId;
  final int? reenvio;
  final DateTime? enviadoEn;
  final bool enviando;
  final int intentosFallidos;
  final String? error;

  String get e164 => '+51$telefono';

  EstadoLogin copiar({
    Rol? rol,
    String? telefono,
    String? verificationId,
    int? reenvio,
    DateTime? enviadoEn,
    bool? enviando,
    int? intentosFallidos,
    String? error,
    bool limpiarError = false,
  }) => EstadoLogin(
    rol: rol ?? this.rol,
    telefono: telefono ?? this.telefono,
    verificationId: verificationId ?? this.verificationId,
    reenvio: reenvio ?? this.reenvio,
    enviadoEn: enviadoEn ?? this.enviadoEn,
    enviando: enviando ?? this.enviando,
    intentosFallidos: intentosFallidos ?? this.intentosFallidos,
    error: limpiarError ? null : (error ?? this.error),
  );
}

/// HU-01: registro e inicio de sesión con celular peruano y código SMS.
class LoginNotifier extends Notifier<EstadoLogin> {
  @override
  EstadoLogin build() => const EstadoLogin();

  void elegirRol(Rol rol) => state = state.copiar(rol: rol);

  /// Envía el SMS. Completa cuando el código fue enviado (o el usuario
  /// quedó autenticado automáticamente en Android).
  Future<void> enviarCodigo(String telefono) async {
    state = state.copiar(telefono: telefono, enviando: true, limpiarError: true, intentosFallidos: 0);
    final listo = Completer<void>();
    await ref
        .read(authProvider)
        .verifyPhoneNumber(
          phoneNumber: '+51$telefono',
          forceResendingToken: state.telefono == telefono ? state.reenvio : null,
          timeout: const Duration(seconds: 60),
          verificationCompleted: (credencial) async {
            await ref.read(authProvider).signInWithCredential(credencial);
            if (!listo.isCompleted) listo.complete();
          },
          verificationFailed: (e) {
            state = state.copiar(enviando: false, error: _mensaje(e));
            if (!listo.isCompleted) listo.completeError(state.error!);
          },
          codeSent: (id, reenvio) {
            state = state.copiar(verificationId: id, reenvio: reenvio, enviadoEn: DateTime.now(), enviando: false);
            if (!listo.isCompleted) listo.complete();
          },
          codeAutoRetrievalTimeout: (id) => state = state.copiar(verificationId: id),
        );
    return listo.future;
  }

  Future<bool> verificar(String codigo) async {
    final id = state.verificationId;
    if (id == null) return false;
    try {
      await ref
          .read(authProvider)
          .signInWithCredential(PhoneAuthProvider.credential(verificationId: id, smsCode: codigo));
      state = state.copiar(limpiarError: true);
      return true;
    } on FirebaseAuthException catch (e) {
      final fallidos = state.intentosFallidos + 1;
      final quedan = 3 - fallidos;
      state = state.copiar(
        intentosFallidos: fallidos,
        error: e.code == 'invalid-verification-code'
            ? (quedan > 0
                  ? 'Código incorrecto. Te queda${quedan == 1 ? '' : 'n'} $quedan intento${quedan == 1 ? '' : 's'}.'
                  : 'Código incorrecto. Pide un código nuevo.')
            : _mensaje(e),
      );
      return false;
    }
  }

  String _mensaje(FirebaseAuthException e) => switch (e.code) {
    'invalid-phone-number' => 'Usa un celular peruano de 9 dígitos que empiece con 9.',
    'too-many-requests' => 'Demasiados intentos. Espera unos minutos.',
    'session-expired' => 'El código venció. Pide uno nuevo.',
    'network-request-failed' => 'Sin conexión. Revisa tu internet.',
    _ => e.message ?? 'No pudimos enviar el código.',
  };
}

final loginProvider = NotifierProvider<LoginNotifier, EstadoLogin>(LoginNotifier.new);
