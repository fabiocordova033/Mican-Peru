import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../componentes/base.dart';
import '../../componentes/estructura.dart';
import '../../datos/proveedores.dart';
import '../../tema/colores.dart';
import '../../tema/iconos.dart';
import '../../tema/tipografia.dart';
import '../../util/ui.dart';

/// Pantalla 24 · Permiso de ubicación (HU-29). Explica el uso antes del
/// diálogo del sistema.
class PantallaPermisoUbicacion extends ConsumerStatefulWidget {
  const PantallaPermisoUbicacion({super.key});

  @override
  ConsumerState<PantallaPermisoUbicacion> createState() => _Estado();
}

class _Estado extends ConsumerState<PantallaPermisoUbicacion> {
  bool _pidiendo = false;

  Future<void> _permitir() async {
    setState(() => _pidiendo = true);
    final ok = await ref.read(ubicacionProvider).pedirPermiso();
    if (!mounted) return;
    setState(() => _pidiendo = false);
    if (!ok) avisar(context, 'Sin ubicación podrás escribir tu dirección, pero el cuidador no podrá iniciar paseos.');
    context.go('/app');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
          children: [
            Center(
              child: Container(
                width: 140,
                height: 140,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: MicanColores.primarioSuave, shape: BoxShape.circle),
                child: const Icono(MicanIcono.ubicacion, tamano: 64, color: MicanColores.primario),
              ),
            ),
            const SizedBox(height: 18),
            Text('Activa tu ubicación', style: MicanTexto.titulo1, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            Text(
              'La usamos para que los paseos sean seguros y encontrar cuidadores cerca de ti.',
              style: MicanTexto.cuerpo.copyWith(color: MicanColores.textoSecundario),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            const Tarjeta(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  FilaUso(
                    icono: MicanIcono.ruta,
                    titulo: 'Ruta del paseo en vivo',
                    texto: 'Solo mientras hay un servicio en curso, aunque la app esté en segundo plano',
                  ),
                  SizedBox(height: 14),
                  FilaUso(
                    icono: MicanIcono.ubicacion,
                    titulo: 'Cuidadores cercanos',
                    texto: 'Usamos tu zona, no tu dirección exacta',
                  ),
                  SizedBox(height: 14),
                  FilaUso(
                    icono: MicanIcono.candado,
                    titulo: 'No la vendemos ni la compartimos',
                    texto: 'Solo la ve la otra parte del servicio',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BarraAccion(
        vertical: true,
        children: [
          Boton('Permitir ubicación', cargando: _pidiendo, alPresionar: _permitir),
          Boton('Ahora no, escribiré mi dirección', tipo: TipoBoton.fantasma, alPresionar: () => context.go('/app')),
        ],
      ),
    );
  }
}

class FilaUso extends StatelessWidget {
  const FilaUso({super.key, required this.icono, required this.titulo, required this.texto});

  final MicanIcono icono;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CajaIcono(icono),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: MicanTexto.cuerpoFuerte),
              Text(texto, style: MicanTexto.leyenda),
            ],
          ),
        ),
      ],
    );
  }
}
