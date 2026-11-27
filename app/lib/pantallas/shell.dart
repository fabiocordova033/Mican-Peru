import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../componentes/base.dart';
import '../componentes/estructura.dart';
import '../datos/modelos.dart';
import '../datos/proveedores.dart';
import 'cuenta/cuenta.dart';
import 'cuidador/inicio_cuidador.dart';
import 'dueno/inicio_dueno.dart';
import 'mensajes/mensajes.dart';
import 'servicio/actividad.dart';

/// Pestaña activa de la navegación inferior.
class PestanaNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void ir(int i) => state = i;
}

final pestanaProvider = NotifierProvider<PestanaNotifier, int>(PestanaNotifier.new);

/// Contenedor con la "Navegación inferior". Las pestañas cambian según el
/// rol activo (dueño o cuidador).
class ShellMican extends ConsumerWidget {
  const ShellMican({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(usuarioProvider).value;
    if (usuario == null) return const Scaffold(body: Cargando());
    final indice = ref.watch(pestanaProvider);
    final cuidador = usuario.rolActivo == Rol.cuidador;
    final paginas = [
      cuidador ? const InicioCuidador() : const InicioDueno(),
      const PantallaMensajes(),
      PantallaActividad(comoCuidador: cuidador),
      const PantallaCuenta(),
    ];
    return Scaffold(
      body: IndexedStack(index: indice, children: paginas),
      bottomNavigationBar: NavegacionInferior(
        activo: indice,
        noLeidos: ref.watch(noLeidosProvider),
        alCambiar: ref.read(pestanaProvider.notifier).ir,
      ),
    );
  }
}
