import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../componentes/base.dart';
import '../../datos/modelos.dart';
import '../../datos/proveedores.dart';
import '../../tema/colores.dart';
import '../../tema/iconos.dart';
import '../../tema/tipografia.dart';
import '../../util/ui.dart';

/// Miniatura de una foto del servicio (Storage).
class MiniaturaFoto extends ConsumerWidget {
  const MiniaturaFoto({super.key, required this.ruta, this.tamano = 80, this.alto});

  final String ruta;
  final double tamano;
  final double? alto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(urlFotoProvider(ruta)).value;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: tamano,
        height: alto ?? tamano,
        color: MicanColores.primarioSuave,
        child: url == null
            ? const Center(child: Icono(MicanIcono.camara, tamano: 22))
            : Image.network(url, fit: BoxFit.cover),
      ),
    );
  }
}

/// Galería de fotos del servicio (HU-17).
Future<void> verFotos(BuildContext context, String servicioId) {
  return mostrarHoja(
    context,
    builder: (c) => Consumer(
      builder: (context, ref, _) {
        final fotos = ref.watch(fotosServicioProvider(servicioId)).value ?? const <FotoServicio>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Fotos del servicio', style: MicanTexto.titulo2),
            const SizedBox(height: 12),
            if (fotos.isEmpty)
              const Vacio(
                icono: MicanIcono.camara,
                titulo: 'Aún no hay fotos',
                texto: 'Te avisaremos cuando llegue una.',
              )
            else
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [for (final f in fotos) MiniaturaFoto(ruta: f.ruta)],
              ),
          ],
        );
      },
    ),
  );
}
