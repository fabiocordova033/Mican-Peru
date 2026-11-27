# Mican · Panel de administración (web)

Panel para el equipo de Mican, hecho en **React + Vite + TypeScript** sobre el mismo Firebase del backend. Sigue la página **"04 · Panel admin (web)"** de Figma y los colores de "02 · Componentes" (los mismos de `app/lib/tema/colores.dart`).

| Sección | Qué hace |
|---|---|
| **Verificaciones** | Cola de cuidadores en revisión, ordenada por antigüedad, con horas en espera y lo que queda del plazo de 48 h (HU-04). Indicadores: pendientes, vencen pronto (40 h o más), aprobados y rechazados del mes. Pestañas de incompletos y rechazados. Búsqueda por nombre o DNI. |
| **Revisar cuidador** | DNI (anverso y reverso), antecedentes y selfie en grande, checklist de revisión, motivo de rechazo y **Aprobar / Rechazar** con la Cloud Function `revisarCuidador`. |
| **Recargas y comisiones** | Servicios completados del mes con la comisión del 12 %, total movido, recargas pagadas y desglose por tipo. |
| **Reportes y emergencias** | Libro de Reclamaciones (HU-30): reclamos y quejas con su plazo legal de 15 días hábiles. Solo lectura; la respuesta se envía por correo. |

"Usuarios" y "Servicios" aparecen en el menú como en el diseño, pero todavía no tienen pantalla.

## Cómo decide el checklist

Cada punto del checklist cubre documentos concretos:

| Punto | Documentos |
|---|---|
| La foto del DNI coincide con la selfie | Selfie |
| El DNI es legible y está vigente | DNI anverso y reverso |
| El certificado de antecedentes no registra delitos | Antecedentes |
| El certificado tiene menos de 3 meses | Antecedentes |

- **Aprobar** solo se activa con los 4 puntos marcados.
- **Rechazar** pide el motivo (el cuidador lo ve en la app) y manda como `documentosARehacer` los documentos cuyos puntos quedaron sin marcar. La tarjeta de esos documentos muestra "Revisar".

Toda la validación real la hace el backend: `revisarCuidador` y `enlacesDocumentosVerificacion` exigen el claim `admin`, y las reglas de Firestore y Storage solo dejan leer estos datos a administradores.

## Correr en local con los emuladores

```bash
# 1. Emuladores (en la raíz del repo)
cd functions && npm ci && npm run serve

# 2. En otra terminal: datos de prueba y el panel
cd admin
npm ci
npm run sembrar        # crea admin@mican.pe / mican123, cuidadores, servicios y reclamos de ejemplo
npm run dev            # http://localhost:5173
```

En los emuladores no hay cuenta de servicio para firmar URLs, así que el panel descarga los documentos con la sesión del admin. En producción usa los enlaces firmados de 15 minutos.

## Pruebas

```bash
npm test               # lógica del panel y pantallas con datos falsos (Vitest + Testing Library)
npm run typecheck
```

## Producción

1. En la consola de Firebase, activa **Correo electrónico/contraseña** en Authentication y crea la cuenta del administrador.
2. Dale el rol: `cd functions && node scripts/asignar-admin.js equipo@mican.pe` (con `GOOGLE_APPLICATION_CREDENTIALS`).
3. Registra una app web en el proyecto y copia `.env.example` a `.env.local` con sus datos (`VITE_USAR_EMULADORES=false`).
4. Despliega los índices nuevos y el panel en Firebase Hosting:

```bash
firebase deploy --only firestore:indexes,hosting
```

Para que el servidor pueda firmar los enlaces de los documentos, la cuenta de servicio de Cloud Functions necesita el rol **Creador de tokens de cuenta de servicio** (`roles/iam.serviceAccountTokenCreator`).
