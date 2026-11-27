import 'package:flutter/material.dart';

import 'colores.dart';

/// Estilos de texto de Figma (Tipografía · Nunito).
abstract final class MicanTexto {
  static const _base = TextStyle(fontFamily: 'Nunito', color: MicanColores.textoPrincipal, letterSpacing: 0);

  /// Display — 28/34 ExtraBold
  static final display = _base.copyWith(fontSize: 28, height: 34 / 28, fontWeight: FontWeight.w800);

  /// Título 1 — 22/28 Bold
  static final titulo1 = _base.copyWith(fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w700);

  /// Título 2 — 18/24 Bold
  static final titulo2 = _base.copyWith(fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w700);

  /// Subtítulo — 16/22 SemiBold
  static final subtitulo = _base.copyWith(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w600);

  /// Cuerpo — 15/21 Regular
  static final cuerpo = _base.copyWith(fontSize: 15, height: 21 / 15, fontWeight: FontWeight.w400);

  /// Cuerpo fuerte — 15/21 Bold
  static final cuerpoFuerte = _base.copyWith(fontSize: 15, height: 21 / 15, fontWeight: FontWeight.w700);

  /// Etiqueta — 13/18 SemiBold
  static final etiqueta = _base.copyWith(fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w600);

  /// Leyenda — 12/16 Regular
  static final leyenda = _base.copyWith(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    color: MicanColores.textoSecundario,
  );

  /// Botón — 16/20 Bold
  static final boton = _base.copyWith(fontSize: 16, height: 20 / 16, fontWeight: FontWeight.w700);

  /// Nav — 11/14 SemiBold
  static final nav = _base.copyWith(fontSize: 11, height: 14 / 11, fontWeight: FontWeight.w600);

  /// Logotipo "mican" — 28 Black
  static final logotipo = _base.copyWith(fontSize: 28, fontWeight: FontWeight.w900, color: MicanColores.primario);
}
