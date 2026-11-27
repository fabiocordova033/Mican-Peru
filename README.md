# Mican Peru · Backend

Backend de **Mican**, una app al estilo inDrive que une a dueños de perros y gatos con paseadores y cuidadores verificados en el Perú. El dueño propone un precio (o elige un paquete fijo), los cuidadores cercanos aceptan o contraofertan, y Mican cobra una comisión del **12 %** del saldo que el cuidador recarga.

> Proyecto universitario. Los montos y reglas marcados como *provisionales* se validarán en el piloto.

> La app móvil (Flutter, Android e iOS) está en [`app/`](app/README.md) y el panel web de administración (React) en [`admin/`](admin/README.md).

## Stack

| Pieza | Uso en Mican |
|---|---|
| **Firebase Auth** (SMS) | Registro con celular peruano (HU-01) |
| **Cloud Firestore** | Usuarios, mascotas, solicitudes, ofertas en tiempo real, ruta en vivo, chat, billetera |
| **Cloud Functions** (TypeScript, 2.ª gen., `southamerica-east1`) | Toda la lógica sensible: comisión, saldo, ofertas, estados, calificaciones, niveles, verificación, legal |
| **Cloud Storage** | DNI, antecedentes, selfie, fotos de mascotas y del servicio |
| **Cloud Messaging (FCM)** | Notificaciones push |
| **Cloud Scheduler** | Vencer ofertas (60 s), revelar calificaciones, cerrar chats, borrar cuentas |
| **Mercado Pago** (Checkout Pro) | Recargas y Premium con Yape, tarjeta o PagoEfectivo, confirmados por webhook firmado. En local se usa una pasarela **simulada** |

**Por qué Firebase:** las ofertas y contraofertas en vivo, la ruta del paseo y el chat necesitan tiempo real, y Firestore lo da sin montar servidores ni WebSockets. Para un equipo universitario además es gratis en el plan Spark/Blaze inicial y se prueba entero con emuladores.

**Alternativa considerada:** NestJS + PostgreSQL (+ Socket.IO). Conviene si el curso pide SQL/relacional o un servidor propio; la lógica de `src/dominio/` (comisión, precios, niveles, validaciones) es TypeScript puro y se puede reutilizar tal cual.

## Cómo está organizado

```
firebase.json            Emuladores y despliegue
firestore.rules          Quién puede leer/escribir qué (Firestore)
firestore.indexes.json   Índices compuestos
storage.rules            Reglas de archivos (documentos y fotos)
docs/modelo-de-datos.md  Colecciones, campos y estados
admin/                   Panel web de administración (React): verificación, reclamos, comisiones
functions/
  src/config/reglas.ts   ⭐ Todas las reglas de negocio y montos en un solo lugar
  src/dominio/           Lógica pura y probada: comisión, precios, niveles, vacunas, fechas
  src/lib/               Firebase, billetera, notificaciones, pasarela, correo
  src/callable/          Funciones que llama la app (una por acción)
  src/triggers/          Reacciones a Storage y al chat
  src/programadas/       Tareas cada minuto / hora / día
  test/dominio/          Pruebas unitarias (Jest)
  test/reglas/           Pruebas de las reglas de seguridad (emulador)
  test/integracion/      Flujo completo de punta a punta (emulador)
  scripts/               Asignar admin, simular un pago
```

**Principio de seguridad:** todo lo que mueve dinero o cambia estados pasa por Cloud Functions. La app solo lee, y escribe directamente en tres lugares: la ruta del paseo, los mensajes de texto del chat y sus tokens de notificación. Las reglas lo garantizan (y está probado).

**Dinero en céntimos:** todos los montos son enteros en céntimos (`2800` = S/ 28.00). Así la comisión de S/ 28 da exactamente S/ 3.36.

## Correr en local

Requisitos: Node 22 y Java 21 (para los emuladores).

