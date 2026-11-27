import 'package:flutter/material.dart';

import '../../componentes/base.dart';
import '../../tema/colores.dart';
import '../../tema/iconos.dart';
import '../../tema/tipografia.dart';
import '../../util/ui.dart';
import '../inicio_sesion/permiso_ubicacion.dart' show FilaUso;

/// Aviso destacado (Google Play "prominent disclosure" y App Store 5.1.1)
/// que ve el cuidador antes de su primer paseo: la ubicación se seguirá
/// registrando con la app en segundo plano o la pantalla apagada, solo
/// mientras el servicio esté en curso. Devuelve `true` si acepta.
Future<bool> mostrarAvisoUbicacionPaseo(BuildContext context) async {
  final r = await mostrarHoja<bool>(context, builder: (c) => const ContenidoAvisoUbicacionPaseo());
  return r ?? false;
}

class ContenidoAvisoUbicacionPaseo extends StatelessWidget {
  const ContenidoAvisoUbicacionPaseo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: MicanColores.primarioSuave, shape: BoxShape.circle),
            child: const Icono(MicanIcono.ruta, tamano: 34, color: MicanColores.primario),
          ),
        ),
        const SizedBox(height: 14),
        Text('Ubicación durante el paseo', style: MicanTexto.titulo2, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'Mican recoge tu ubicación para mostrar al dueño la ruta en vivo, incluso cuando la app está cerrada, '
          'en segundo plano o con la pantalla apagada.',
          style: MicanTexto.cuerpo.copyWith(color: MicanColores.textoSecundario),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const FilaUso(
          icono: MicanIcono.reloj,
          titulo: 'Solo mientras el servicio está en curso',
          texto: 'Empieza al iniciar y se detiene sola al finalizar o cancelar',
        ),
        const SizedBox(height: 12),
        const FilaUso(
          icono: MicanIcono.campana,
          titulo: 'Siempre sabrás que está activa',
          texto: 'Verás la notificación "Paseo en curso" (o el indicador azul en iPhone)',
        ),
        const SizedBox(height: 12),
        const FilaUso(
          icono: MicanIcono.candado,
          titulo: 'Solo la ve el dueño de la mascota',
          texto: 'No la vendemos ni la usamos para publicidad',
        ),
        const SizedBox(height: 20),
        Boton('Entendido, continuar', alPresionar: () => Navigator.pop(context, true)),
        const SizedBox(height: 8),
        Boton('Ahora no', tipo: TipoBoton.fantasma, alPresionar: () => Navigator.pop(context, false)),
      ],
    );
  }
}
