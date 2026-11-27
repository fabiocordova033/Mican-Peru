import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../componentes/base.dart';
import '../../componentes/estructura.dart';
import '../../datos/proveedores.dart';
import '../../tema/colores.dart';
import '../../tema/iconos.dart';
import '../../tema/tipografia.dart';
import '../../util/formato.dart';
import '../../util/ui.dart';

/// Pantalla 10 · Mican Premium (HU-27): S/ 7.50 al mes, 7 días gratis la
/// primera vez, sin anuncios, hasta 5 mascotas e historial completo.
class PantallaPremium extends ConsumerStatefulWidget {
  const PantallaPremium({super.key});

  @override
  ConsumerState<PantallaPremium> createState() => _PantallaPremiumState();
}

class _PantallaPremiumState extends ConsumerState<PantallaPremium> {
  bool _enviando = false;

  static const _beneficios = [
    (MicanIcono.cerrar, 'Sin anuncios', 'Una app más limpia y rápida'),
    (MicanIcono.huella, 'Hasta 5 mascotas', 'En el plan gratis solo 1'),
    (MicanIcono.calendario, 'Historial completo', 'Todos tus servicios, rutas y fotos'),
  ];

  Future<void> _suscribir() async {
    setState(() => _enviando = true);
    await intentar(context, () async {
      final r = await ref.read(apiProvider).suscribirPremium();
      if (r['urlPago'] is String) {
        await launchUrl(Uri.parse(r['urlPago'] as String), mode: LaunchMode.externalApplication);
        if (mounted) avisar(context, 'Activaremos Premium apenas se confirme el pago.');
      } else if (mounted) {
        avisar(context, r['prueba'] == true ? '¡Listo! Tienes 7 días de Premium gratis.' : 'Reactivamos tu Premium.');
      }
    });
    if (mounted) setState(() => _enviando = false);
  }

  Future<void> _cancelar() async {
    final ok = await confirmar(
      context,
      titulo: '¿Cancelar Premium?',
      texto: 'Seguirás con los beneficios hasta el final del periodo pagado. No se renovará.',
      si: 'Sí, cancelar',
      no: 'Mantener Premium',
      peligro: true,
    );
    if (!ok || !mounted) return;
    final hecho = await intentar(context, ref.read(apiProvider).cancelarPremium);
    if (hecho && mounted) avisar(context, 'Listo. No volveremos a cobrarte.');
  }

  @override
  Widget build(BuildContext context) {
    final u = ref.watch(usuarioProvider).value;
    final activo = u?.esPremium ?? false;
    final renueva = u?.renovacionAutomatica ?? false;

    return PantallaMican(
      titulo: 'Mican Premium',
      espacio: 16,
      barraAccion: BarraAccion(
        vertical: true,
        children: [
          if (!activo || !renueva)
            Boton(
              activo ? 'Reactivar renovación' : 'Probar 7 días gratis',
              tipo: TipoBoton.acento,
              cargando: _enviando,
              alPresionar: _suscribir,
            )
          else
            Boton('Cancelar Premium', tipo: TipoBoton.peligro, alPresionar: _cancelar),
          Text(
            activo ? '' : 'Luego S/ 7.50 al mes. Cancela cuando quieras.',
            style: MicanTexto.leyenda,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [MicanColores.primario, MicanColores.primarioOscuro],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(MicanMedidas.radioTarjeta),
          ),
          child: Column(
            children: [
              const CajaIcono(
                MicanIcono.corona,
                tamano: 64,
                tamanoIcono: 32,
                radio: 999,
                fondo: MicanColores.acento,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              Text('Mican Premium', style: MicanTexto.titulo1.copyWith(color: Colors.white)),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'S/ 7.50',
                      style: MicanTexto.display.copyWith(color: Colors.white),
                    ),
                    TextSpan(
                      text: ' /mes',
                      style: MicanTexto.cuerpo.copyWith(color: MicanColores.primarioSuave),
                    ),
                  ],
                ),
              ),
              if (activo) ...[
                const SizedBox(height: 8),
                Pildora(
                  texto: u!.enPrueba
                      ? 'Prueba gratis hasta el ${fechaRelativa(u.premiumHasta, conHora: false).toLowerCase()}'
                      : renueva
                      ? 'Activo · se renueva el ${fechaRelativa(u.premiumHasta, conHora: false).toLowerCase()}'
                      : 'Activo hasta el ${fechaRelativa(u.premiumHasta, conHora: false).toLowerCase()}',
                  fondo: MicanColores.acentoSuave,
                  color: MicanColores.acento,
                  compacta: true,
                ),
              ],
            ],
          ),
        ),
        for (final (icono, titulo, texto) in _beneficios)
          Row(
            children: [
              CajaIcono(icono, fondo: MicanColores.acentoSuave, color: MicanColores.acento),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: MicanTexto.cuerpoFuerte),
                    Text(texto, style: MicanTexto.leyenda),
                  ],
                ),
              ),
            ],
          ),
        const NotaConIcono(
          icono: MicanIcono.candado,
          texto: 'El pago se procesa en una pasarela segura. Puedes cancelar cuando quieras desde esta pantalla.',
        ),
      ],
    );
  }
}