```bash
cd functions
npm install
cp .secret.local.example .secret.local   # secretos de pagos para el emulador
cp .env.example .env.local               # opcional

npm test                 # 62 pruebas unitarias (dominio y pasarela)
npm run test:reglas      # 14 pruebas de reglas de Firestore y Storage
npm run test:integracion # flujo completo: registro → recarga → oferta → paseo → comisión → calificación
npm run serve            # levanta los emuladores con la UI en http://127.0.0.1:4000
```

Con los emuladores corriendo:

```bash
# Dar rol de administrador (para el panel web, que entra con correo)
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 node scripts/asignar-admin.js equipo@mican.pe
# o, más simple: cd ../admin && npm run sembrar (crea admin@mican.pe / mican123 y datos de ejemplo)
# Confirmar una recarga como si fuera la pasarela
node scripts/simular-pago.js <pagoId> 2000
```

Las tareas programadas necesitan el emulador de Pub/Sub; sin él, el emulador las omite (en producción corren con Cloud Scheduler).

## Desplegar

```bash
firebase use --add                                  # elegir el proyecto real
firebase functions:secrets:set PAGOS_WEBHOOK_SECRET
firebase functions:secrets:set MP_ACCESS_TOKEN     # aunque uses la pasarela simulada (pon cualquier texto)
firebase deploy --only firestore,storage,functions
```

## Pasarela de pago (Mercado Pago)

**Por qué Mercado Pago y no Culqi:** su Checkout Pro es una página alojada por Mercado Pago, así que la app solo abre una URL (lo que ya hacía con la pasarela simulada) y no hay que incrustar ningún SDK ni formulario de tarjeta. En Perú acepta **Yape, tarjetas de crédito y débito y PagoEfectivo**, se abre con una cuenta personal (sin RUC, ideal para el piloto universitario), trae credenciales y usuarios de prueba, y firma sus webhooks. Culqi también sirve, pero su checkout es un widget web que obliga a montar un WebView y pide una empresa para pasar a producción. **Plin no está entre los medios de Mercado Pago**; el cuidador que use Plin puede pagar con su tarjeta de débito.

### Cómo funciona

1. La app llama a `iniciarRecarga` o `suscribirPremium`. La función crea `pagos/{id}` en `pendiente` y una *preferencia* en Mercado Pago con `external_reference = id`, el monto en soles (el backend guarda céntimos y convierte solo aquí) y la cabecera `X-Idempotency-Key`. Devuelve `urlPago`.
2. La app abre `urlPago` en el navegador y el usuario paga.
3. Mercado Pago llama a `webhookPagos`. La función **verifica la firma** `x-signature` (HMAC-SHA256 con la clave secreta, sobre `id:<data.id>;request-id:<x-request-id>;ts:<ts>;`) y luego **consulta el pago** en `GET /v1/payments/{id}`: el estado y el monto salen de la API, nunca del aviso.
4. `procesarEventoPago` aplica el resultado en una transacción, **una sola vez** (`src/dominio/pagos.ts`):
   - aprobado → acredita el saldo o extiende Premium 30 días;
   - rechazado → marca `fallido` con el motivo (p. ej. "Fondos insuficientes"), y si luego paga con otro medio en el mismo checkout, se acredita;
   - avisos repetidos → no hacen nada; un rechazo tardío no deshace un pago aprobado;
   - un segundo cobro aprobado o un monto distinto → no se acredita y se abre un ticket en `soporteTickets` para devolverlo.
   - pendiente (p. ej. PagoEfectivo antes de pagar en agente) → espera el siguiente aviso.

Respuestas: 200 para todo aviso válido (aunque no cambie nada), 401 si la firma no corresponde, 500 solo ante un error transitorio para que Mercado Pago reintente.

**Premium mensual:** cada mes es un pago de S/ 7.50 por Checkout Pro (así se puede pagar con Yape). Al vencer, el job `diario` avisa al usuario para renovar. El cobro automático con tarjeta guardada (API de Suscripciones de Mercado Pago) queda como mejora: solo acepta tarjeta.

### Conectar tu cuenta (sandbox)

