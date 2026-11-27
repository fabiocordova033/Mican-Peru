import 'package:flutter/material.dart';

import '../tema/colores.dart';
import '../tema/iconos.dart';
import '../tema/tipografia.dart';
import 'base.dart';

/// "Tarjeta / Servicio": paseo, visita a domicilio o transporte.
class TarjetaServicio extends StatelessWidget {
  const TarjetaServicio({
    super.key,
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    this.seleccionado = false,
    this.alPresionar,
  });

  final MicanIcono icono;
  final String titulo;
  final String subtitulo;
  final bool seleccionado;
  final VoidCallback? alPresionar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Tarjeta(
        alPresionar: alPresionar,
        borde: BorderSide(color: seleccionado ? MicanColores.primario : MicanColores.superficieTarjeta, width: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CajaIcono(
              icono,
              tamano: 48,
              tamanoIcono: 26,
              radio: 14,
              fondo: seleccionado ? MicanColores.primario : MicanColores.primarioSuave,
              color: seleccionado ? MicanColores.textoInvertido : MicanColores.textoPrincipal,
            ),
            const SizedBox(height: 10),
            Text(titulo, style: MicanTexto.cuerpoFuerte, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Text(subtitulo, style: MicanTexto.leyenda, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

/// "Banner / Patrocinado" (se oculta con Premium).
class BannerPatrocinado extends StatelessWidget {
  const BannerPatrocinado({super.key, required this.titulo, required this.vigencia, this.alPresionar});

  final String titulo;
  final String vigencia;
  final VoidCallback? alPresionar;

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      color: MicanColores.acentoSuave,
      alPresionar: alPresionar,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PATROCINADO', style: MicanTexto.leyenda.copyWith(color: MicanColores.acento)),
                const SizedBox(height: 2),
                Text(titulo, style: MicanTexto.cuerpoFuerte),
                const SizedBox(height: 2),
                Text(vigencia, style: MicanTexto.leyenda),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const CajaIcono(
            MicanIcono.mas,
            tamano: 52,
            tamanoIcono: 26,
            radio: 14,
            fondo: MicanColores.superficieTarjeta,
            color: MicanColores.acento,
          ),
        ],
      ),
    );
  }
}

/// "Tarjeta / Mascota".
class TarjetaMascota extends StatelessWidget {
  const TarjetaMascota({
    super.key,
    required this.nombre,
    required this.detalle,
    required this.emoji,
    this.vacunasAlDia,
    this.fotoUrl,
    this.alPresionar,
  });

  final String nombre;
  final String detalle;
  final String emoji;
  final bool? vacunasAlDia;
  final String? fotoUrl;
  final VoidCallback? alPresionar;

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      alPresionar: alPresionar,
      child: Row(
        children: [
          Avatar(nombre: nombre, emoji: emoji, fotoUrl: fotoUrl, tamano: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: MicanTexto.subtitulo),
                const SizedBox(height: 2),
                Text(detalle, style: MicanTexto.leyenda),
                if (vacunasAlDia != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icono(
                        MicanIcono.huella,
                        tamano: 14,
                        color: vacunasAlDia! ? MicanColores.exito : MicanColores.acento,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        vacunasAlDia! ? 'Vacunas al día' : 'Revisa sus vacunas',
                        style: MicanTexto.leyenda.copyWith(
                          color: vacunasAlDia! ? MicanColores.exito : MicanColores.acento,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (alPresionar != null) const Icono(MicanIcono.chevron, tamano: 20),
        ],
      ),
    );
  }
}

/// "Tarjeta / Oferta": oferta de un cuidador que ve el dueño.
class TarjetaOferta extends StatelessWidget {
  const TarjetaOferta({
    super.key,
    required this.nombre,
    required this.nota,
    required this.resenas,
    required this.precio,
    required this.llegada,
    this.fotoUrl,
    this.esContraoferta = false,
    this.segundosRestantes,
    this.alAceptar,
    this.alRechazar,
    this.alVerPerfil,
    this.aceptando = false,
  });

  final String nombre;
  final double nota;
  final int resenas;
  final String precio;
  final String llegada;
  final String? fotoUrl;
  final bool esContraoferta;
  final int? segundosRestantes;
  final VoidCallback? alAceptar;
  final VoidCallback? alRechazar;
  final VoidCallback? alVerPerfil;
  final bool aceptando;

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      child: Column(
        children: [
          GestureDetector(
            onTap: alVerPerfil,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Avatar(nombre: nombre, fotoUrl: fotoUrl, tamano: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre, style: MicanTexto.cuerpoFuerte, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Calificacion(nota: nota, resenas: resenas),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(precio, style: MicanTexto.titulo1.copyWith(color: MicanColores.acento)),
                    Text(llegada, style: MicanTexto.leyenda),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Boton('Rechazar', tipo: TipoBoton.contorno, alPresionar: alRechazar),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Boton('Aceptar', alPresionar: alAceptar, cargando: aceptando),
              ),
            ],
          ),
          if (segundosRestantes != null) ...[
            const SizedBox(height: 8),
            Text(
              esContraoferta
                  ? 'Contraoferta · vence en $segundosRestantes s'
                  : 'Acepta tu precio · vence en $segundosRestantes s',
              style: MicanTexto.leyenda,
            ),
          ],
        ],
      ),
    );
  }
}

