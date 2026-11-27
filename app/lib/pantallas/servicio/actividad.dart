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
import '../dueno/inicio_dueno.dart' show iconoServicio;

/// Pantalla 17 · Actividad: servicios en curso e historial (HU-20).
class PantallaActividad extends ConsumerStatefulWidget {
  const PantallaActividad({super.key, required this.comoCuidador});

  final bool comoCuidador;

  @override
  ConsumerState<PantallaActividad> createState() => _PantallaActividadState();
}

class _PantallaActividadState extends ConsumerState<PantallaActividad> {
  int _pestana = 0;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(widget.comoCuidador ? serviciosCuidadorProvider : serviciosDuenoProvider);
    final premium = ref.watch(usuarioProvider).value?.esPremium ?? false;
    final todos = async.value ?? const <Servicio>[];
    final activos = todos.where((s) => s.estado.activo).toList();
    final historial = todos.where((s) => !s.estado.activo).toList();
    final lista = _pestana == 0 ? activos : historial;

    return PantallaMican(
      titulo: 'Actividad',
      mostrarAtras: false,
      children: [
        SelectorSegmentado(
          opciones: ['En curso (${activos.length})', 'Historial'],
          indice: _pestana,
          alCambiar: (i) => setState(() => _pestana = i),
        ),
        if (async.isLoading && todos.isEmpty)
          const Cargando()
        else if (lista.isEmpty)
          Vacio(
            icono: _pestana == 0 ? MicanIcono.huella : MicanIcono.calendario,
            titulo: _pestana == 0 ? 'Nada en curso' : 'Aún no hay servicios',
            texto: _pestana == 0
                ? (widget.comoCuidador
                      ? 'Acepta una solicitud desde el inicio.'
                      : 'Pide un paseo, visita o transporte desde el inicio.')
                : 'Aquí verás tus servicios terminados.',
          )
        else
          ListaTarjeta(
            children: [for (final s in lista) _FilaServicio(servicio: s, comoCuidador: widget.comoCuidador)],
          ),
        if (_pestana == 1 && !widget.comoCuidador && !premium)
          Tarjeta(
            color: MicanColores.acentoSuave,
            sombra: false,
            alPresionar: () => context.push('/premium'),
            child: Row(
              children: [
                const Icono(MicanIcono.corona, tamano: 22, color: MicanColores.acento),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ves los últimos 30 días', style: MicanTexto.cuerpoFuerte),
                      Text('Con Premium guardas todo tu historial y las rutas.', style: MicanTexto.leyenda),
                    ],
                  ),
                ),
                const Icono(MicanIcono.chevron, tamano: 20),
              ],
            ),
          ),
      ],
    );
  }
}

class _FilaServicio extends StatelessWidget {
  const _FilaServicio({required this.servicio, required this.comoCuidador});

  final Servicio servicio;
  final bool comoCuidador;

  @override
  Widget build(BuildContext context) {
    final s = servicio;
    final (texto, fondo, color) = switch (s.estado) {
      EstadoServicio.buscando => ('Buscando', MicanColores.acentoSuave, MicanColores.acento),
      EstadoServicio.confirmado => ('Confirmado', MicanColores.primarioSuave, MicanColores.primario),
      EstadoServicio.enCurso => ('En curso', MicanColores.exitoSuave, MicanColores.exito),
      EstadoServicio.completado => ('Completado', MicanColores.superficieGris, MicanColores.textoSecundario),
      EstadoServicio.cancelado => ('Cancelado', MicanColores.errorSuave, MicanColores.error),
      EstadoServicio.expirado => ('Expirado', MicanColores.superficieGris, MicanColores.textoSecundario),
    };
    final otro = comoCuidador ? s.duenoNombre.split(' ').first : (s.cuidadorNombre?.split(' ').first);
    return FilaLista(
      icono: iconoServicio(s.tipo),
      fondoIcono: MicanColores.primarioSuave,
      titulo: '${s.tipo.nombre} · ${s.mascota.nombre}',
      subtitulo: [fechaRelativa(s.creadoEn), ?otro].join(' · '),
      alPresionar: () => context.push('/servicio/${s.id}'),
      final_: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(solesCortos(s.precio), style: MicanTexto.cuerpoFuerte),
          const SizedBox(height: 2),
          Pildora(texto: texto, fondo: fondo, color: color, compacta: true),
        ],
      ),
    );
  }
}
