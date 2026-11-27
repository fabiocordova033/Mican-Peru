import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../componentes/base.dart';
import '../../componentes/estructura.dart';
import '../../componentes/tarjetas.dart';
import '../../datos/modelos.dart';
import '../../datos/proveedores.dart';
import '../../tema/colores.dart';
import '../../tema/iconos.dart';
import '../../tema/tipografia.dart';
import '../../util/formato.dart';

/// Pantalla 09 · Mis mascotas (HU-06). Sin Premium: 1 mascota; con Premium: 5.
class PantallaMascotas extends ConsumerWidget {
  const PantallaMascotas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mascotasProvider);
    final mascotas = async.value ?? const <Mascota>[];
    final premium = ref.watch(usuarioProvider).value?.esPremium ?? false;
    final limite = premium ? 5 : 1;
    final lleno = mascotas.length >= limite;

    return PantallaMican(
      titulo: 'Mis mascotas',
      barraAccion: BarraAccion(
        children: [
          Expanded(
            child: Boton(
              lleno && !premium ? 'Agrega más con Premium' : 'Agregar mascota',
              icono: MicanIcono.mas,
              tipo: lleno && !premium ? TipoBoton.acento : TipoBoton.primario,
              alPresionar: lleno
                  ? (premium ? null : () => context.push('/premium'))
                  : () => context.push('/mascotas/nueva'),
            ),
          ),
        ],
      ),
      children: [
        if (async.isLoading && mascotas.isEmpty)
          const Cargando()
        else if (mascotas.isEmpty)
          const Vacio(
            icono: MicanIcono.huella,
            titulo: 'Agrega a tu mascota',
            texto: 'Así el cuidador sabrá su tamaño, temperamento y vacunas.',
          )
        else
          for (final m in mascotas)
            TarjetaMascota(
              nombre: m.nombre,
              emoji: m.emoji,
              fotoUrl: m.fotoUrl,
              detalle: [
                m.raza,
                tamano(m.tamano),
                if (m.edadAnios != null) edad(m.edadAnios),
              ].where((t) => t.isNotEmpty).join(' · '),
              vacunasAlDia: m.vacunas.isEmpty ? null : m.vacunasAlDia,
              alPresionar: () => context.push('/mascotas/${m.id}'),
            ),
        Text(
          '${mascotas.length} de $limite ${limite == 1 ? 'mascota' : 'mascotas'} en tu plan ${premium ? 'Premium' : 'Gratis'}',
          style: MicanTexto.leyenda,
          textAlign: TextAlign.center,
        ),
        if (!premium)
          const Aviso(
            icono: MicanIcono.corona,
            texto: 'Con Premium registras hasta 5 mascotas y guardas todo su historial.',
            fondo: MicanColores.acentoSuave,
            color: MicanColores.textoPrincipal,
            colorIcono: MicanColores.acento,
          ),
      ],
    );
  }
}
