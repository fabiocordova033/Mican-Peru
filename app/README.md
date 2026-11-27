# Mican · App móvil (Flutter)

App de Mican para **Android e iOS**, hecha en Flutter a partir de los diseños de Figma
(página "02 Componentes" para tokens, tipografía, íconos y componentes; página
"03 Alta fidelidad" para las 27 pantallas). Habla con el backend de Firebase de este
mismo repositorio: Auth por SMS, Firestore en tiempo real, Cloud Functions, Storage y FCM.

## Requisitos

- Flutter 3.35 (Dart 3.9) o superior
- Android Studio con un emulador (API 23+) o Xcode 15+ con un simulador (iOS 13+)
- Node 22 y Java 21 para los emuladores de Firebase (ver el README de la raíz)

## Cómo correrla con los emuladores

```bash
# 1. En la raíz del repo: levanta Auth, Firestore, Functions y Storage
cd functions && npm ci && npm run serve        # emuladores con el proyecto demo-mican

# 2. En otra terminal: la app
cd app
flutter pub get
flutter run                                     # emulador de Android
flutter run --dart-define=HOST_EMULADOR=127.0.0.1   # simulador de iOS
```

Con los emuladores, el SMS no se envía de verdad: el código aparece en la consola del
emulador de Auth (http://localhost:4000/auth).

En un celular real en la misma red Wi-Fi, usa la IP de tu PC:
`--dart-define=HOST_EMULADOR=192.168.1.20`.

### Variables (`--dart-define`)

| Variable | Por defecto | Para qué |
|---|---|---|
| `USAR_EMULADORES` | `true` | `false` para usar el proyecto de Firebase real |
| `HOST_EMULADOR` | `10.0.2.2` | Dónde están los emuladores (10.0.2.2 = tu PC vista desde Android) |
| `FIREBASE_PROJECT_ID` | `demo-mican` | El mismo `--project` con que corren los emuladores |
| `MAPS_HABILITADO` | `false` | `true` cuando haya API key de Google Maps |
| `TELEFONO_SOPORTE` | `+51999999999` | Número de la hoja de emergencia |

## Conectar el proyecto de Firebase real

1. `dart pub global activate flutterfire_cli`
2. `flutterfire configure --project=<tu-proyecto>` (reemplaza `lib/firebase_options.dart` y
   agrega `google-services.json` y `GoogleService-Info.plist`)
3. `flutter run --dart-define=USAR_EMULADORES=false`

Las notificaciones push (FCM) solo se registran con el proyecto real.

## Google Maps

Sin API key, la app dibuja el **mapa ilustrado** del diseño (calles, parques y la ruta en
vivo proyectada encima). Para usar Google Maps:

- **Android:** agrega `MAPS_API_KEY=tu_clave` en `android/local.properties`.
- **iOS:** crea `ios/Flutter/Mapas.xcconfig` con `MAPS_API_KEY=tu_clave` (está en `.gitignore`).
- Corre con `--dart-define=MAPS_HABILITADO=true`.

## Cómo está organizada

```
lib/
  main.dart, app.dart, rutas.dart   Arranque, tema, rutas (go_router) y redirecciones por sesión
  config/entorno.dart               Variables de --dart-define
  tema/                             Colores, tipografía Nunito, íconos SVG del Figma
  componentes/                      Botón, chips, campos, tarjetas, mapa, barras, navegación
  datos/
    modelos.dart                    Lectura de Firestore (montos en céntimos, como el backend)
    api.dart                        Una función por cada Cloud Function callable
    proveedores.dart                Providers de Riverpod (sesión, servicios, ofertas, ruta, chat…)
    archivos.dart                   Subidas a Storage (fotos del servicio, documentos, mascotas)
  pantallas/
    inicio_sesion/                  01 Bienvenida, celular, 13 Código SMS, 23 Registro, 24 Ubicación
    dueno/                          02 Inicio, 03 Solicitar, 09 Mascotas, 19 Agregar mascota
    servicio/                       04 Ofertas, 05 Perfil del cuidador, 06/21/22 En curso,
                                    07 Calificar, 17 Actividad, 18 Finalizado, 20 Emergencia
    cuidador/                       14 Inicio, 15 Contraoferta, servicio en curso, 08 Billetera,
                                    16 Recargar, 11 Verificación
    mensajes/                       12 Mensajes y chat
    cuenta/                         Cuenta, 10 Premium
    legal/                          25 Libro de reclamaciones, 26 Privacidad, 27 Eliminar cuenta
test/                               Pruebas de formato, modelos y componentes
```

La app **no** escribe directo en Firestore nada que mueva dinero o cambie estados: todo eso
pasa por las Cloud Functions. Solo escribe lo que las reglas permiten: puntos de la ruta
(`servicios/{id}/ruta`), mensajes del chat y el token del dispositivo.

## Pruebas

```bash
flutter analyze
flutter test
```

## Pendiente

- **Búsqueda de direcciones:** el destino del transporte usa por ahora las coordenadas del
  recojo; falta autocompletar con Google Places cuando haya API key.
- **Reseñas públicas en el perfil del cuidador:** el backend aún no expone una lista de
  reseñas reveladas que cualquier dueño pueda leer; hoy se muestran nota, etiquetas y servicios.
- **Rechazar una oferta** solo la oculta en el celular del dueño (no hay callable para eso).
- **Pagos reales:** la pasarela del backend está simulada; la app abre la `urlPago` que devuelve.
- **Ruta en segundo plano:** el GPS registra la ruta mientras la app está abierta. Para seguir
  con la pantalla apagada hace falta un servicio en primer plano (Android) y el modo
  "location" de fondo (iOS).
- Íconos de la app, pantalla de arranque nativa y textos legales definitivos.
- Fuente Nunito: licencia SIL Open Font License 1.1 (Google Fonts).
