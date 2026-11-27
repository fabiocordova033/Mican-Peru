import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mican/datos/ubicacion.dart';
import 'package:mican/pantallas/servicio/aviso_ubicacion_paseo.dart';
import 'package:mican/tema/tema.dart';

void main() {
  group('GPS del paseo (HU-16)', () {
    test('Android: en segundo plano usa un servicio en primer plano con notificación fija', () {
      final a = ajustesSeguimiento(TargetPlatform.android, enSegundoPlano: true) as AndroidSettings;
      expect(a.foregroundNotificationConfig, isNotNull);
      expect(a.foregroundNotificationConfig!.notificationTitle, 'Paseo en curso');
      expect(a.foregroundNotificationConfig!.setOngoing, isTrue);
      expect(a.foregroundNotificationConfig!.enableWakeLock, isTrue);
      expect(a.distanceFilter, 10);
    });

    test('Android: sin segundo plano no arranca el servicio', () {
      final a = ajustesSeguimiento(TargetPlatform.android, enSegundoPlano: false) as AndroidSettings;
      expect(a.foregroundNotificationConfig, isNull);
    });

    test('iOS: en segundo plano muestra el indicador azul y no se pausa sola', () {
      final a = ajustesSeguimiento(TargetPlatform.iOS, enSegundoPlano: true) as AppleSettings;
      expect(a.allowBackgroundLocationUpdates, isTrue);
      expect(a.showBackgroundLocationIndicator, isTrue);
      expect(a.pauseLocationUpdatesAutomatically, isFalse);
    });

    test('iOS: sin segundo plano no pide actualizaciones en segundo plano', () {
      final a = ajustesSeguimiento(TargetPlatform.iOS, enSegundoPlano: false) as AppleSettings;
      expect(a.allowBackgroundLocationUpdates, isFalse);
    });
  });

  testWidgets('El aviso destacado explica el uso en segundo plano y pide una acción explícita', (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    bool? respuesta;
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: temaMican(),
          home: Builder(
            builder: (c) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async => respuesta = await mostrarAvisoUbicacionPaseo(c),
                  child: const Text('Iniciar'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Iniciar'));
    await t.pumpAndSettle();
    expect(find.textContaining('incluso cuando la app está cerrada'), findsOneWidget);
    expect(find.text('Solo mientras el servicio está en curso'), findsOneWidget);
    await t.tap(find.text('Ahora no'));
    await t.pumpAndSettle();
    expect(respuesta, isFalse);

    await t.tap(find.text('Iniciar'));
    await t.pumpAndSettle();
    await t.tap(find.text('Entendido, continuar'));
    await t.pumpAndSettle();
    expect(respuesta, isTrue);
  });
}
