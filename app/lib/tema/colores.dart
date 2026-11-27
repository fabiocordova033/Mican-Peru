import 'package:flutter/material.dart';

/// Variables de color de Figma (página "02 · Componentes" → Fundamentos).
/// Los nombres siguen la ruta del token: `fondo/app` → [MicanColores.fondoApp].
abstract final class MicanColores {
  // Fondo y superficies
  static const fondoApp = Color(0xFFC3D9E0);
  static const fondoAppSuave = Color(0xFFE3EEF2);
  static const superficieTarjeta = Color(0xFFFFFFFF);
  static const superficieGris = Color(0xFFE6ECEF);

  // Marca
  static const primario = Color(0xFF1F6F82);
  static const primarioOscuro = Color(0xFF164F5D);
  static const primarioSuave = Color(0xFFD3E7ED);
  static const acento = Color(0xFFF28C38);
  static const acentoSuave = Color(0xFFFDE6D3);

  // Estado
  static const exito = Color(0xFF2E9D6A);
  static const exitoSuave = Color(0xFFD8F1E4);
  static const alerta = Color(0xFFE0A800);
  static const error = Color(0xFFD64545);
  static const errorSuave = Color(0xFFFCE5E5);
  static const errorSuaveTarjeta = Color(0xFFFCEBEB);

  // Texto
  static const textoPrincipal = Color(0xFF17262D);
  static const textoSecundario = Color(0xFF5A6E77);
  static const textoInvertido = Color(0xFFFFFFFF);

  // Bordes
  static const bordeFuerte = Color(0xFF17262D);
  static const bordeSuave = Color(0xFFB4CAD2);

  // Mapa ilustrativo
  static const mapaFondo = Color(0xFFDEEBED);
  static const mapaParque = Color(0xFFCFE6D2);
  static const mapaAgua = Color(0xFFBFDCEB);
  static const tuUbicacion = Color(0xFF3380F2);
}

/// Efectos de Figma: "Mican/Sombra tarjeta" y "Mican/Sombra flotante".
abstract final class MicanSombras {
  static const tarjeta = [BoxShadow(color: Color(0x1A17262E), offset: Offset(0, 4), blurRadius: 14)];
  static const flotante = [BoxShadow(color: Color(0x2E17262E), offset: Offset(0, -2), blurRadius: 20)];
}

/// Radios y espacios que se repiten en las pantallas de alta fidelidad.
abstract final class MicanMedidas {
  static const radioTarjeta = 20.0;
  static const radioIcono = 12.0;
  static const radioAviso = 14.0;
  static const radioPildora = 999.0;
  static const margen = 16.0;
}
