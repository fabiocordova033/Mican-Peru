import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mican/componentes/base.dart';
import 'package:mican/componentes/tarjetas.dart';
import 'package:mican/datos/modelos.dart';
import 'package:mican/pantallas/cuidador/contraoferta.dart';
import 'package:mican/tema/iconos.dart';
import 'package:mican/tema/tema.dart';

Widget _envolver(Widget hijo) => ProviderScope(
  child: MaterialApp(theme: temaMican(), home: hijo),
);

void main() {
  testWidgets('Botón llama a su acción y se deshabilita sin ella', (t) async {
    var toques = 0;
    await t.pumpWidget(
      _envolver(
        Scaffold(
          body: Column(
            children: [
              Boton('Aceptar', alPresionar: () => toques++),
              const Boton('Deshabilitado', alPresionar: null),
            ],
          ),
        ),
      ),
    );
    await t.tap(find.text('Aceptar'));
    await t.tap(find.text('Deshabilitado'));
    expect(toques, 1);
  });

  testWidgets('Tarjeta de solicitud: paquete fijo no permite contraofertar', (t) async {
    Widget tarjeta(bool paquete) => _envolver(
      Scaffold(
        body: TarjetaSolicitud(
          icono: MicanIcono.ruta,
          titulo: 'Paseo · 1 h',
          subtitulo: '0.8 km',
          precio: 'S/ 25',
          metodoPago: 'Yape',
          mascota: 'Rocky',
          emojiMascota: '🐶',
          esPaquete: paquete,
          alAceptar: () {},
          alContraofertar: () {},
        ),
      ),
    );
    await t.pumpWidget(tarjeta(false));
    expect(find.text('Contraofertar'), findsOneWidget);
    expect(find.text('Aceptar S/ 25'), findsOneWidget);
    await t.pumpWidget(tarjeta(true));
    expect(find.text('Contraofertar'), findsNothing);
  });

  testWidgets('Contraoferta calcula comisión y lo que recibe el cuidador', (t) async {
    final solicitud = SolicitudCercana.desde({
      'id': 's1',
      'tipo': 'paseo',
      'modalidad': 'oferta',
      'mascota': {'nombre': 'Rocky', 'especie': 'perro'},
      'duracionMin': 60,
      'precioOfrecido': 2000,
      'distanciaKm': 0.8,
      'expiraEn': DateTime.now().millisecondsSinceEpoch,
    });
    await t.pumpWidget(_envolver(PantallaContraoferta(solicitud: solicitud)));
    // Por defecto propone S/ 5 más: S/ 25, comisión S/ 3, recibe S/ 22.
    expect(find.text('Enviar S/ 25'), findsOneWidget);
    expect(find.text('− S/ 3.00'), findsOneWidget);
    expect(find.text('S/ 22.00'), findsOneWidget);

    await t.tap(find.text('+ S/ 8'));
    await t.pump();
    expect(find.text('Enviar S/ 28'), findsOneWidget);
    expect(find.text('S/ 24.64'), findsOneWidget);
  });
}
