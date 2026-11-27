import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../componentes/base.dart';
import '../../datos/modelos.dart';
import '../../tema/colores.dart';
import '../../tema/iconos.dart';
import '../../tema/tipografia.dart';
import 'estado_login.dart';

/// Pantalla 01 · Bienvenida.
class PantallaBienvenida extends ConsumerWidget {
  const PantallaBienvenida({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rol = ref.watch(loginProvider).rol;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight - 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: LogoMican()),
                  const SizedBox(height: 20),
                  const _Ilustracion(),
                  const SizedBox(height: 20),
                  Text(
                    'Cuidadores de confianza para tu perro o gato',
                    style: MicanTexto.titulo1,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Paseos, visitas a domicilio y transporte. Tú propones el precio, ellos ofertan.',
                    style: MicanTexto.cuerpo.copyWith(color: MicanColores.textoSecundario),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  _Opcion(
                    icono: MicanIcono.huella,
                    titulo: 'Soy dueño de mascota',
                    texto: 'Encuentra paseadores y cuidadores cerca',
                    seleccionada: rol == Rol.dueno,
                    alPresionar: () => ref.read(loginProvider.notifier).elegirRol(Rol.dueno),
                  ),
                  const SizedBox(height: 20),
                  _Opcion(
                    icono: MicanIcono.escudo,
                    titulo: 'Quiero ser cuidador',
                    texto: 'Gana dinero cuidando mascotas',
                    seleccionada: rol == Rol.cuidador,
                    alPresionar: () => ref.read(loginProvider.notifier).elegirRol(Rol.cuidador),
                  ),
                  const SizedBox(height: 20),
                  Boton('Continuar', alPresionar: () => context.push('/ingresar')),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => context.push('/ingresar?login=1'),
                    child: Text(
                      '¿Ya tienes cuenta? Inicia sesión',
                      style: MicanTexto.etiqueta.copyWith(color: MicanColores.primario),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Ilustracion extends StatelessWidget {
  const _Ilustracion();

  @override
  Widget build(BuildContext context) {
    Widget circulo(String emoji, Color fondo) => Container(
      width: 120,
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fondo,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 6),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 56)),
    );
    return Container(
      height: 230,
      decoration: BoxDecoration(color: MicanColores.superficieTarjeta, borderRadius: BorderRadius.circular(28)),
      alignment: Alignment.center,
      child: SizedBox(
        width: 222,
        height: 120,
        child: Stack(
          children: [
            Positioned(left: 0, child: circulo('🐶', MicanColores.primarioSuave)),
            Positioned(right: 0, child: circulo('🐱', MicanColores.acentoSuave)),
          ],
        ),
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.icono,
    required this.titulo,
    required this.texto,
    required this.seleccionada,
    required this.alPresionar,
  });

  final MicanIcono icono;
  final String titulo;
  final String texto;
  final bool seleccionada;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: seleccionada,
      button: true,
      child: Tarjeta(
        padding: const EdgeInsets.all(14),
        alPresionar: alPresionar,
        borde: BorderSide(color: seleccionada ? MicanColores.primario : Colors.white, width: 2),
        child: Row(
          children: [
            CajaIcono(
              icono,
              tamano: 44,
              tamanoIcono: 24,
              fondo: seleccionada ? MicanColores.primario : MicanColores.primarioSuave,
              color: seleccionada ? Colors.white : MicanColores.textoPrincipal,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: MicanTexto.cuerpoFuerte),
                  const SizedBox(height: 2),
                  Text(texto, style: MicanTexto.leyenda),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
