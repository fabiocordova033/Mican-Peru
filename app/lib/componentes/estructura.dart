import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../tema/colores.dart';
import '../tema/iconos.dart';
import '../tema/tipografia.dart';

/// Botón redondo blanco de 40 px (Atrás, campana, cerrar).
class BotonCircular extends StatelessWidget {
  const BotonCircular({
    super.key,
    required this.icono,
    required this.alPresionar,
    this.fondo = MicanColores.superficieTarjeta,
    this.colorIcono = MicanColores.textoPrincipal,
    this.tamano = 40,
    this.tamanoIcono = 22,
  });

  final MicanIcono icono;
  final VoidCallback? alPresionar;
  final Color fondo;
  final Color colorIcono;
  final double tamano;
  final double tamanoIcono;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fondo,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alPresionar,
        child: SizedBox(
          width: tamano,
          height: tamano,
          child: Center(
            child: Icono(icono, tamano: tamanoIcono, color: colorIcono),
          ),
        ),
      ),
    );
  }
}

/// Componente "Barra superior": atrás + título (+ acción opcional).
class BarraSuperior extends StatelessWidget {
  const BarraSuperior({super.key, required this.titulo, this.accion, this.alVolver, this.mostrarAtras = true});

  final String titulo;
  final Widget? accion;
  final VoidCallback? alVolver;
  final bool mostrarAtras;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (mostrarAtras) ...[
              BotonCircular(
                icono: MicanIcono.atras,
                alPresionar: alVolver ?? () => context.canPop() ? context.pop() : context.go('/'),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(titulo, style: MicanTexto.titulo2, overflow: TextOverflow.ellipsis),
            ),
            if (accion != null) accion!,
          ],
        ),
      ),
    );
  }
}

/// "Barra de acción": franja blanca inferior con los botones principales.
class BarraAccion extends StatelessWidget {
  const BarraAccion({super.key, required this.children, this.vertical = false});

  final List<Widget> children;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final inferior = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + (inferior > 0 ? inferior : 22)),
      decoration: const BoxDecoration(
        color: MicanColores.superficieTarjeta,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: MicanSombras.flotante,
      ),
      child: vertical
          ? Column(mainAxisSize: MainAxisSize.min, children: _conEspacio(children, const SizedBox(height: 10)))
          : Row(children: _conEspacio(children, const SizedBox(width: 12))),
    );
  }

  static List<Widget> _conEspacio(List<Widget> ws, Widget espacio) => [
    for (var i = 0; i < ws.length; i++) ...[if (i > 0) espacio, ws[i]],
  ];
}

class ItemNavegacion {
  const ItemNavegacion(this.etiqueta, this.icono);
  final String etiqueta;
  final MicanIcono icono;
}

const itemsNavegacion = [
  ItemNavegacion('Inicio', MicanIcono.inicio),
  ItemNavegacion('Mensajes', MicanIcono.mensajes),
  ItemNavegacion('Actividad', MicanIcono.actividad),
  ItemNavegacion('Cuenta', MicanIcono.cuenta),
];

/// Componente "Navegación inferior" (Inicio, Mensajes, Actividad, Cuenta).
class NavegacionInferior extends StatelessWidget {
  const NavegacionInferior({super.key, required this.activo, required this.alCambiar, this.noLeidos = 0});

  final int activo;
  final ValueChanged<int> alCambiar;
  final int noLeidos;

  @override
  Widget build(BuildContext context) {
    final inferior = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, inferior > 0 ? inferior : 24),
      decoration: const BoxDecoration(
        color: MicanColores.superficieTarjeta,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Color(0x2E17262E), offset: Offset(0, -2), blurRadius: 10)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < itemsNavegacion.length; i++)
            _Item(
              item: itemsNavegacion[i],
              activo: i == activo,
              insignia: i == 1 ? noLeidos : 0,
              alPresionar: () => alCambiar(i),
            ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.item, required this.activo, required this.alPresionar, this.insignia = 0});

  final ItemNavegacion item;
  final bool activo;
  final VoidCallback alPresionar;
  final int insignia;

  @override
  Widget build(BuildContext context) {
    final color = activo ? MicanColores.primario : MicanColores.textoSecundario;
    return Semantics(
      button: true,
      selected: activo,
      label: item.etiqueta,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: alPresionar,
        child: SizedBox(
          width: 76,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    decoration: BoxDecoration(
                      color: activo ? MicanColores.primarioSuave : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Icono(item.icono, color: MicanColores.textoPrincipal),
                  ),
                  if (insignia > 0)
                    Positioned(
                      right: 10,
                      top: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(color: MicanColores.acento, shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(item.etiqueta, style: MicanTexto.nav.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Andamio de las pantallas con barra superior y contenido desplazable.
class PantallaMican extends StatelessWidget {
  const PantallaMican({
    super.key,
    this.titulo,
    required this.children,
    this.barraAccion,
    this.accion,
    this.fondo = MicanColores.fondoApp,
    this.espacio = 14,
    this.alVolver,
    this.mostrarAtras = true,
    this.alRefrescar,
  });

  final String? titulo;
  final List<Widget> children;
  final Widget? barraAccion;
  final Widget? accion;
  final Color fondo;
  final double espacio;
  final VoidCallback? alVolver;
  final bool mostrarAtras;
  final Future<void> Function()? alRefrescar;

  @override
  Widget build(BuildContext context) {
    Widget lista = ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(height: espacio), children[i]],
      ],
    );
    if (alRefrescar != null) lista = RefreshIndicator(onRefresh: alRefrescar!, child: lista);
    return Scaffold(
      backgroundColor: fondo,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (titulo != null)
              BarraSuperior(titulo: titulo!, accion: accion, alVolver: alVolver, mostrarAtras: mostrarAtras),
            Expanded(child: lista),
          ],
        ),
      ),
      bottomNavigationBar: barraAccion,
    );
  }
}

/// "Panel inferior" sobre el mapa, con su asa gris.
class PanelInferior extends StatelessWidget {
  const PanelInferior({super.key, required this.children, this.fondo = MicanColores.fondoApp});

  final List<Widget> children;
  final Color fondo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: MicanSombras.flotante,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(color: MicanColores.bordeSuave, borderRadius: BorderRadius.circular(3)),
            ),
          ),
          for (final c in children) ...[const SizedBox(height: 14), c],
        ],
      ),
    );
  }
}

/// Encabezado de sección ("Movimientos", "Esta semana"...), con acción opcional.
class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, {super.key, this.accion, this.alPresionarAccion});

  final String texto;
  final String? accion;
  final VoidCallback? alPresionarAccion;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(texto, style: MicanTexto.subtitulo)),
        if (accion != null)
          GestureDetector(
            onTap: alPresionarAccion,
            child: Text(accion!, style: MicanTexto.etiqueta.copyWith(color: MicanColores.primario)),
          ),
      ],
    );
  }
}
