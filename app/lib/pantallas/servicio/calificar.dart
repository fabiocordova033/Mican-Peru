import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../componentes/base.dart';
import '../../componentes/estructura.dart';
import '../../datos/proveedores.dart';
import '../../tema/iconos.dart';
import '../../tema/tipografia.dart';
import '../../util/formato.dart';
import '../../util/ui.dart';

/// Etiquetas permitidas por el backend (ETIQUETAS_CALIFICACION).
const etiquetasCalificacion = ['Puntual', 'Cariñoso', 'Responsable', 'Buena comunicación', 'Envió fotos', 'Cuidadoso'];

/// Pantalla 07 · Calificar servicio (HU-24).
class PantallaCalificar extends ConsumerStatefulWidget {
  const PantallaCalificar({super.key, required this.servicioId});

  final String servicioId;

  @override
  ConsumerState<PantallaCalificar> createState() => _PantallaCalificarState();
}

class _PantallaCalificarState extends ConsumerState<PantallaCalificar> {
  int _estrellas = 5;
  final _etiquetas = <String>{};
  final _comentario = TextEditingController();
  final _motivo = TextEditingController();
  bool _enviando = false;

  Future<void> _enviar() async {
    if (_estrellas <= 2 && _motivo.text.trim().isEmpty) {
      return avisar(context, 'Con 1 o 2 estrellas cuéntanos qué pasó.');
    }
    setState(() => _enviando = true);
    final ok = await intentar(context, () async {
      final r = await ref
          .read(apiProvider)
          .calificar(
            servicioId: widget.servicioId,
            estrellas: _estrellas,
            etiquetas: _etiquetas.toList(),
            comentario: _comentario.text.trim(),
            motivo: _estrellas <= 2 ? _motivo.text.trim() : null,
          );
      if (mounted) {
        avisar(
          context,
          r['revelada'] == true
              ? '¡Gracias! Ya pueden ver sus reseñas.'
              : '¡Gracias! Tu reseña se publica cuando ambos califiquen.',
        );
      }
    });
    if (!mounted) return;
    setState(() => _enviando = false);
    if (ok) context.go('/app');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(servicioProvider(widget.servicioId)).value;
    final uid = ref.watch(uidProvider);
    if (s == null) return const Scaffold(body: Cargando());
    final soyDueno = s.duenoId == uid;
    final otro = soyDueno ? (s.cuidadorNombre ?? '') : s.duenoNombre;
    final sustantivo = switch (s.tipo.name) {
      'paseo' => 'el paseo',
      'visita' => 'la visita',
      _ => 'el transporte',
    };

    return PantallaMican(
      titulo: 'Calificar servicio',
      espacio: 16,
      barraAccion: BarraAccion(
        children: [
          Expanded(
            child: Boton('Enviar calificación', cargando: _enviando, alPresionar: _enviar),
          ),
        ],
      ),
      children: [
        Center(child: Avatar(nombre: otro, tamano: 88)),
        Text(
          soyDueno
              ? '¿Cómo fue $sustantivo de ${s.mascota.nombre} con ${otro.split(' ').first}?'
              : '¿Cómo te fue con ${otro.split(' ').first} y ${s.mascota.nombre}?',
          style: MicanTexto.titulo2,
          textAlign: TextAlign.center,
        ),
        Text(
          '${s.tipo.nombre} ${duracion(s.duracionMin)} · ${fechaRelativa(s.iniciadoEn ?? s.creadoEn).toLowerCase()} · ${solesCortos(s.precio)}',
          style: MicanTexto.leyenda,
          textAlign: TextAlign.center,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 1; i <= 5; i++)
              Semantics(
                button: true,
                label: '$i estrella${i == 1 ? '' : 's'}',
                selected: i <= _estrellas,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _estrellas = i);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: EstrellaRellena(tamano: 40, activa: i <= _estrellas),
                  ),
                ),
              ),
          ],
        ),
        Text('¿Qué destacarías?', style: MicanTexto.subtitulo),
        GrupoChips<String>(
          opciones: etiquetasCalificacion,
          etiqueta: (e) => e,
          seleccionados: _etiquetas,
          alCambiar: (e) => setState(() => _etiquetas.contains(e) ? _etiquetas.remove(e) : _etiquetas.add(e)),
        ),
        if (_estrellas <= 2)
          CampoTexto(
            etiqueta: '¿Qué pasó? (lo verá soporte de Mican)',
            controlador: _motivo,
            lineas: 3,
            maxCaracteres: 1000,
          ),
        CampoTexto(
          etiqueta: 'Comentario (opcional)',
          controlador: _comentario,
          lineas: 3,
          maxCaracteres: 300,
          pista: soyDueno ? '${s.mascota.nombre} volvió feliz y cansado. ¡Gracias por las fotos!' : null,
        ),
        const Aviso(icono: MicanIcono.candado, texto: 'Tu reseña se publica cuando ambos califiquen.'),
      ],
    );
  }
}
