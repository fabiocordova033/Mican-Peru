import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mican/util/formato.dart';
import 'package:mican/util/geo.dart';
import 'package:mican/datos/modelos.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  group('soles', () {
    test('formatea céntimos como el backend', () {
      expect(soles(2800), 'S/ 28.00');
      expect(soles(-336), '− S/ 3.36');
      expect(solesCortos(2500), 'S/ 25');
      expect(solesCortos(2550), 'S/ 25.50');
    });

    test('comisión del 12 % redondeada al céntimo', () {
      expect(comision(2500), 300);
      expect(comision(2800), 336);
      expect(comision(1250), 150);
    });
  });

  test('duración legible', () {
    expect(duracion(30), '30 min');
    expect(duracion(60), '1 h');
    expect(duracion(90), '1 h 30 min');
  });

  test('edad de la mascota', () {
    expect(edad(0.5), '6 meses');
    expect(edad(1), '1 año');
    expect(edad(3.2), '3 años');
  });

  test('fecha relativa de hoy y ayer', () {
    final ahora = DateTime.now();
    expect(fechaRelativa(ahora, conHora: false), 'Hoy');
    expect(fechaRelativa(ahora.subtract(const Duration(days: 1)), conHora: false), 'Ayer');
  });

  test('distancia de una ruta', () {
    final ruta = [Lugar(lat: -12.1211, lng: -77.0297), Lugar(lat: -12.1301, lng: -77.0297)];
    expect(distanciaRutaKm(ruta), closeTo(1.0, 0.05));
  });
}
