import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mican/datos/modelos.dart';

void main() {
  final ahora = DateTime.now();

  Json servicio({String estado = 'completado', DateTime? calificarHasta}) => {
    'duenoId': 'd1',
    'duenoNombre': 'Ana Torres',
    'cuidadorId': 'c1',
    'cuidadorNombre': 'Luis Rojas',
    'mascotaId': 'm1',
    'mascota': {'nombre': 'Rocky', 'especie': 'perro', 'raza': 'Mestizo', 'tamano': 'mediano'},
    'tipo': 'paseo',
    'modalidad': 'oferta',
    'duracionMin': 60,
    'origen': {'lat': -12.12, 'lng': -77.03, 'direccion': 'Av. Larco 123'},
    'metodoPago': 'yape',
    'precioOfrecido': 2500,
    'precioFinal': 2800,
    'estado': estado,
    'creadoEn': Timestamp.fromDate(ahora),
    if (calificarHasta != null) 'calificarHasta': Timestamp.fromDate(calificarHasta),
  };

  test('Servicio lee el documento de Firestore', () {
    final s = Servicio.desde('s1', servicio(estado: 'en_curso'));
    expect(s.estado, EstadoServicio.enCurso);
    expect(s.estado.activo, isTrue);
    expect(s.tipo, TipoServicio.paseo);
    expect(s.precio, 2800, reason: 'usa el precio final si existe');
    expect(s.mascota.emoji, '🐶');
    expect(s.destino, isNull);
  });

  test('solo se califica un servicio completado dentro de los 7 días', () {
    expect(Servicio.desde('s', servicio(calificarHasta: ahora.add(const Duration(days: 2)))).puedeCalificar, isTrue);
    expect(
      Servicio.desde('s', servicio(calificarHasta: ahora.subtract(const Duration(days: 1)))).puedeCalificar,
      isFalse,
    );
    expect(
      Servicio.desde(
        's',
        servicio(estado: 'en_curso', calificarHasta: ahora.add(const Duration(days: 2))),
      ).puedeCalificar,
      isFalse,
    );
  });

  test('una oferta vence a los 60 s', () {
    Oferta oferta(DateTime expira, [String estado = 'pendiente']) => Oferta.desde('c1', {
      'cuidadorId': 'c1',
      'nombre': 'Luis',
      'precio': 3000,
      'estado': estado,
      'expiraEn': Timestamp.fromDate(expira),
    });
    expect(oferta(ahora.add(const Duration(seconds: 30))).vigente, isTrue);
    expect(oferta(ahora.subtract(const Duration(seconds: 1))).vigente, isFalse);
    expect(oferta(ahora.add(const Duration(seconds: 30)), 'rechazada').vigente, isFalse);
  });

  test('solicitud cercana acepta fechas en milisegundos', () {
    final s = SolicitudCercana.desde({
      'id': 'x',
      'tipo': 'transporte',
      'modalidad': 'paquete',
      'mascota': {'nombre': 'Michi', 'especie': 'gato'},
      'precioOfrecido': 3500,
      'destino': {'direccion': 'Vet San Borja'},
      'expiraEn': ahora.millisecondsSinceEpoch,
    });
    expect(s.esPaquete, isTrue);
    expect(s.destino, 'Vet San Borja');
    expect(s.mascota.emoji, '🐱');
  });
}