/// "Tarjeta / Solicitud": lo que ve el cuidador en su inicio.
class TarjetaSolicitud extends StatelessWidget {
  const TarjetaSolicitud({
    super.key,
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.precio,
    required this.metodoPago,
    required this.mascota,
    required this.emojiMascota,
    this.alertas = const [],
    this.esPaquete = false,
    this.alContraofertar,
    this.alAceptar,
    this.aceptando = false,
  });

  final MicanIcono icono;
  final String titulo;
  final String subtitulo;
  final String precio;
  final String metodoPago;
  final String mascota;
  final String emojiMascota;
  final List<String> alertas;
  final bool esPaquete;
  final VoidCallback? alContraofertar;
  final VoidCallback? alAceptar;
  final bool aceptando;

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      child: Column(
        children: [
          Row(
            children: [
              CajaIcono(icono, tamanoIcono: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: MicanTexto.cuerpoFuerte),
                    Text(subtitulo, style: MicanTexto.leyenda, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(precio, style: MicanTexto.titulo2.copyWith(color: MicanColores.primario)),
                  Text(metodoPago, style: MicanTexto.leyenda),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: MicanColores.bordeSuave),
          const SizedBox(height: 12),
          Row(
            children: [
              Avatar(nombre: mascota, emoji: emojiMascota, tamano: 32, fondo: MicanColores.acentoSuave),
              const SizedBox(width: 8),
              Expanded(
                child: Text(mascota, style: MicanTexto.etiqueta, overflow: TextOverflow.ellipsis),
              ),
              for (final a in alertas.take(1))
                Pildora(texto: a, fondo: MicanColores.acentoSuave, color: MicanColores.acento, compacta: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (!esPaquete) ...[
                Expanded(
                  child: Boton('Contraofertar', tipo: TipoBoton.contorno, alPresionar: alContraofertar),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Boton('Aceptar $precio', alPresionar: alAceptar, cargando: aceptando),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Tarjeta / Saldo" del cuidador.
class TarjetaSaldo extends StatelessWidget {
  const TarjetaSaldo({super.key, required this.saldo, required this.alRecargar});

  final String saldo;
  final VoidCallback alRecargar;

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      color: MicanColores.primario,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icono(MicanIcono.billetera, tamano: 20, color: MicanColores.textoInvertido),
              const SizedBox(width: 8),
              Text('Saldo disponible', style: MicanTexto.etiqueta.copyWith(color: MicanColores.textoInvertido)),
            ],
          ),
          const SizedBox(height: 12),
          Text(saldo, style: MicanTexto.display.copyWith(color: MicanColores.textoInvertido)),
          const SizedBox(height: 12),
          Text(
            'Comisión Mican: 12% por servicio completado',
            style: MicanTexto.leyenda.copyWith(color: MicanColores.primarioSuave),
          ),
          const SizedBox(height: 12),
          Boton('Recargar saldo', tipo: TipoBoton.acento, alPresionar: alRecargar),
        ],
      ),
    );
  }
}

/// Fila de una lista blanca: icono, título, subtítulo y algo a la derecha.
class FilaLista extends StatelessWidget {
  const FilaLista({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.icono,
    this.fondoIcono = MicanColores.superficieGris,
    this.colorIcono = MicanColores.textoPrincipal,
    this.inicio,
    this.final_,
    this.colorTitulo = MicanColores.textoPrincipal,
    this.colorSubtitulo = MicanColores.textoSecundario,
    this.alPresionar,
    this.tamanoIcono = 40,
    this.relleno = const EdgeInsets.all(10),
  });

  final String titulo;
  final String? subtitulo;
  final MicanIcono? icono;
  final Color fondoIcono;
  final Color colorIcono;
  final Widget? inicio;
  final Widget? final_;
  final Color colorTitulo;
  final Color colorSubtitulo;
  final VoidCallback? alPresionar;
  final double tamanoIcono;
  final EdgeInsets relleno;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: alPresionar,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: relleno,
        child: Row(
          children: [
            if (inicio != null) ...[inicio!, const SizedBox(width: 12)],
            if (icono != null) ...[
              CajaIcono(
                icono!,
                tamano: tamanoIcono,
                tamanoIcono: tamanoIcono / 2,
                fondo: fondoIcono,
                color: colorIcono,
                radio: tamanoIcono < 40 ? 10 : 12,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: MicanTexto.cuerpoFuerte.copyWith(color: colorTitulo)),
                  if (subtitulo != null) Text(subtitulo!, style: MicanTexto.leyenda.copyWith(color: colorSubtitulo)),
                ],
              ),
            ),
            if (final_ != null) ...[const SizedBox(width: 8), final_!],
          ],
        ),
      ),
    );
  }
}

