import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../componentes/base.dart';
import '../../componentes/estructura.dart';
import '../../componentes/tarjetas.dart';
import '../../datos/proveedores.dart';
import '../../tema/colores.dart';
import '../../tema/iconos.dart';
import '../../tema/tipografia.dart';
import '../../util/ui.dart';

/// Pantalla 11 · Verificación del cuidador (HU-03). Los documentos van a
/// Storage (`verificaciones/{uid}/…`) y solo los ve el equipo de Mican.
class PantallaVerificacion extends ConsumerStatefulWidget {
  const PantallaVerificacion({super.key});

  @override
  ConsumerState<PantallaVerificacion> createState() => _PantallaVerificacionState();
}

class _PantallaVerificacionState extends ConsumerState<PantallaVerificacion> {
  static const _documentos = [
    ('dniFrente', 'DNI (frente)', 'Foto clara, sin reflejos', MicanIcono.documento, true),
    ('dniReverso', 'DNI (reverso)', 'Que se lean todos los datos', MicanIcono.documento, true),
    ('antecedentes', 'Certificado de antecedentes', 'Penales y policiales, menos de 3 meses', MicanIcono.escudo, true),
    ('selfie', 'Selfie', 'Tu rostro, de frente y con buena luz', MicanIcono.camara, true),
    ('cv', 'Experiencia (opcional)', 'CV o certificados con mascotas', MicanIcono.estrella, false),
  ];

  final _dni = TextEditingController();
  String? _subiendo;
  bool _enviando = false;

  Future<void> _subir(String tipo) async {
    final uid = ref.read(uidProvider);
    if (uid == null) return;
    final camara = tipo == 'selfie'
        ? true
        : await mostrarHoja<bool>(
            context,
            builder: (c) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Subir documento', style: MicanTexto.titulo2),
                const SizedBox(height: 14),
                Boton('Tomar foto', icono: MicanIcono.camara, alPresionar: () => Navigator.pop(c, true)),
                const SizedBox(height: 10),
                Boton('Elegir de la galería', tipo: TipoBoton.contorno, alPresionar: () => Navigator.pop(c, false)),
              ],
            ),
          );
    if (camara == null || !mounted) return;
    setState(() => _subiendo = tipo);
    await intentar(context, () => ref.read(archivosProvider).documentoVerificacion(uid, tipo, camara: camara));
    if (mounted) setState(() => _subiendo = null);
  }

  Future<void> _enviar() async {
    final dni = _dni.text.trim();
    if (dni.length != 8) return avisar(context, 'El DNI tiene 8 dígitos.');
    setState(() => _enviando = true);
    final ok = await intentar(context, () => ref.read(apiProvider).enviarAVerificacion(dni));
    if (!mounted) return;
    setState(() => _enviando = false);
    if (ok) avisar(context, 'Recibimos tus documentos. Te avisaremos en menos de 48 horas.');
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(verificacionProvider).value;
    final estado = v?.estado ?? 'incompleta';
    final docs = v?.documentos ?? const <String, String>{};
    final editable = estado == 'incompleta' || estado == 'rechazada';
    final subidos = _documentos.where((d) => d.$5 && _listo(docs[d.$1])).length;
    final obligatorios = _documentos.where((d) => d.$5).length;

    return PantallaMican(
      titulo: 'Verificación',
      espacio: 16,
      barraAccion: editable
          ? BarraAccion(
              children: [
                Expanded(
                  child: Boton(
                    'Enviar a revisión',
                    cargando: _enviando,
                    alPresionar: subidos == obligatorios ? _enviar : null,
                  ),
                ),
              ],
            )
          : null,
      children: [
        Tarjeta(
          color: MicanColores.primario,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icono(MicanIcono.escudo, tamano: 22, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(switch (estado) {
                      'en_revision' => 'Tus documentos están en revisión',
                      'aprobada' => '¡Ya estás verificado!',
                      'rechazada' => 'Hay documentos por corregir',
                      'revocada' => 'Verificación suspendida',
                      _ => 'Verifica tu identidad',
                    }, style: MicanTexto.cuerpoFuerte.copyWith(color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(switch (estado) {
                'en_revision' => 'Respondemos en menos de 48 horas.',
                'aprobada' => 'Los dueños verán tu insignia de verificado.',
                'rechazada' => v?.motivoRechazo ?? 'Vuelve a subir los documentos marcados.',
                'revocada' => 'Escríbenos a soporte para revisar tu caso.',
                _ => 'Los dueños confían más en cuidadores verificados.',
              }, style: MicanTexto.leyenda.copyWith(color: MicanColores.primarioSuave)),
              const SizedBox(height: 12),
              BarraProgreso(valor: subidos / obligatorios, fondo: MicanColores.primarioOscuro, alto: 8),
              const SizedBox(height: 6),
              Text('$subidos de $obligatorios obligatorios', style: MicanTexto.leyenda.copyWith(color: Colors.white)),
            ],
          ),
        ),
        ListaTarjeta(
          children: [
            for (final (tipo, titulo, ayuda, icono, _) in _documentos)
              FilaLista(
                icono: icono,
                fondoIcono: MicanColores.primarioSuave,
                titulo: titulo,
                subtitulo: docs[tipo] == 'rechazado' ? 'Rechazado: vuelve a subirlo' : ayuda,
                colorSubtitulo: docs[tipo] == 'rechazado' ? MicanColores.error : MicanColores.textoSecundario,
                alPresionar: editable && _subiendo == null ? () => _subir(tipo) : null,
                final_: _subiendo == tipo
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : _EstadoDocumento(docs[tipo]),
              ),
          ],
        ),
        if (editable) _CampoDni(controlador: _dni),
        const NotaConIcono(
          icono: MicanIcono.candado,
          texto:
              'Tus documentos son datos sensibles: solo los ve el equipo de verificación y el certificado de '
              'antecedentes se borra al aprobarte (Ley 29733).',
        ),
      ],
    );
  }

  static bool _listo(String? e) => e == 'subido' || e == 'en_revision' || e == 'listo' || e == 'aprobado';
}

class _EstadoDocumento extends StatelessWidget {
  const _EstadoDocumento(this.estado);

  final String? estado;

  @override
  Widget build(BuildContext context) {
    return switch (estado) {
      'subido' => const Pildora(
        texto: 'Subido',
        fondo: MicanColores.exitoSuave,
        color: MicanColores.exito,
        compacta: true,
      ),
      'en_revision' => const Pildora(
        texto: 'En revisión',
        fondo: MicanColores.acentoSuave,
        color: MicanColores.acento,
        compacta: true,
      ),
      'listo' || 'aprobado' => const Icono(MicanIcono.verificado, tamano: 22, color: MicanColores.exito),
      'rechazado' => const Pildora(
        texto: 'Rechazado',
        fondo: MicanColores.errorSuave,
        color: MicanColores.error,
        compacta: true,
      ),
      _ => const Pildora(
        texto: 'Subir',
        fondo: MicanColores.primarioSuave,
        color: MicanColores.primario,
        compacta: true,
      ),
    };
  }
}

class _CampoDni extends StatelessWidget {
  const _CampoDni({required this.controlador});

  final TextEditingController controlador;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Número de DNI', style: MicanTexto.etiqueta),
        const SizedBox(height: 6),
        TextField(
          controller: controlador,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
          style: MicanTexto.cuerpo,
          decoration: InputDecoration(
            hintText: '12345678',
            filled: true,
            fillColor: MicanColores.superficieTarjeta,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: const BorderSide(color: MicanColores.bordeFuerte, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }
}
