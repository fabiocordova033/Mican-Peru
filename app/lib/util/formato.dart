import 'package:intl/intl.dart';

/// 2800 → "S/ 28.00". Igual que `formatearSoles` del backend.
String soles(int centimos) {
  final signo = centimos < 0 ? '− ' : '';
  return '${signo}S/ ${(centimos.abs() / 100).toStringAsFixed(2)}';
}

/// 2800 → "S/ 28" (precios enteros de las ofertas).
String solesCortos(int centimos) {
  if (centimos % 100 != 0) return soles(centimos);
  final signo = centimos < 0 ? '− ' : '';
  return '${signo}S/ ${centimos.abs() ~/ 100}';
}

/// Comisión del 12 % redondeada al céntimo (como `calcularComision`).
int comision(int precioCentimos, [double tasa = 0.12]) => (precioCentimos * tasa).round();

String duracion(int minutos) {
  if (minutos < 60) return '$minutos min';
  final h = minutos ~/ 60;
  final m = minutos % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

String metodoPago(String m) => switch (m) {
  'yape' => 'Yape',
  'plin' => 'Plin',
  'efectivo' => 'Efectivo',
  _ => m,
};

String tamano(String t) => switch (t) {
  'pequeno' => 'Pequeño',
  'mediano' => 'Mediano',
  'grande' => 'Grande',
  _ => t,
};

String edad(double? anios) {
  if (anios == null) return '';
  if (anios < 1) return '${(anios * 12).round()} meses';
  final n = anios.round();
  return n == 1 ? '1 año' : '$n años';
}

final _hora = DateFormat('HH:mm');
final _diaCorto = DateFormat("EEE d MMM", 'es');
final _mesAnio = DateFormat('MM/yyyy');

String hora(DateTime? f) => f == null ? '' : _hora.format(f);

/// "Hoy 11:30", "Ayer 18:02" o "Mar 25 nov".
String fechaRelativa(DateTime? f, {bool conHora = true}) {
  if (f == null) return '';
  final hoy = DateTime.now();
  final d = DateTime(f.year, f.month, f.day);
  final dias = DateTime(hoy.year, hoy.month, hoy.day).difference(d).inDays;
  final h = conHora ? ' ${_hora.format(f)}' : '';
  if (dias == 0) return 'Hoy$h';
  if (dias == 1) return 'Ayer$h';
  final t = _diaCorto.format(f).replaceAll('.', '');
  return t[0].toUpperCase() + t.substring(1);
}

/// "10:42" hoy, "Ayer", o el día de la semana ("Lun").
String horaChat(DateTime? f) {
  if (f == null) return '';
  final hoy = DateTime.now();
  final dias = DateTime(hoy.year, hoy.month, hoy.day).difference(DateTime(f.year, f.month, f.day)).inDays;
  if (dias == 0) return _hora.format(f);
  if (dias == 1) return 'Ayer';
  if (dias < 7) {
    final t = DateFormat('EEE', 'es').format(f).replaceAll('.', '');
    return t[0].toUpperCase() + t.substring(1);
  }
  return DateFormat('dd/MM').format(f);
}

/// "2026-03-14" → "03/2026".
String mesAnio(String iso) {
  final f = DateTime.tryParse(iso);
  return f == null ? iso : _mesAnio.format(f);
}

String telefonoLegible(String e164) {
  final n = e164.replaceFirst('+51', '');
  if (n.length != 9) return e164;
  return '+51 ${n.substring(0, 3)} ${n.substring(3, 6)} ${n.substring(6)}';
}

String mmss(int segundos) {
  final s = segundos < 0 ? 0 : segundos;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}
