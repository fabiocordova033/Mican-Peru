import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../componentes/base.dart';
import '../../componentes/estructura.dart';
import '../../datos/modelos.dart';
import '../../datos/proveedores.dart';
import '../../tema/colores.dart';
import '../../tema/iconos.dart';
import '../../tema/tipografia.dart';
import '../../util/ui.dart';

/// Opciones de temperamento. Las de [alertasTemperamento] se le resaltan
/// al cuidador (functions/src/callable/mascotas.ts → ETIQUETAS_ALERTA).
const temperamentos = [
  'Juguetón',
  'Tranquilo',
  'Sociable',
  'Tímido',
  'Jala la correa',
  'Reactivo con perros',
  'Reactivo con gatos',
  'Reactivo con personas',
  'Muerde',
  'Se escapa',
];
const alertasTemperamento = {
  'Reactivo con perros',
  'Reactivo con gatos',
  'Reactivo con personas',
  'Muerde',
  'Se escapa',
};

/// Pantalla 19 · Agregar mascota (HU-06) y edición (HU-07).
class PantallaAgregarMascota extends ConsumerStatefulWidget {
  const PantallaAgregarMascota({super.key, this.mascotaId});

  final String? mascotaId;

  @override
  ConsumerState<PantallaAgregarMascota> createState() => _PantallaAgregarMascotaState();
}

class _PantallaAgregarMascotaState extends ConsumerState<PantallaAgregarMascota> {
  final _nombre = TextEditingController();
  final _raza = TextEditingController();
  final _edad = TextEditingController();
  final _peso = TextEditingController();
  final _notas = TextEditingController();
  String _especie = 'perro';
  String _tamano = 'mediano';
  final _temperamento = <String>{};
  final _vacunas = <Vacuna>[];
  String? _fotoUrl;
  bool _guardando = false;
  bool _subiendoFoto = false;
  bool _cargado = false;

  bool get _editando => widget.mascotaId != null;

  void _cargar(Mascota m) {
    _cargado = true;
    _nombre.text = m.nombre;
    _raza.text = m.raza;
    _edad.text = m.edadAnios == null ? '' : _numero(m.edadAnios!);
    _peso.text = m.pesoKg == null ? '' : _numero(m.pesoKg!);
    _notas.text = m.notas;
    _especie = m.especie;
    _tamano = m.tamano;
    _temperamento.addAll(m.temperamento);
    _vacunas.addAll(m.vacunas);
    _fotoUrl = m.fotoUrl;
  }

