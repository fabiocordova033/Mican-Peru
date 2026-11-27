import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../tema/colores.dart';
import '../tema/iconos.dart';
import '../tema/tipografia.dart';

// ---------------------------------------------------------------------------
// Botón (componente "Botón": Primario, Acento, Contorno, Fantasma)
// ---------------------------------------------------------------------------

enum TipoBoton { primario, acento, contorno, fantasma, peligro }

class Boton extends StatelessWidget {
  const Boton(
    this.texto, {
    super.key,
    required this.alPresionar,
    this.tipo = TipoBoton.primario,
    this.cargando = false,
    this.icono,
    this.expandido = true,
  });

  final String texto;
  final VoidCallback? alPresionar;
  final TipoBoton tipo;
  final bool cargando;
  final MicanIcono? icono;
  final bool expandido;

  @override
  Widget build(BuildContext context) {
    final (fondo, textoColor, borde) = switch (tipo) {
      TipoBoton.primario => (MicanColores.primario, MicanColores.textoInvertido, null),
      TipoBoton.acento => (MicanColores.acento, MicanColores.textoInvertido, null),
      TipoBoton.contorno => (MicanColores.superficieTarjeta, MicanColores.primario, MicanColores.primario),
      TipoBoton.fantasma => (Colors.transparent, MicanColores.primario, null),
      TipoBoton.peligro => (MicanColores.superficieTarjeta, MicanColores.error, MicanColores.error),
    };
    final deshabilitado = alPresionar == null && !cargando;
    final contenido = cargando
        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: textoColor))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icono != null) ...[Icono(icono!, tamano: 20, color: textoColor), const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  texto,
                  style: MicanTexto.boton.copyWith(color: textoColor),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );
    return Opacity(
      opacity: deshabilitado ? 0.5 : 1,
      child: Material(
        color: fondo,
        shape: StadiumBorder(side: borde == null ? BorderSide.none : BorderSide(color: borde, width: 1.5)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: cargando ? null : alPresionar,
          child: Container(
            height: 50,
            width: expandido ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            alignment: Alignment.center,
            child: contenido,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chip / Etiqueta
// ---------------------------------------------------------------------------

class ChipEtiqueta extends StatelessWidget {
  const ChipEtiqueta(this.texto, {super.key, this.seleccionado = false, this.alPresionar});

  final String texto;
  final bool seleccionado;
  final VoidCallback? alPresionar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: seleccionado ? MicanColores.primario : MicanColores.superficieTarjeta,
      shape: StadiumBorder(side: BorderSide(color: seleccionado ? MicanColores.primario : MicanColores.bordeSuave)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alPresionar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            texto,
            style: MicanTexto.etiqueta.copyWith(
              color: seleccionado ? MicanColores.textoInvertido : MicanColores.textoPrincipal,
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila de chips con selección única o múltiple.
class GrupoChips<T> extends StatelessWidget {
  const GrupoChips({
    super.key,
    required this.opciones,
    required this.etiqueta,
    required this.seleccionados,
    required this.alCambiar,
  });

  final List<T> opciones;
  final String Function(T) etiqueta;
  final Set<T> seleccionados;
  final ValueChanged<T> alCambiar;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in opciones)
          ChipEtiqueta(etiqueta(o), seleccionado: seleccionados.contains(o), alPresionar: () => alCambiar(o)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Campo de texto
// ---------------------------------------------------------------------------

class CampoTexto extends StatelessWidget {
  const CampoTexto({
    super.key,
    required this.etiqueta,
    this.controlador,
    this.pista,
    this.teclado,
    this.lineas = 1,
    this.maxCaracteres,
    this.alCambiar,
    this.prefijo,
    this.soloLectura = false,
    this.alPresionar,
    this.mayusculas = TextCapitalization.sentences,
  });

  final String etiqueta;
  final TextEditingController? controlador;
  final String? pista;
  final TextInputType? teclado;
  final int lineas;
  final int? maxCaracteres;
  final ValueChanged<String>? alCambiar;
  final String? prefijo;
  final bool soloLectura;
  final VoidCallback? alPresionar;
  final TextCapitalization mayusculas;

  @override
  Widget build(BuildContext context) {
    final multilinea = lineas > 1;
    final borde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(multilinea ? 18 : MicanMedidas.radioPildora),
      borderSide: BorderSide(
        color: multilinea ? MicanColores.bordeSuave : MicanColores.bordeFuerte,
        width: multilinea ? 1 : 1.2,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: MicanTexto.etiqueta),
        const SizedBox(height: 6),
        TextField(
          controller: controlador,
          keyboardType: teclado,
          minLines: lineas,
          maxLines: lineas,
          maxLength: maxCaracteres,
          onChanged: alCambiar,
          readOnly: soloLectura,
          onTap: alPresionar,
          textCapitalization: mayusculas,
          style: MicanTexto.cuerpo,
          decoration: InputDecoration(
            hintText: pista,
            hintStyle: MicanTexto.cuerpo.copyWith(color: MicanColores.textoSecundario),
            prefixText: prefijo,
            prefixStyle: MicanTexto.cuerpo,
            filled: true,
            fillColor: MicanColores.superficieTarjeta,
            isDense: true,
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            border: borde,
            enabledBorder: borde,
            focusedBorder: borde.copyWith(borderSide: const BorderSide(color: MicanColores.primario, width: 2)),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Insignias, calificación y avatar
// ---------------------------------------------------------------------------

class Pildora extends StatelessWidget {
  const Pildora({
    super.key,
    required this.texto,
    required this.fondo,
    required this.color,
    this.icono,
    this.estrella = false,
    this.compacta = false,
  });

  final String texto;
  final Color fondo;
  final Color color;
  final MicanIcono? icono;
  final bool estrella;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(icono != null || estrella ? 8 : 10, compacta ? 3 : 4, 10, compacta ? 3 : 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(MicanMedidas.radioPildora)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[Icono(icono!, tamano: compacta ? 14 : 16, color: color), const SizedBox(width: 4)],
          if (estrella) ...[Icono(MicanIcono.estrella, tamano: 14, color: color), const SizedBox(width: 4)],
          Text(texto, style: (compacta ? MicanTexto.leyenda : MicanTexto.etiqueta).copyWith(color: color)),
        ],
      ),
    );
  }
}

class InsigniaVerificado extends StatelessWidget {
  const InsigniaVerificado({super.key});

  @override
  Widget build(BuildContext context) => const Pildora(
    texto: 'Verificado',
    fondo: MicanColores.exitoSuave,
    color: MicanColores.exito,
    icono: MicanIcono.verificado,
  );
}

/// Insignia / Nivel: Nuevo, Confiable, Experto, Embajador Mican.
class InsigniaNivel extends StatelessWidget {
  const InsigniaNivel(this.nivel, {super.key});

  final String nivel;

  static String nombre(String nivel) => switch (nivel) {
    'confiable' => 'Confiable',
    'experto' => 'Experto',
    'embajador' => 'Embajador Mican',
    _ => 'Nuevo',
  };

  @override
  Widget build(BuildContext context) {
    final (fondo, color) = switch (nivel) {
      'nuevo' => (MicanColores.superficieGris, MicanColores.textoSecundario),
      'confiable' => (MicanColores.primarioSuave, MicanColores.primario),
      _ => (MicanColores.acentoSuave, MicanColores.acento),
    };
    return Pildora(texto: nombre(nivel), fondo: fondo, color: color, estrella: true);
  }
}

class Calificacion extends StatelessWidget {
  const Calificacion({super.key, required this.nota, required this.resenas, this.textoResenas});

  final double nota;
  final int resenas;

  /// Por defecto "(128)"; en el perfil se muestra "(128 reseñas)".
  final String? textoResenas;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const EstrellaRellena(tamano: 18),
        const SizedBox(width: 6),
        Text(resenas == 0 ? 'Nuevo' : nota.toStringAsFixed(1), style: MicanTexto.cuerpoFuerte),
        const SizedBox(width: 6),
        Text(textoResenas ?? '($resenas)', style: MicanTexto.leyenda),
      ],
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.nombre, this.fotoUrl, this.emoji, this.tamano = 48, this.fondo});

  final String nombre;
  final String? fotoUrl;
  final String? emoji;
  final double tamano;
  final Color? fondo;

  static String iniciales(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return (partes[0][0] + partes[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: fondo ?? MicanColores.primarioSuave, shape: BoxShape.circle),
      child: fotoUrl != null
          ? Image.network(fotoUrl!, width: tamano, height: tamano, fit: BoxFit.cover)
          : Text(
              emoji ?? iniciales(nombre),
              style: emoji != null
                  ? TextStyle(fontSize: tamano * 0.5)
                  : MicanTexto.subtitulo.copyWith(
                      color: MicanColores.primario,
                      fontSize: tamano >= 80 ? 28 : 16,
                      fontWeight: tamano >= 80 ? FontWeight.w800 : FontWeight.w600,
                    ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Interruptor, selector segmentado, casilla
// ---------------------------------------------------------------------------

class Interruptor extends StatelessWidget {
  const Interruptor({super.key, required this.activo, required this.alCambiar});

  final bool activo;
  final ValueChanged<bool>? alCambiar;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: alCambiar == null ? null : () => alCambiar!(!activo),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 52,
        height: 30,
        padding: const EdgeInsets.all(3),
        alignment: activo ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: activo ? MicanColores.exito : MicanColores.bordeSuave,
          borderRadius: BorderRadius.circular(MicanMedidas.radioPildora),
        ),
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// "Modalidad" y "Pestañas": dos opciones en una píldora gris.
class SelectorSegmentado extends StatelessWidget {
  const SelectorSegmentado({super.key, required this.opciones, required this.indice, required this.alCambiar});

  final List<String> opciones;
  final int indice;
  final ValueChanged<int> alCambiar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: MicanColores.superficieGris,
        borderRadius: BorderRadius.circular(MicanMedidas.radioPildora),
      ),
      child: Row(
        children: [
          for (var i = 0; i < opciones.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => alCambiar(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == indice ? MicanColores.superficieTarjeta : Colors.transparent,
                    borderRadius: BorderRadius.circular(MicanMedidas.radioPildora),
                  ),
                  child: Text(
                    opciones[i],
                    style: MicanTexto.etiqueta.copyWith(
                      color: i == indice ? MicanColores.primario : MicanColores.textoSecundario,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Casilla cuadrada (consentimientos) o redonda (tareas de la visita).
class Casilla extends StatelessWidget {
  const Casilla({super.key, required this.marcada, this.redonda = false, this.colorMarcada = MicanColores.primario});

  final bool marcada;
  final bool redonda;
  final Color colorMarcada;

  @override
  Widget build(BuildContext context) {
    final tam = redonda ? 22.0 : 24.0;
    return Container(
      width: tam,
      height: tam,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: marcada ? colorMarcada : MicanColores.superficieTarjeta,
        border: Border.all(color: marcada ? colorMarcada : MicanColores.bordeSuave, width: 2),
        borderRadius: BorderRadius.circular(redonda ? 999 : 7),
      ),
      child: marcada
          ? Text(
              '✓',
              style: MicanTexto.etiqueta.copyWith(color: Colors.white, fontSize: redonda ? 12 : 13, height: 1),
            )
          : null,
    );
  }
}

/// Radio redondo del método de pago (pantalla 16).
class RadioMican extends StatelessWidget {
  const RadioMican({super.key, required this.marcado});

  final bool marcado;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: marcado ? MicanColores.primario : Colors.transparent,
        border: Border.all(color: marcado ? MicanColores.primario : MicanColores.bordeSuave, width: marcado ? 7 : 2),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Contenedores
// ---------------------------------------------------------------------------

class Tarjeta extends StatelessWidget {
  const Tarjeta({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = MicanColores.superficieTarjeta,
    this.radio = MicanMedidas.radioTarjeta,
    this.borde,
    this.alPresionar,
    this.sombra = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radio;
  final BorderSide? borde;
  final VoidCallback? alPresionar;
  final bool sombra;

  @override
  Widget build(BuildContext context) {
    final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radio), side: borde ?? BorderSide.none);
    return DecoratedBox(
      decoration: ShapeDecoration(shape: forma, shadows: sombra ? MicanSombras.tarjeta : null),
      child: Material(
        color: color,
        shape: forma,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alPresionar,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Aviso de color con icono (p. ej. "Tu reseña se publica cuando ambos califiquen").
class Aviso extends StatelessWidget {
  const Aviso({
    super.key,
    required this.texto,
    this.icono,
    this.fondo = MicanColores.primarioSuave,
    this.color = MicanColores.primarioOscuro,
    this.colorIcono,
    this.radio = MicanMedidas.radioAviso,
  });

  final String texto;
  final MicanIcono? icono;
  final Color fondo;
  final Color color;
  final Color? colorIcono;
  final double radio;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(radio)),
      child: Row(
        children: [
          if (icono != null) ...[Icono(icono!, tamano: 16, color: colorIcono ?? color), const SizedBox(width: 8)],
          Expanded(
            child: Text(texto, style: MicanTexto.leyenda.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

/// Texto pequeño con icono (p. ej. el candado de privacidad).
class NotaConIcono extends StatelessWidget {
  const NotaConIcono({super.key, required this.icono, required this.texto, this.color = MicanColores.textoSecundario});

  final MicanIcono icono;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icono(icono, tamano: 14, color: MicanColores.textoSecundario),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(texto, style: MicanTexto.leyenda.copyWith(color: color)),
        ),
      ],
    );
  }
}

/// Cuadro de icono redondeado (40×40 o 44×44) usado en filas y tarjetas.
class CajaIcono extends StatelessWidget {
  const CajaIcono(
    this.icono, {
    super.key,
    this.tamano = 40,
    this.tamanoIcono = 20,
    this.fondo = MicanColores.primarioSuave,
    this.color = MicanColores.textoPrincipal,
    this.radio = MicanMedidas.radioIcono,
  });

  final MicanIcono icono;
  final double tamano;
  final double tamanoIcono;
  final Color fondo;
  final Color color;
  final double radio;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(radio)),
      child: Icono(icono, tamano: tamanoIcono, color: color),
    );
  }
}

class LogoMican extends StatelessWidget {
  const LogoMican({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.string(marcaMicanSvg, width: 48, height: 48),
        const SizedBox(width: 10),
        Text('mican', style: MicanTexto.logotipo),
      ],
    );
  }
}

class Cargando extends StatelessWidget {
  const Cargando({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
  );
}

class Vacio extends StatelessWidget {
  const Vacio({super.key, required this.icono, required this.titulo, this.texto});

  final MicanIcono icono;
  final String titulo;
  final String? texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          CajaIcono(icono, tamano: 64, tamanoIcono: 30, radio: 999, color: MicanColores.primario),
          const SizedBox(height: 12),
          Text(titulo, style: MicanTexto.subtitulo, textAlign: TextAlign.center),
          if (texto != null) ...[
            const SizedBox(height: 4),
            Text(texto!, style: MicanTexto.leyenda, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
