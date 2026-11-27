import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../legal/documentos_legales.dart';
import 'estado_login.dart';

/// Pantalla 23 · Términos y consentimientos (HU-01, HU-02, HU-28).
/// Se muestra tras verificar el celular si aún no hay cuenta en `usuarios/`.
class PantallaRegistro extends ConsumerStatefulWidget {
  const PantallaRegistro({super.key});

  @override
  ConsumerState<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends ConsumerState<PantallaRegistro> {
  final _nombre = TextEditingController();
  final _fecha = TextEditingController();
  bool _terminos = false;
  bool _privacidad = false;
  bool _publicidad = false;
  bool _datosSensibles = false;
  bool _guardando = false;

  /// "14 / 03 / 2001" → "2001-03-14", o null si no es válida.
  String? get _fechaIso {
    final d = _fecha.text.replaceAll(RegExp(r'\D'), '');
    if (d.length != 8) return null;
    final dia = int.parse(d.substring(0, 2)), mes = int.parse(d.substring(2, 4)), anio = int.parse(d.substring(4));
    final f = DateTime(anio, mes, dia);
    if (f.day != dia || f.month != mes || anio < 1900) return null;
    return '${d.substring(4)}-${d.substring(2, 4)}-${d.substring(0, 2)}';
  }

  bool get _mayorDeEdad {
    final iso = _fechaIso;
    if (iso == null) return false;
    final n = DateTime.parse(iso);
    final hoy = DateTime.now();
    var edad = hoy.year - n.year;
    if (hoy.month < n.month || (hoy.month == n.month && hoy.day < n.day)) edad--;
    return edad >= 18;
  }

  Future<void> _crear() async {
    final rol = ref.read(loginProvider).rol;
    if (_nombre.text.trim().isEmpty) return avisar(context, 'Ingresa tu nombre.');
    if (_fechaIso == null) return avisar(context, 'Revisa tu fecha de nacimiento (DD / MM / AAAA).');
    if (!_mayorDeEdad) return avisar(context, 'Mican es solo para mayores de 18 años.');
    if (!_terminos || !_privacidad) return avisar(context, 'Debes aceptar los términos y la política de privacidad.');
    if (rol == Rol.cuidador && !_datosSensibles) {
      return avisar(context, 'Para ser cuidador debes autorizar el uso de tu selfie y antecedentes.');
    }
    setState(() => _guardando = true);
    final ok = await intentar(context, () async {
      final api = ref.read(apiProvider);
      final v = await api.versionesLegales();
      await api.completarRegistro(
        nombre: _nombre.text.trim(),
        fechaNacimiento: _fechaIso!,
        rol: rol,
        versionTerminos: v['versionTerminos'] as String,
        versionPrivacidad: v['versionPrivacidad'] as String,
        aceptaPublicidad: _publicidad,
        aceptaDatosSensibles: rol == Rol.cuidador && _datosSensibles,
      );
    });
    if (!mounted) return;
    setState(() => _guardando = false);
    if (ok) context.go('/permiso-ubicacion');
  }

  @override
  Widget build(BuildContext context) {
    final rol = ref.watch(loginProvider).rol;
    return PantallaMican(
      titulo: 'Antes de empezar',
      alVolver: () async {
        await ref.read(authProvider).signOut();
        if (context.mounted) context.go('/');
      },
      barraAccion: BarraAccion(
        children: [
          Expanded(
            child: Boton('Crear cuenta', cargando: _guardando, alPresionar: _crear),
          ),
        ],
      ),
      children: [
        CampoTexto(
          etiqueta: 'Nombre y apellido',
          controlador: _nombre,
          pista: 'Ana Mendoza',
          mayusculas: TextCapitalization.words,
        ),
        CampoTexto(
          etiqueta: 'Fecha de nacimiento',
          controlador: _fecha,
          pista: 'DD / MM / AAAA',
          teclado: TextInputType.number,
          alCambiar: (v) {
            final d = v.replaceAll(RegExp(r'\D'), '');
            final f = [
              if (d.isNotEmpty) d.substring(0, d.length.clamp(0, 2)),
              if (d.length > 2) d.substring(2, d.length.clamp(2, 4)),
              if (d.length > 4) d.substring(4, d.length.clamp(4, 8)),
            ].join(' / ');
            if (f != v) {
              _fecha.value = TextEditingValue(
                text: f,
                selection: TextSelection.collapsed(offset: f.length),
              );
            }
            setState(() {});
          },
        ),
        Text('Debes tener 18 años o más para usar Mican.', style: MicanTexto.leyenda),
        Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Obligatorios', style: MicanTexto.etiqueta.copyWith(color: MicanColores.textoSecundario)),
              const SizedBox(height: 16),
              _Consentimiento(
                marcado: _terminos,
                texto: 'Acepto los Términos y condiciones',
                enlace: 'Leer términos',
                alCambiar: (v) => setState(() => _terminos = v),
                alLeer: () => verDocumentoLegal(context, DocumentoLegal.terminos),
              ),
              const SizedBox(height: 16),
              _Consentimiento(
                marcado: _privacidad,
                texto: 'Acepto la Política de privacidad y el tratamiento de mis datos para usar la app',
                enlace: 'Leer política de privacidad',
                alCambiar: (v) => setState(() => _privacidad = v),
                alLeer: () => verDocumentoLegal(context, DocumentoLegal.privacidad),
              ),
              if (rol == Rol.cuidador) ...[
                const SizedBox(height: 16),
                _Consentimiento(
                  marcado: _datosSensibles,
                  texto: 'Autorizo el uso de mi selfie y certificado de antecedentes para verificar mi identidad',
                  nota: 'Datos sensibles: solo los ve el equipo de verificación de Mican.',
                  alCambiar: (v) => setState(() => _datosSensibles = v),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(height: 1, color: MicanColores.bordeSuave),
              const SizedBox(height: 16),
              Text('Opcional', style: MicanTexto.etiqueta.copyWith(color: MicanColores.textoSecundario)),
              const SizedBox(height: 16),
              _Consentimiento(
                marcado: _publicidad,
                texto: 'Quiero recibir promociones de Mican y de sus patrocinadores (veterinarias y pet shops)',
                nota: 'Puedes cambiarlo cuando quieras en Privacidad.',
                alCambiar: (v) => setState(() => _publicidad = v),
              ),
            ],
          ),
        ),
        const Aviso(
          icono: MicanIcono.escudo,
          texto:
              'Responsable de tus datos: Mican Perú S.A.C. Tus datos se usan solo para prestar el servicio (Ley 29733).',
        ),
      ],
    );
  }
}

class _Consentimiento extends StatelessWidget {
  const _Consentimiento({
    required this.marcado,
    required this.texto,
    required this.alCambiar,
    this.enlace,
    this.alLeer,
    this.nota,
  });

  final bool marcado;
  final String texto;
  final ValueChanged<bool> alCambiar;
  final String? enlace;
  final VoidCallback? alLeer;
  final String? nota;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          alCambiar(!marcado);
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              checked: marcado,
              child: Casilla(marcada: marcado),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(texto, style: MicanTexto.cuerpo),
                  const SizedBox(height: 2),
                  if (enlace != null)
                    GestureDetector(
                      onTap: alLeer,
                      child: Text(enlace!, style: MicanTexto.etiqueta.copyWith(color: MicanColores.primario)),
                    ),
                  if (nota != null) Text(nota!, style: MicanTexto.leyenda),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
