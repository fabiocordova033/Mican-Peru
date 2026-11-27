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
import '../../util/ui.dart';

/// Pantalla 25 · Libro de Reclamaciones virtual (HU-30, Ley 29571).
class PantallaReclamo extends ConsumerStatefulWidget {
  const PantallaReclamo({super.key, this.servicioId});

  final String? servicioId;

  @override
  ConsumerState<PantallaReclamo> createState() => _PantallaReclamoState();
}

class _PantallaReclamoState extends ConsumerState<PantallaReclamo> {
  String _tipo = 'reclamo';
  late final _nombre = TextEditingController(text: ref.read(usuarioProvider).value?.nombre ?? '');
  final _documento = TextEditingController();
  final _correo = TextEditingController();
  final _domicilio = TextEditingController();
  final _monto = TextEditingController();
  final _detalle = TextEditingController();
  final _pedido = TextEditingController();
  bool _enviando = false;
  Json? _constancia;

  Future<void> _enviar() async {
    if ([_nombre, _documento, _correo, _detalle, _pedido].any((c) => c.text.trim().isEmpty)) {
      return avisar(context, 'Completa tus datos, el detalle y tu pedido.');
    }
    final monto = double.tryParse(_monto.text.replaceAll(',', '.'));
    setState(() => _enviando = true);
    await intentar(context, () async {
      final r = await ref.read(apiProvider).presentarReclamo({
        'tipo': _tipo,
        'nombre': _nombre.text.trim(),
        'documento': _documento.text.trim(),
        'correo': _correo.text.trim(),
        'domicilio': _domicilio.text.trim(),
        'servicioId': ?widget.servicioId,
        if (monto != null) 'montoReclamado': (monto * 100).round(),
        'detalle': _detalle.text.trim(),
        'pedido': _pedido.text.trim(),
      });
      if (mounted) setState(() => _constancia = r);
    });
    if (mounted) setState(() => _enviando = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_constancia != null) return _Constancia(constancia: _constancia!, correo: _correo.text.trim());
    final servicio = widget.servicioId == null ? null : ref.watch(servicioProvider(widget.servicioId!)).value;
    return PantallaMican(
      titulo: 'Libro de reclamaciones',
      espacio: 16,
      barraAccion: BarraAccion(
        children: [
          Expanded(
            child: Boton(
              'Enviar ${_tipo == 'reclamo' ? 'reclamo' : 'queja'}',
              cargando: _enviando,
              alPresionar: _enviar,
            ),
          ),
        ],
      ),
      children: [
        const Aviso(
          icono: MicanIcono.documento,
          texto:
              'Conforme al Código de Protección y Defensa del Consumidor, te responderemos en un máximo de 15 días hábiles.',
        ),
        SelectorSegmentado(
          opciones: const ['Reclamo', 'Queja'],
          indice: _tipo == 'reclamo' ? 0 : 1,
          alCambiar: (i) => setState(() => _tipo = i == 0 ? 'reclamo' : 'queja'),
        ),
        Text(
          _tipo == 'reclamo'
              ? 'Reclamo: disconformidad con el servicio contratado.'
              : 'Queja: malestar por la atención, no relacionado al servicio en sí.',
          style: MicanTexto.leyenda,
        ),
        if (servicio != null)
          Tarjeta(
            padding: const EdgeInsets.all(12),
            child: FilaResumen(
              'Servicio',
              '${servicio.tipo.nombre} · ${servicio.mascota.nombre} · ${fechaRelativa(servicio.creadoEn, conHora: false)}',
            ),
          ),
        TituloSeccion('Tus datos'),
        CampoTexto(etiqueta: 'Nombre completo', controlador: _nombre, mayusculas: TextCapitalization.words),
        CampoTexto(etiqueta: 'DNI o carné de extranjería', controlador: _documento, teclado: TextInputType.number),
        CampoTexto(
          etiqueta: 'Correo (te enviaremos la constancia)',
          controlador: _correo,
          teclado: TextInputType.emailAddress,
          mayusculas: TextCapitalization.none,
        ),
        CampoTexto(etiqueta: 'Domicilio (opcional)', controlador: _domicilio),
        TituloSeccion('Detalle'),
        if (_tipo == 'reclamo')
          CampoTexto(
            etiqueta: 'Monto reclamado (opcional)',
            controlador: _monto,
            prefijo: 'S/ ',
            teclado: const TextInputType.numberWithOptions(decimal: true),
          ),
        CampoTexto(etiqueta: '¿Qué pasó?', controlador: _detalle, lineas: 5, maxCaracteres: 3000),
        CampoTexto(etiqueta: '¿Qué solicitas?', controlador: _pedido, lineas: 3, maxCaracteres: 1500),
      ],
    );
  }
}

class _Constancia extends StatelessWidget {
  const _Constancia({required this.constancia, required this.correo});

  final Json constancia;
  final String correo;

  @override
  Widget build(BuildContext context) {
    final vence = fecha(constancia['venceEn']);
    return PantallaMican(
      titulo: 'Constancia',
      espacio: 16,
      barraAccion: BarraAccion(
        children: [Expanded(child: Boton('Listo', alPresionar: () => context.pop()))],
      ),
      children: [
        const SizedBox(height: 16),
        const Center(
          child: CajaIcono(
            MicanIcono.verificado,
            tamano: 80,
            tamanoIcono: 40,
            radio: 999,
            fondo: MicanColores.exitoSuave,
            color: MicanColores.exito,
          ),
        ),
        Text(
          'Registramos tu ${constancia['numero'] ?? 'reclamo'}',
          style: MicanTexto.titulo1,
          textAlign: TextAlign.center,
        ),
        Text(
          'Enviamos la constancia a $correo. Te responderemos hasta el ${vence == null ? 'plazo legal' : fechaRelativa(vence, conHora: false).toLowerCase()}.',
          style: MicanTexto.cuerpo.copyWith(color: MicanColores.textoSecundario),
          textAlign: TextAlign.center,
        ),
        Tarjeta(
          child: Column(
            children: [
              FilaResumen('N.º de registro', '${constancia['numero'] ?? '—'}', fuerte: true),
              const SizedBox(height: 10),
              FilaResumen('Plazo de respuesta', '${constancia['plazoDiasHabiles'] ?? 15} días hábiles'),
            ],
          ),
        ),
      ],
    );
  }
}
