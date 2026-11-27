import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mican/componentes/tarjetas.dart';
import 'package:mican/datos/modelos.dart';
import 'package:mican/tema/tema.dart';

Widget _envolver(Widget hijo) => ProviderScope(
  child: MaterialApp(
    theme: temaMican(),
    home: Scaffold(body: hijo),
  ),
);

void main() {
  test('Resena lee la reseña pública que escribe el backend', () {
    final r = Resena.desde('s1', {
      'autorNombre': 'Ana P.',
      'estrellas': 5,
      'etiquetas': ['Puntual', 'Cariñoso'],
      'comentario': 'Rocky volvió feliz',
      'tipoServicio': 'paseo',
      'mascotaNombre': 'Rocky',
      'creadoEn': Timestamp.fromDate(DateTime(2026, 11, 20)),
    });
    expect(r.autorNombre, 'Ana P.');
    expect(r.estrellas, 5);
    expect(r.etiquetas, ['Puntual', 'Cariñoso']);
    expect(r.contexto, 'Paseo con Rocky');
    expect(r.creadoEn, DateTime(2026, 11, 20));
  });

  test('Resena tolera documentos incompletos', () {
    final r = Resena.desde('s2', {'estrellas': 9});
    expect(r.autorNombre, 'Dueño de Mican');
    expect(r.estrellas, 5);
    expect(r.contexto, '');
    expect(r.etiquetas, isEmpty);
  });

  test('Oferta distingue "rechazada por el dueño" de "eligió otra"', () {
    final base = {'precio': 2800, 'estado': 'rechazada'};
    expect(Oferta.desde('c1', {...base, 'rechazadaPorDueno': true}).rechazadaPorDueno, isTrue);
    expect(Oferta.desde('c1', base).rechazadaPorDueno, isFalse);
  });

  testWidgets('TarjetaResena muestra autor, estrellas, comentario y etiquetas', (t) async {
    await t.pumpWidget(
      _envolver(
        const TarjetaResena(
          autor: 'Ana P.',
          estrellas: 4,
          fecha: 'Ayer',
          contexto: 'Paseo con Rocky',
          comentario: 'Muy puntual',
          etiquetas: ['Puntual'],
        ),
      ),
    );
    expect(find.text('Ana P.'), findsOneWidget);
    expect(find.text('Paseo con Rocky · Ayer'), findsOneWidget);
    expect(find.text('Muy puntual'), findsOneWidget);
    expect(find.text('Puntual'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == '4 de 5 estrellas'), findsOneWidget);
  });
}