1. Crea una cuenta en [mercadopago.com.pe](https://www.mercadopago.com.pe) y entra a [Tus integraciones](https://www.mercadopago.com.pe/developers/panel/app) → **Crear aplicación** (producto: *Pagos online*, Checkout Pro).
2. En **Credenciales de prueba** copia el **Access Token**. En **Cuentas de prueba** crea un usuario *comprador* para pagar en el sandbox (con las tarjetas de prueba de la documentación).
3. Despliega una vez y copia la URL de `webhookPagos` (`https://southamerica-east1-<proyecto>.cloudfunctions.net/webhookPagos`).
4. En la aplicación de Mercado Pago → **Webhooks** → **Configurar notificaciones**: pega esa URL en *modo de prueba*, marca el evento **Pagos** y guarda. Copia la **clave secreta** que aparece ahí.
5. Guarda los secretos y la configuración:

   ```bash
   firebase functions:secrets:set MP_ACCESS_TOKEN        # el Access Token de prueba
   firebase functions:secrets:set PAGOS_WEBHOOK_SECRET   # la clave secreta del webhook
   ```

   y en `functions/.env.<proyecto>` (o `.env`):

   ```
   PASARELA=mercadopago
   MP_MODO=sandbox
   PAGOS_URL_WEBHOOK=https://southamerica-east1-<proyecto>.cloudfunctions.net/webhookPagos
   ```

6. `firebase deploy --only functions`. Desde la app, recarga S/ 20 y paga con el usuario comprador de prueba; el saldo se actualiza solo. En el panel puedes usar **Simular notificación**: con un id inventado la función responde 200 e ignora el aviso.

**Pasar a producción:** cambia los dos secretos por las credenciales y la clave de *modo productivo*, pon `MP_MODO=produccion`, configura el webhook en modo productivo y vuelve a desplegar. Antes, revisa comisiones de Mercado Pago y comprobantes SUNAT (abajo).

**En local** sigue `PASARELA=simulada`: `node scripts/simular-pago.js <pagoId> <montoCentimos> [pagado|fallido]` hace de webhook. Para probar Mercado Pago contra el emulador necesitas exponer el puerto 5001 con un túnel (p. ej. `ngrok http 5001`) y usar esa URL en `PAGOS_URL_WEBHOOK` y en el panel.

## Historias de usuario → funciones

| Historia | Dónde |
|---|---|
| HU-01 Registro con celular | Firebase Auth (SMS) + `completarRegistro` valida +51 9XXXXXXXX |
| HU-02 Elegir rol | `completarRegistro`, `activarRolCuidador`, `cambiarRolActivo` |
| HU-03 Enviar documentos | Storage `verificaciones/{uid}/…` + trigger `alSubirArchivo` + `enviarAVerificacion` |
| HU-04 Revisar cuidador (admin) | `revisarCuidador`, `enlacesDocumentosVerificacion` |
| HU-05 Proteger DNI y teléfono | `perfilesPublicos` sin datos sensibles; `servicios/{id}/privado/contacto` visible solo durante el servicio y 24 h después |
| HU-06 Registrar mascota | `crearMascota` (1 gratis, 5 con Premium), `actualizarMascota`, `archivarMascota` |
| HU-07 Vacunas | `dominio/vacunas.ts` (vigente / por vencer / vencida) |
| HU-08 Ver la mascota antes de aceptar | Copia de la mascota en la solicitud, con `alertas` |
| HU-09 Elegir servicio | `crearSolicitud` (paseo solo perros; transporte pide destino) |
| HU-10 Proponer precio | `cotizar` + `crearSolicitud` (rango sugerido, piso del 70 %, aviso) |
| HU-11 Paquete fijo | `crearSolicitud` modalidad `paquete` + `tomarPaquete` (el primero gana) |
| HU-12 Solicitudes cercanas | `listarSolicitudesCercanas` (3 km, geohash), `cambiarDisponibilidad`, aviso de saldo < S/ 10 |
| HU-13 Aceptar o contraofertar | `enviarOferta` (desglose de comisión, vence en 60 s) |
| HU-14 Comparar y elegir | `aceptarOferta` (rechaza las demás), `rechazarOferta` (avisa al cuidador, que puede volver a ofertar), job `cadaMinuto` sugiere subir precio a los 3 min, `subirPrecio` |
| HU-15 Iniciar y terminar | `iniciarServicio` (< 100 m), `finalizarServicio` (resumen + comisión) |
| HU-16 Paseo en vivo | La app escribe `servicios/{id}/ruta` cada ~10 m, también en segundo plano durante el servicio (reglas), y el dueño la escucha |
| HU-17 Fotos | Storage `servicios/{id}/fotos/` + trigger; visita exige 1 foto para finalizar |
| HU-18 Emergencia | `reportarEmergencia` |
| HU-19 Chat | `chats/{id}/mensajes` (reglas) + trigger `alCrearMensaje` (no leídos, push); se cierra 24 h después |
| HU-20 Actividad | Consultas de la app; reglas limitan a 30 días sin Premium |
| HU-21 Recargar saldo | `iniciarRecarga` + `webhookPagos` (Mercado Pago, firma verificada, idempotente) |
| HU-22 Comisión | `finalizarServicio` descuenta el 12 % y registra el movimiento; aviso si saldo < S/ 10 |
| HU-23 Pagar al cuidador | `metodoPago` (Yape, Plin, efectivo) en la solicitud y en el resumen |
| HU-24 Calificar | `calificar` (oculta hasta que ambos califiquen o pasen 7 días; 1-2 ★ van a soporte). Al revelarse, la del dueño se publica en `perfilesPublicos/{cuidador}/resenas` |
| HU-25 Niveles | `dominio/niveles.ts`, se recalcula al revelar calificaciones; `miProgresoNivel`; `registrarIncidente` |
| HU-26 Anuncios | Colección `anuncios` (lectura); la app no los muestra a Premium ni en paseo en vivo |
| HU-27 Premium | `suscribirPremium` (7 días gratis), `cancelarPremium`, job `diario` |
| HU-28 Términos y consentimientos | `completarRegistro` (18+, versiones, consentimientos separados), `aceptarNuevaVersion` |
| HU-29 Ubicación | Sin ubicación el cuidador no puede iniciar (`iniciarServicio`) |
| HU-30 Libro de Reclamaciones | `presentarReclamo` (correlativo R-AAAA-000001, 15 días hábiles, correo) |
| HU-31 Derechos ARCO | `exportarMisDatos`, `actualizarPerfil`, `actualizarConsentimiento`, `solicitarArco`, `datosEmpresa` |
| HU-32 Eliminar cuenta | `eliminarCuenta` (ELIMINAR, sin servicio activo, devolución de saldo), `recuperarCuenta`, purga a los 30 días |

## Reglas de negocio (provisionales)

Todas están en [`functions/src/config/reglas.ts`](functions/src/config/reglas.ts):

- Comisión 12 % por servicio completado, descontada del saldo del cuidador. La comisión reducida por nivel (10 % para Embajador) está lista pero **desactivada**.
- Saldo mínimo S/ 10, y suficiente para la comisión del precio ofertado. Un cuidador no puede tener dos servicios activos, así el saldo nunca queda negativo.
- Recarga de S/ 10 a S/ 500. Radio de 3 km. Ofertas vencen en 60 s; solicitudes en 15 min.
- Niveles: Nuevo (0-9), Confiable (10+, 4.5 ★), Experto (50+, 4.7 ★), Embajador (150+, 4.8 ★, 90 días sin incidentes).
- Premium S/ 7.50/mes con 7 días gratis: sin anuncios, historial completo y hasta 5 mascotas.

## Pendiente para producción

- Crear la cuenta de Mercado Pago y cargar las credenciales (ver *Pasarela de pago*). Cobro automático de Premium con la API de Suscripciones.
- Comprobantes electrónicos SUNAT (boleta/factura por comisión y Premium) vía OSE/PSE; definir si el 12 % incluye IGV.
- Calendario de feriados del Perú para los plazos en días hábiles.
- Política de cancelaciones y penalidades.
- Instalar la extensión *Trigger Email from Firestore* para enviar las constancias de reclamo.
- Términos, política de privacidad e inscripción del banco de datos ante la ANPD (trámites fuera de la app).
