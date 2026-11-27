import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../componentes/base.dart';
import '../../componentes/estructura.dart';
import '../../componentes/tarjetas.dart';
import '../../datos/modelos.dart';
import '../../datos/proveedores.dart';
import '../../tema/colores.dart';
import '../../tema/iconos.dart';
import '../../tema/tipografia.dart';
import '../../util/ui.dart';
import 'documentos_legales.dart';

final _empresaProvider = FutureProvider<Json>((ref) => ref.watch(apiProvider).datosEmpresa());

/// Pantalla 26 · Privacidad y mis datos (Ley 29733): consentimientos,
/// derechos ARCO, descarga de datos y datos del titular.
class PantallaPrivacidad extends ConsumerWidget {
  const PantallaPrivacidad({super.key});

  static const _derechos = [
    ('acceso', 'Acceso', 'Saber qué datos tenemos y cómo los usamos'),
    ('rectificacion', 'Rectificación', 'Corregir datos inexactos'),
    ('cancelacion', 'Cancelación', 'Pedir que eliminemos datos'),
    ('oposicion', 'Oposición', 'Oponerte a un uso específico'),
  ];

  Future<void> _arco(BuildContext context, WidgetRef ref, String derecho, String nombre) async {
    final detalle = await pedirTexto(
      context,
      titulo: 'Derecho de $nombre',
      etiqueta: 'Cuéntanos tu solicitud',
      boton: 'Enviar solicitud',
    );
    if (detalle == null || detalle.isEmpty || !context.mounted) return;
    final ok = await intentar(context, () => ref.read(apiProvider).solicitarArco(derecho, detalle));
    if (ok && context.mounted) avisar(context, 'Recibimos tu solicitud. Respondemos en un máximo de 20 días hábiles.');
  }

  Future<void> _exportar(BuildContext context, WidgetRef ref) async {
    Json? datos;
    final ok = await intentar(context, () async => datos = await ref.read(apiProvider).exportarMisDatos());
    if (!ok || datos == null || !context.mounted) return;
    final texto = const JsonEncoder.withIndent('  ').convert(datos);
    await mostrarHoja(
      context,
      builder: (c) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tus datos', style: MicanTexto.titulo2),
          const SizedBox(height: 6),
          Text(
            '${(datos!['servicios'] as List?)?.length ?? 0} servicios · ${(datos!['mascotas'] as List?)?.length ?? 0} mascotas · '
            '${(datos!['movimientos'] as List?)?.length ?? 0} movimientos',
            style: MicanTexto.leyenda,
          ),
          const SizedBox(height: 12),
          Container(
            height: 260,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: MicanColores.superficieGris, borderRadius: BorderRadius.circular(14)),
            child: SingleChildScrollView(
              child: Text(texto, style: MicanTexto.leyenda.copyWith(fontFamily: 'monospace')),
            ),
          ),
          const SizedBox(height: 14),
          Boton(
            'Copiar (JSON)',
            alPresionar: () async {
              await Clipboard.setData(ClipboardData(text: texto));
              if (c.mounted) Navigator.pop(c);
              if (context.mounted) avisar(context, 'Copiado. Pégalo donde quieras guardarlo.');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(usuarioProvider).value;
    final empresa = ref.watch(_empresaProvider).value;
    final api = ref.read(apiProvider);
    return PantallaMican(
      titulo: 'Privacidad y mis datos',
      children: [
        const TituloSeccion('Tus permisos'),
        ListaTarjeta(
          children: [
            FilaLista(
              icono: MicanIcono.campana,
              titulo: 'Promociones y novedades',
              subtitulo: 'Ofertas de Mican y aliados',
              final_: Interruptor(
                activo: u?.aceptaPublicidad ?? false,
                alCambiar: (v) => intentar(context, () => api.actualizarConsentimiento('publicidad', v)),
              ),
            ),
            if (u?.esCuidador ?? false)
              FilaLista(
                icono: MicanIcono.escudo,
                titulo: 'Datos sensibles de cuidador',
                subtitulo: 'Selfie y antecedentes. Si lo retiras dejas de ser cuidador.',
                final_: Interruptor(
                  activo: true,
                  alCambiar: (v) async {
                    final ok = await confirmar(
                      context,
                      titulo: '¿Retirar tu autorización?',
                      texto: 'Dejarás de recibir solicitudes y tu verificación se revocará.',
                      si: 'Sí, retirar',
                      peligro: true,
                    );
                    if (ok && context.mounted) {
                      await intentar(context, () => api.actualizarConsentimiento('datosSensibles', false));
                    }
                  },
                ),
              ),
          ],
        ),
        const TituloSeccion('Tus derechos (ARCO)'),
        ListaTarjeta(
          children: [
            for (final (id, nombre, texto) in _derechos)
              FilaLista(
                icono: MicanIcono.documento,
                titulo: nombre,
                subtitulo: texto,
                alPresionar: () => _arco(context, ref, id, nombre.toLowerCase()),
                final_: const Icono(MicanIcono.chevron, tamano: 20, color: MicanColores.textoSecundario),
              ),
          ],
        ),
        Boton('Descargar mis datos', tipo: TipoBoton.contorno, alPresionar: () => _exportar(context, ref)),
        Boton(
          'Política de privacidad',
          tipo: TipoBoton.fantasma,
          alPresionar: () => verDocumentoLegal(context, DocumentoLegal.privacidad),
        ),
        if (empresa != null)
          Tarjeta(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Titular del banco de datos', style: MicanTexto.etiqueta),
                const SizedBox(height: 6),
                Text('${empresa['razonSocial']}', style: MicanTexto.cuerpoFuerte),
                Text('RUC ${empresa['ruc']} · ${empresa['domicilio']}', style: MicanTexto.leyenda),
                Text(
                  '${empresa['correoPrivacidad']}',
                  style: MicanTexto.leyenda.copyWith(color: MicanColores.primario),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
