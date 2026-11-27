import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../componentes/base.dart';
import '../../config/entorno.dart';
import '../../datos/modelos.dart';
import '../../datos/proveedores.dart';
import '../../tema/colores.dart';
import '../../tema/iconos.dart';
import '../../tema/tipografia.dart';
import '../../util/ui.dart';

/// Pantalla 20 · Confirmar emergencia (HU-18). Cualquier opción registra la
/// emergencia en el servicio y abre un ticket urgente para soporte.
Future<void> mostrarEmergencia(BuildContext context, WidgetRef ref, Servicio servicio, {required bool soyDueno}) {
  return mostrarHoja(
    context,
    builder: (c) => _HojaEmergencia(servicio: servicio, soyDueno: soyDueno),
  );
}

class _HojaEmergencia extends ConsumerStatefulWidget {
  const _HojaEmergencia({required this.servicio, required this.soyDueno});

  final Servicio servicio;
  final bool soyDueno;

  @override
  ConsumerState<_HojaEmergencia> createState() => _HojaEmergenciaState();
}

class _HojaEmergenciaState extends ConsumerState<_HojaEmergencia> {
  Json? _reporte;
  bool _enviando = false;

  /// Registra la emergencia una sola vez y devuelve los teléfonos.
  Future<Json?> _reportar(String detalle) async {
    if (_reporte != null) return _reporte;
    setState(() => _enviando = true);
    try {
      final pos = await ref.read(ubicacionProvider).actual();
      _reporte = await ref
          .read(apiProvider)
          .reportarEmergencia(widget.servicio.id, detalle: detalle, lat: pos?.lat, lng: pos?.lng);
      return _reporte;
    } catch (e) {
      if (mounted) mostrarError(context, e);
      return null;
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _abrir(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      avisar(context, 'No pudimos abrir ${uri.scheme == 'tel' ? 'el teléfono' : 'la app'}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.servicio;
    final otro = widget.soyDueno ? (s.cuidadorNombre ?? 'tu cuidador') : s.duenoNombre;
    final primerNombre = otro.split(' ').first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: MicanColores.errorSuave, shape: BoxShape.circle),
            child: const Icono(MicanIcono.actividad, tamano: 32, color: MicanColores.error),
          ),
        ),
        const SizedBox(height: 14),
        Text('¿Qué está pasando?', style: MicanTexto.titulo1, textAlign: TextAlign.center),
        const SizedBox(height: 14),
        Text(
          'Elige una opción. Avisaremos a soporte de Mican y quedará registrado en el servicio.',
          style: MicanTexto.cuerpo.copyWith(color: MicanColores.textoSecundario),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        if (_enviando) const LinearProgressIndicator(minHeight: 2),
        _Opcion(
          icono: MicanIcono.corazon,
          titulo: 'Llamar a la veterinaria más cercana',
          texto: 'Busca veterinarias abiertas cerca de ti',
          peligro: true,
          alPresionar: () async {
            await _reportar('Necesita veterinaria');
            final pos = await ref.read(ubicacionProvider).actual();
            final q = pos == null ? 'veterinaria 24 horas' : 'veterinaria/@${pos.lat},${pos.lng},15z';
            await _abrir(Uri.parse('https://www.google.com/maps/search/${Uri.encodeComponent(q)}'));
          },
        ),
        _Opcion(
          icono: MicanIcono.cuenta,
          titulo: 'Llamar a $primerNombre (${widget.soyDueno ? 'cuidador' : 'dueño'})',
          texto: 'Su número se muestra solo en emergencias',
          alPresionar: () async {
            final r = await _reportar('Llamada a la otra parte');
            final tel = mapa(r?['llamarA'])['otraParte'] as String?;
            if (tel == null) {
              if (context.mounted) avisar(context, 'No encontramos su número. Llama a soporte.');
              return;
            }
            await _abrir(Uri(scheme: 'tel', path: tel));
          },
        ),
        _Opcion(
          icono: MicanIcono.mensajes,
          titulo: 'Hablar con soporte Mican',
          texto: 'Respuesta en menos de 2 min',
          alPresionar: () async {
            final r = await _reportar('Contactar soporte');
            final tel = mapa(r?['llamarA'])['soporteMican'] as String? ?? Entorno.telefonoSoporte;
            await _abrir(Uri(scheme: 'tel', path: tel));
          },
        ),
        _Opcion(
          icono: MicanIcono.ubicacion,
          titulo: 'Compartir ubicación en vivo',
          texto: 'Envía tu ubicación actual por WhatsApp',
          alPresionar: () async {
            await _reportar('Compartió su ubicación');
            final pos = await ref.read(ubicacionProvider).actual();
            final enlace = pos == null ? '' : ' https://maps.google.com/?q=${pos.lat},${pos.lng}';
            await _abrir(
              Uri.parse(
                'https://wa.me/?text=${Uri.encodeComponent('Emergencia durante un servicio de Mican con ${s.mascota.nombre}.$enlace')}',
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Boton('Cancelar, fue un error', tipo: TipoBoton.fantasma, alPresionar: () => Navigator.pop(context)),
      ],
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.icono,
    required this.titulo,
    required this.texto,
    required this.alPresionar,
    this.peligro = false,
  });

  final MicanIcono icono;
  final String titulo;
  final String texto;
  final VoidCallback alPresionar;
  final bool peligro;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: peligro ? MicanColores.errorSuaveTarjeta : MicanColores.superficieGris,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: alPresionar,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CajaIcono(
                  icono,
                  fondo: MicanColores.superficieTarjeta,
                  color: peligro ? MicanColores.error : MicanColores.textoPrincipal,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: MicanTexto.cuerpoFuerte.copyWith(
                          color: peligro ? MicanColores.error : MicanColores.textoPrincipal,
                        ),
                      ),
                      Text(texto, style: MicanTexto.leyenda),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
