import 'package:flutter/material.dart';

import '../componentes/base.dart';
import '../datos/api.dart';
import '../tema/colores.dart';
import '../tema/tipografia.dart';

String mensajeDeError(Object e) {
  if (e is ErrorMican) return e.mensaje;
  final t = e.toString();
  if (t.contains('network') || t.contains('unavailable')) return 'Sin conexión. Revisa tu internet.';
  if (t.contains('permission-denied')) return 'No tienes permiso para ver esto.';
  return 'Algo salió mal. Inténtalo de nuevo.';
}

void avisar(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}

void mostrarError(BuildContext context, Object e) => avisar(context, mensajeDeError(e));

/// Ejecuta una acción y muestra el error en un aviso si falla.
/// Devuelve `true` si terminó bien.
Future<bool> intentar(BuildContext context, Future<void> Function() accion) async {
  try {
    await accion();
    return true;
  } catch (e) {
    if (context.mounted) mostrarError(context, e);
    return false;
  }
}

/// Hoja inferior con el estilo de "Hoja de emergencia".
Future<T?> mostrarHoja<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: MicanColores.superficieTarjeta,
    barrierColor: const Color(0x8C0D1A1F),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(color: MicanColores.bordeSuave, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(height: 14),
            builder(c),
          ],
        ),
      ),
    ),
  );
}

/// Confirmación simple con dos botones.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String texto,
  String si = 'Sí, continuar',
  String no = 'Mejor no',
  bool peligro = false,
}) async {
  final r = await mostrarHoja<bool>(
    context,
    builder: (c) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(titulo, style: MicanTexto.titulo1, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          texto,
          style: MicanTexto.cuerpo.copyWith(color: MicanColores.textoSecundario),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Boton(si, tipo: peligro ? TipoBoton.peligro : TipoBoton.primario, alPresionar: () => Navigator.pop(c, true)),
        const SizedBox(height: 10),
        Boton(no, tipo: TipoBoton.fantasma, alPresionar: () => Navigator.pop(c, false)),
      ],
    ),
  );
  return r ?? false;
}

/// Pide un texto en una hoja (p. ej. motivo de cancelación, monto "Otro").
Future<String?> pedirTexto(
  BuildContext context, {
  required String titulo,
  required String etiqueta,
  String? pista,
  TextInputType? teclado,
  String boton = 'Continuar',
  String? prefijo,
}) {
  final c = TextEditingController();
  return mostrarHoja<String>(
    context,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(titulo, style: MicanTexto.titulo2),
        const SizedBox(height: 14),
        CampoTexto(etiqueta: etiqueta, controlador: c, pista: pista, teclado: teclado, prefijo: prefijo),
        const SizedBox(height: 18),
        Boton(boton, alPresionar: () => Navigator.pop(ctx, c.text.trim())),
      ],
    ),
  );
}