  static String _numero(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Future<void> _foto() async {
    final uid = ref.read(uidProvider);
    if (uid == null) return;
    setState(() => _subiendoFoto = true);
    await intentar(context, () async {
      final url = await ref.read(archivosProvider).fotoUsuario(uid, 'mascotas');
      if (url != null && mounted) setState(() => _fotoUrl = url);
    });
    if (mounted) setState(() => _subiendoFoto = false);
  }

  Future<void> _agregarVacuna() async {
    final v = await mostrarHoja<Vacuna>(context, builder: (_) => const _HojaVacuna());
    if (v != null) setState(() => _vacunas.add(v));
  }

  Future<void> _guardar() async {
    if (_nombre.text.trim().isEmpty) return avisar(context, 'Escribe el nombre de tu mascota.');
    final datos = <String, dynamic>{
      'nombre': _nombre.text.trim(),
      'especie': _especie,
      'raza': _raza.text.trim(),
      'tamano': _tamano,
      if (double.tryParse(_edad.text.replaceAll(',', '.')) case final e?) 'edadAnios': e,
      if (double.tryParse(_peso.text.replaceAll(',', '.')) case final p?) 'pesoKg': p,
      'fotoUrl': _fotoUrl,
      'temperamento': _temperamento.toList(),
      'vacunas': [for (final v in _vacunas) v.aJson()],
      'notas': _notas.text.trim(),
    };
    setState(() => _guardando = true);
    final api = ref.read(apiProvider);
    final ok = await intentar(context, () async {
      if (_editando) {
        await api.actualizarMascota(widget.mascotaId!, datos);
      } else {
        await api.crearMascota(datos);
      }
    });
    if (!mounted) return;
    setState(() => _guardando = false);
    if (ok) context.pop();
  }

  Future<void> _archivar() async {
    final ok = await confirmar(
      context,
      titulo: '¿Quitar a ${_nombre.text}?',
      texto: 'Dejará de aparecer en tus mascotas. Su historial de servicios se mantiene.',
      si: 'Sí, quitar',
      peligro: true,
    );
    if (!ok || !mounted) return;
    final hecho = await intentar(context, () => ref.read(apiProvider).archivarMascota(widget.mascotaId!));
    if (hecho && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_editando && !_cargado) {
      final m = ref.watch(mascotaProvider(widget.mascotaId!));
      if (m == null) return const Scaffold(body: Cargando());
      _cargar(m);
    }
    return PantallaMican(
      titulo: _editando ? 'Editar mascota' : 'Agregar mascota',
      espacio: 16,
      barraAccion: BarraAccion(
        children: [
          Expanded(
            child: Boton(
              _editando ? 'Guardar cambios' : 'Guardar mascota',
              cargando: _guardando,
              alPresionar: _guardar,
            ),
          ),
        ],
      ),
      children: [
        Center(
          child: GestureDetector(
            onTap: _subiendoFoto ? null : _foto,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Avatar(
                  nombre: _nombre.text.isEmpty ? '?' : _nombre.text,
                  emoji: _especie == 'perro' ? '🐶' : '🐱',
                  fotoUrl: _fotoUrl,
                  tamano: 96,
                  fondo: MicanColores.acentoSuave,
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: MicanColores.primario,
                      shape: BoxShape.circle,
                      border: Border.all(color: MicanColores.fondoApp, width: 3),
                    ),
                    child: _subiendoFoto
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icono(MicanIcono.camara, tamano: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
        CampoTexto(
          etiqueta: 'Nombre',
          controlador: _nombre,
          pista: 'Ej. Rocky',
          maxCaracteres: 40,
          mayusculas: TextCapitalization.words,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Especie', style: MicanTexto.etiqueta),
            const SizedBox(height: 6),
            SelectorSegmentado(
              opciones: const ['🐶 Perro', '🐱 Gato'],
              indice: _especie == 'perro' ? 0 : 1,
              alCambiar: (i) => setState(() => _especie = i == 0 ? 'perro' : 'gato'),
            ),
          ],
        ),
        CampoTexto(etiqueta: 'Raza', controlador: _raza, pista: 'Ej. Golden Retriever o mestizo', maxCaracteres: 60),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tamaño', style: MicanTexto.etiqueta),
            const SizedBox(height: 6),
            GrupoChips<String>(
              opciones: const ['pequeno', 'mediano', 'grande'],
              etiqueta: (t) => switch (t) {
                'pequeno' => 'Pequeño · hasta 10 kg',
                'mediano' => 'Mediano · 10–25 kg',
                _ => 'Grande · +25 kg',
              },
              seleccionados: {_tamano},
              alCambiar: (t) => setState(() => _tamano = t),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: CampoTexto(
                etiqueta: 'Edad (años)',
                controlador: _edad,
                teclado: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CampoTexto(
                etiqueta: 'Peso (kg)',
                controlador: _peso,
                teclado: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Temperamento', style: MicanTexto.etiqueta),
            const SizedBox(height: 6),
            GrupoChips<String>(
              opciones: temperamentos,
              etiqueta: (t) => alertasTemperamento.contains(t) ? '⚠ $t' : t,
              seleccionados: _temperamento,
              alCambiar: (t) =>
                  setState(() => _temperamento.contains(t) ? _temperamento.remove(t) : _temperamento.add(t)),
            ),
            const SizedBox(height: 6),
            Text('Las marcadas con ⚠ se le resaltan al cuidador.', style: MicanTexto.leyenda),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Vacunas', style: MicanTexto.etiqueta)),
                GestureDetector(
                  onTap: _agregarVacuna,
                  child: Text('+ Agregar', style: MicanTexto.etiqueta.copyWith(color: MicanColores.primario)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_vacunas.isEmpty)
              Text('Opcional, pero ayuda a que acepten más rápido.', style: MicanTexto.leyenda)
            else
              for (var i = 0; i < _vacunas.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Tarjeta(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_vacunas[i].nombre, style: MicanTexto.cuerpoFuerte),
                              Text('Vence: ${_vacunas[i].vence}', style: MicanTexto.leyenda),
                            ],
                          ),
                        ),
                        BotonCircular(
                          icono: MicanIcono.cerrar,
                          tamano: 32,
                          tamanoIcono: 16,
                          fondo: MicanColores.superficieGris,
                          alPresionar: () => setState(() => _vacunas.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
        CampoTexto(
          etiqueta: 'Notas para el cuidador',
          controlador: _notas,
          lineas: 3,
          maxCaracteres: 500,
          pista: 'Ej. Le encanta la pelota. No le des comida de la calle.',
        ),
        if (_editando) Boton('Quitar mascota', tipo: TipoBoton.fantasma, alPresionar: _archivar),
      ],
    );
  }
}

class _HojaVacuna extends StatefulWidget {
  const _HojaVacuna();

  @override
  State<_HojaVacuna> createState() => _HojaVacunaState();
}

class _HojaVacunaState extends State<_HojaVacuna> {
  static const _comunes = ['Rabia', 'Séxtuple', 'Triple felina', 'Bordetella', 'Leptospirosis'];
  final _nombre = TextEditingController();
  DateTime? _aplicada;
  DateTime? _vence;

  String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<DateTime?> _fecha(DateTime inicial) => showDatePicker(
    context: context,
    initialDate: inicial,
    firstDate: DateTime(2010),
    lastDate: DateTime(DateTime.now().year + 5),
    locale: const Locale('es'),
  );

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Agregar vacuna', style: MicanTexto.titulo2),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in _comunes)
              ChipEtiqueta(c, seleccionado: _nombre.text == c, alPresionar: () => setState(() => _nombre.text = c)),
          ],
        ),
        const SizedBox(height: 12),
        CampoTexto(etiqueta: 'Nombre de la vacuna', controlador: _nombre, alCambiar: (_) => setState(() {})),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: CampoTexto(
                etiqueta: 'Aplicada',
                soloLectura: true,
                pista: _aplicada == null ? 'Elegir' : _iso(_aplicada!),
                alPresionar: () async {
                  final d = await _fecha(_aplicada ?? ahora);
                  if (d != null) setState(() => _aplicada = d);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CampoTexto(
                etiqueta: 'Vence',
                soloLectura: true,
                pista: _vence == null ? 'Elegir' : _iso(_vence!),
                alPresionar: () async {
                  final d = await _fecha(_vence ?? DateTime(ahora.year + 1, ahora.month, ahora.day));
                  if (d != null) setState(() => _vence = d);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Boton(
          'Agregar',
          alPresionar: _nombre.text.trim().isEmpty || _aplicada == null || _vence == null
              ? null
              : () => Navigator.pop(
                  context,
                  Vacuna(nombre: _nombre.text.trim(), aplicada: _iso(_aplicada!), vence: _iso(_vence!), estado: ''),
                ),
        ),
      ],
    );
  }
}
