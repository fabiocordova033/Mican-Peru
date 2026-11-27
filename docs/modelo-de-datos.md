# Modelo de datos (Firestore)

Montos en **céntimos** (enteros). Fechas como `Timestamp`. "Solo servidor" significa que la app no puede escribir: lo hace una Cloud Function.

## Colecciones

| Ruta | Quién lee | Quién escribe | Contenido |
|---|---|---|---|
| `usuarios/{uid}` | El propio usuario, admin | Solo servidor | Nombre, teléfono, DNI, fecha de nacimiento, roles, plan, consentimientos, estado de cuenta |
| `usuarios/{uid}/dispositivos/{token}` | El propio usuario | El propio usuario | Token FCM (`plataforma`, `actualizadoEn`) |
| `perfilesPublicos/{uid}` | Cualquier usuario autenticado | Solo servidor | Nombre, foto, edad, verificado, disponible, nivel, promedio, reseñas, etiquetas, experiencia, certificaciones, educación. **Sin DNI ni teléfono** |
| `perfilesPublicos/{uid}/resenas/{servicioId}` | Cualquier usuario autenticado | Solo servidor | Reseña pública del cuidador, ya revelada: `autorNombre` abreviado ("Ana P."), `autorFotoUrl`, `estrellas`, `etiquetas`, `comentario`, `tipoServicio`, `mascotaNombre`, `creadoEn`. Si el autor elimina su cuenta queda como "Usuario eliminado" |
| `mascotas/{id}` | Su dueño | Solo servidor | `duenoId`, nombre, especie, raza, tamaño, edad, peso, foto, vacunas (con estado), temperamento, alertas, notas |
| `verificaciones/{uid}` | El cuidador, admin | Solo servidor | Estado (`incompleta`, `en_revision`, `aprobada`, `rechazada`, `revocada`), estado de cada documento, motivo de rechazo, plazo de 48 h |
| `billeteras/{uid}` | El cuidador, admin | Solo servidor | `saldo` |
| `billeteras/{uid}/movimientos/{id}` | El cuidador, admin | Solo servidor | `tipo` (`recarga`, `comision`, `devolucion`, `ajuste`), `monto` con signo, `saldoResultante`, `servicioId`, `mascotaNombre` |
| `pagos/{id}` | Su dueño | Solo servidor | Recargas y Premium: `tipo`, `monto`, `estado` (`pendiente`, `pagado`, `fallido`), `proveedor`, `idCheckout` (preferencia de Mercado Pago), `idExterno` (id del pago en la pasarela), `motivo` si falló |
| `servicios/{id}` | Participantes; cuidadores verificados si `estado = buscando` | Solo servidor | Solicitud y servicio (ver abajo) |
| `servicios/{id}/ofertas/{cuidadorId}` | El dueño y ese cuidador | Solo servidor | Precio, comisión, lo que recibe, distancia, minutos de llegada, datos del cuidador, `estado` (`pendiente`, `aceptada`, `rechazada`, `expirada`), `rechazadaPorDueno`, `expiraEn` |
| `servicios/{id}/ruta/{punto}` | Participantes | Cuidador asignado, en curso | `lat`, `lng`, `registradoEn` |
| `servicios/{id}/fotos/{id}` | Participantes | Solo servidor (trigger) | Ruta en Storage |
| `servicios/{id}/calificaciones/{autorId}` | Su autor; ambos cuando `visible` | Solo servidor | Estrellas, etiquetas, comentario, `visible` |
| `servicios/{id}/eventos/{id}` | Participantes | Solo servidor | Iniciado, finalizado, cancelado, emergencia |
| `servicios/{id}/privado/contacto` | Participantes, mientras el servicio está activo y 24 h después | Solo servidor | Teléfonos de ambos |
| `chats/{servicioId}` | Participantes | Solo servidor (la app solo pone en 0 su `noLeidos`) | `abierto`, `cierraEn`, `noLeidos`, `ultimoMensaje` |
| `chats/{servicioId}/mensajes/{id}` | Participantes | Participantes con el chat abierto (texto) | `autorId`, `tipo` (`texto`, `foto`), `texto`, `creadoEn` |
| `reclamos/{id}` | Su autor, admin | Solo servidor | Libro de Reclamaciones: número, tipo, datos del consumidor, detalle, pedido, plazo |
| `solicitudesArco/{id}` | Su autor, admin | Solo servidor | Derecho, detalle, plazo |
| `emergencias/{id}` | Quien la reportó, admin | Solo servidor | Servicio, ubicación, detalle |
| `soporteTickets/{id}` | Su autor, admin | Solo servidor | Calificaciones bajas, devoluciones de saldo |
| `incidentes/{id}` | Admin | Solo servidor | Incidentes confirmados de un cuidador |
| `anuncios/{id}` | Autenticados | Admin | Patrocinadores (HU-26) |
| `ubicacionesCuidadores/{uid}` | Nadie (servidor) | Solo servidor | Última ubicación para avisar de solicitudes cercanas |
| `contadores/{nombre-año}`, `mail/{id}` | Nadie | Solo servidor | Correlativos y cola de correos |

## Documento `servicios/{id}`

```
duenoId, duenoNombre, cuidadorId, cuidadorNombre, participantes[]
mascotaId, mascota { nombre, especie, raza, tamano, temperamento[], alertas[], notas, fotoUrl }
tipo: paseo | visita | transporte
modalidad: oferta | paquete
duracionMin, distanciaKm
origen { lat, lng, direccion, geohash }, destino { lat, lng, direccion } | null
metodoPago: yape | plin | efectivo
rangoSugerido { minimo, maximo, piso } | null
precioOfrecido, precioFinal, comisionTasa, comision
estado, ofertasRecibidas, sugerenciaSubirPrecioEnviada
creadoEn, expiraEn, confirmadoEn, iniciadoEn, finalizadoEn
resumen { duracionRealMin, distanciaKm, precio, metodoPago, comision, recibeCuidador, fotos }
chatCierraEn, calificarHasta, calificacionesReveladas
```

## Estados del servicio

```
buscando ──(dueño acepta oferta / cuidador toma paquete)──> confirmado
confirmado ──(cuidador toca Iniciar a < 100 m)──> en_curso
en_curso ──(cuidador toca Finalizar: se cobra la comisión)──> completado
buscando | confirmado ──> cancelado
buscando ──(15 min sin cuidador)──> expirado
```

## Storage

| Ruta | Sube | Lee |
|---|---|---|
| `verificaciones/{uid}/{dniFrente\|dniReverso\|antecedentes\|selfie\|cv}[.ext]` | El cuidador (imagen o PDF, < 10 MB) | Solo admin. Los antecedentes se borran al aprobar |
| `servicios/{id}/fotos/{archivo}` | Cuidador asignado, con el servicio en curso | Participantes |
| `usuarios/{uid}/{perfil\|mascotas}/{archivo}` | El propio usuario (imagen < 5 MB) | Autenticados |
| `anuncios/{archivo}` | Admin | Autenticados |
