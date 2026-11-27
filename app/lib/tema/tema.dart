import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'colores.dart';
import 'tipografia.dart';

ThemeData temaMican() {
  final esquema = ColorScheme.fromSeed(
    seedColor: MicanColores.primario,
    primary: MicanColores.primario,
    secondary: MicanColores.acento,
    error: MicanColores.error,
    surface: MicanColores.superficieTarjeta,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    fontFamily: 'Nunito',
    scaffoldBackgroundColor: MicanColores.fondoApp,
    textTheme: TextTheme(
      displaySmall: MicanTexto.display,
      headlineSmall: MicanTexto.titulo1,
      titleLarge: MicanTexto.titulo2,
      titleMedium: MicanTexto.subtitulo,
      bodyLarge: MicanTexto.cuerpo,
      bodyMedium: MicanTexto.cuerpo,
      labelLarge: MicanTexto.boton,
      labelMedium: MicanTexto.etiqueta,
      bodySmall: MicanTexto.leyenda,
    ),
    appBarTheme: const AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: MicanColores.textoPrincipal,
      contentTextStyle: MicanTexto.cuerpo.copyWith(color: MicanColores.textoInvertido),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: MicanColores.superficieTarjeta,
      showDragHandle: false,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: MicanColores.primario),
  );
}
