import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../componentes/base.dart';
import '../../componentes/estructura.dart';
import '../../componentes/tarjetas.dart';
import '../../datos/proveedores.dart';
import '../../tema/colores.dart';
import '../../tema/iconos.dart';
import '../../tema/tipografia.dart';
import '../../util/formato.dart';
import '../../util/ui.dart';

/// Pantalla 05 · Perfil del cuidador (`perfilesPublicos/{uid}`). Si llega
/// desde una oferta (`?servicio=&precio=`) permite aceptarla aquí mismo.
class PantallaPerfilCuidador extends ConsumerStatefulWidget {
  const PantallaPerfilCuidador({super.key, required this.uid, this.servicioId, this.precio});

  final String uid;
  final String? servicioId;
  final int? precio;

  @override
  ConsumerState<PantallaPerfilCuidador> createState() => _PantallaPerfilCuidadorState();
}

class _PantallaPerfilCuidadorState extends ConsumerState<PantallaPerfilCuidador> {
  bool _aceptando = false;

  Future<void> _aceptar() async {
    setState(() => _aceptando = true);
    final ok = await intentar(context, () => ref.read(apiProvider).aceptarOferta(widget.servicioId!, widget.uid));
    if (!mounted) return;
    setState(() => _aceptando = false);
    if (ok) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(perfilProvider(widget.uid));
    final p = async.value;
    if (p == null) {
      return PantallaMican(
        titulo: 'Cuidador',
        children: [
          if (async.isLoading)
            const Cargando()
          else
            const Vacio(icono: MicanIcono.cuenta, titulo: 'Perfil no disponible'),
        ],
      );
    }
    final etiquetas = p.etiquetas.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final puedeAceptar = widget.servicioId != null && widget.precio != null;

    return PantallaMican(
      titulo: 'Perfil del cuidador',
      espacio: 16,
      barraAccion: puedeAceptar
          ? BarraAccion(
              children: [
                Expanded(
                  child: Boton(
                    'Aceptar por ${solesCortos(widget.precio!)}',
                    cargando: _aceptando,
                    alPresionar: _aceptar,
                  ),
                ),
              ],
            )
          : null,
      children: [
        Column(
          children: [
            Avatar(nombre: p.nombre, fotoUrl: p.fotoUrl, tamano: 96),
            const SizedBox(height: 12),
            Text(p.nombre, style: MicanTexto.titulo1, textAlign: TextAlign.center),
            if (p.edad != null) Text('${p.edad} años', style: MicanTexto.leyenda),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [if (p.verificado) const InsigniaVerificado(), InsigniaNivel(p.nivel)],
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: CajaDato(
                valor: p.numResenas == 0 ? '—' : p.calificacionPromedio.toStringAsFixed(1),
                etiqueta: '${p.numResenas} reseñas',
                colorValor: MicanColores.acento,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: CajaDato(valor: '${p.serviciosCompletados}', etiqueta: 'servicios'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: CajaDato(
                valor: p.disponible ? 'Sí' : 'No',
                etiqueta: 'disponible',
                colorValor: p.disponible ? MicanColores.exito : MicanColores.textoSecundario,
              ),
            ),
          ],
        ),
        if (etiquetas.isNotEmpty) ...[
          const TituloSeccion('Lo que destacan los dueños'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in etiquetas.take(6))
                Pildora(
                  texto: '${e.key} · ${e.value}',
                  fondo: MicanColores.primarioSuave,
                  color: MicanColores.primario,
                ),
            ],
          ),
        ],
        if (p.experiencia.isNotEmpty) ...[
          const TituloSeccion('Experiencia'),
          Tarjeta(child: Text(p.experiencia, style: MicanTexto.cuerpo)),
        ],
        if (p.certificaciones.isNotEmpty || p.educacion.isNotEmpty)
          ListaTarjeta(
            children: [
              for (final c in p.certificaciones)
                FilaLista(
                  icono: MicanIcono.verificado,
                  fondoIcono: MicanColores.exitoSuave,
                  colorIcono: MicanColores.exito,
                  titulo: c,
                ),
              for (final e in p.educacion)
                FilaLista(icono: MicanIcono.documento, fondoIcono: MicanColores.primarioSuave, titulo: e),
            ],
          ),
        const NotaConIcono(
          icono: MicanIcono.escudo,
          texto: 'Mican verifica el DNI, los antecedentes y una selfie de cada cuidador antes de activarlo.',
        ),
      ],
    );
  }
}