/// Lista blanca con filas (p. ej. "Movimientos", "Historial").
class ListaTarjeta extends StatelessWidget {
  const ListaTarjeta({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      padding: const EdgeInsets.all(6),
      child: Column(children: children),
    );
  }
}

/// Caja de estadística ("186 servicios", "32 min de 60 min").
class CajaDato extends StatelessWidget {
  const CajaDato({
    super.key,
    required this.valor,
    required this.etiqueta,
    this.icono,
    this.colorValor = MicanColores.primario,
    this.grande = true,
  });

  final String valor;
  final String etiqueta;
  final MicanIcono? icono;
  final Color colorValor;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: icono != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          if (icono != null) ...[Icono(icono!, tamano: 20), const SizedBox(height: 4)],
          Text(
            valor,
            style: (grande ? MicanTexto.titulo2 : MicanTexto.cuerpoFuerte).copyWith(color: colorValor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(etiqueta, style: MicanTexto.leyenda, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Tarjeta "Cuidador" de las pantallas en curso (avatar + nombre + chat).
class TarjetaCuidadorEnCurso extends StatelessWidget {
  const TarjetaCuidadorEnCurso({
    super.key,
    required this.titulo,
    required this.nombre,
    this.nota = 0,
    this.resenas = 0,
    this.fotoUrl,
    this.alChatear,
  });

  final String titulo;
  final String nombre;
  final double nota;
  final int resenas;
  final String? fotoUrl;
  final VoidCallback? alChatear;

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Avatar(nombre: nombre, fotoUrl: fotoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: MicanTexto.cuerpoFuerte, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Calificacion(nota: nota, resenas: resenas),
              ],
            ),
          ),
          if (alChatear != null)
            Material(
              color: MicanColores.primario,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: alChatear,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(child: Icono(MicanIcono.mensajes, tamano: 22, color: MicanColores.textoInvertido)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Fila "Etiqueta ........ valor" de los resúmenes y desgloses.
class FilaResumen extends StatelessWidget {
  const FilaResumen(this.etiqueta, this.valor, {super.key, this.colorValor, this.fuerte = false});

  final String etiqueta;
  final String valor;
  final Color? colorValor;
  final bool fuerte;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            etiqueta,
            style: fuerte ? MicanTexto.cuerpoFuerte : MicanTexto.cuerpo.copyWith(color: MicanColores.textoSecundario),
          ),
        ),
        Text(valor, style: MicanTexto.cuerpoFuerte.copyWith(color: colorValor)),
      ],
    );
  }
}

/// Barra de progreso fina (temporizador de ofertas, verificación, visita).
class BarraProgreso extends StatelessWidget {
  const BarraProgreso({
    super.key,
    required this.valor,
    this.color = MicanColores.acento,
    this.fondo = MicanColores.bordeSuave,
    this.alto = 6,
  });

  final double valor;
  final Color color;
  final Color fondo;
  final double alto;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(alto / 2),
      child: LinearProgressIndicator(value: valor.clamp(0, 1), minHeight: alto, color: color, backgroundColor: fondo),
    );
  }
}

/// Reseña pública en el perfil del cuidador (HU-24): autor, estrellas,
/// cuándo y qué servicio, el comentario y las etiquetas elegidas.
class TarjetaResena extends StatelessWidget {
  const TarjetaResena({
    super.key,
    required this.autor,
    this.fotoUrl,
    required this.estrellas,
    this.fecha = '',
    this.contexto = '',
    this.comentario = '',
    this.etiquetas = const [],
  });

  final String autor;
  final String? fotoUrl;
  final int estrellas;
  final String fecha;
  final String contexto;
  final String comentario;
  final List<String> etiquetas;

  @override
  Widget build(BuildContext context) {
    final detalle = [contexto, fecha].where((t) => t.isNotEmpty).join(' · ');
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(nombre: autor, fotoUrl: fotoUrl, tamano: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(autor, style: MicanTexto.cuerpoFuerte),
                    if (detalle.isNotEmpty) Text(detalle, style: MicanTexto.leyenda),
                  ],
                ),
              ),
              Semantics(
                label: '$estrellas de 5 estrellas',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [for (var i = 1; i <= 5; i++) EstrellaRellena(tamano: 14, activa: i <= estrellas)],
                ),
              ),
            ],
          ),
          if (comentario.isNotEmpty) ...[const SizedBox(height: 10), Text(comentario, style: MicanTexto.cuerpo)],
          if (etiquetas.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in etiquetas)
                  Pildora(texto: e, fondo: MicanColores.primarioSuave, color: MicanColores.primario, compacta: true),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
