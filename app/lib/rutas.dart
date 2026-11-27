import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'componentes/base.dart';
import 'datos/modelos.dart';
import 'datos/proveedores.dart';
import 'pantallas/cuenta/premium.dart';
import 'pantallas/cuidador/billetera.dart';
import 'pantallas/cuidador/contraoferta.dart';
import 'pantallas/cuidador/verificacion.dart';
import 'pantallas/dueno/agregar_mascota.dart';
import 'pantallas/dueno/mascotas.dart';
import 'pantallas/dueno/solicitar.dart';
import 'pantallas/inicio_sesion/bienvenida.dart';
import 'pantallas/inicio_sesion/celular.dart';
import 'pantallas/inicio_sesion/permiso_ubicacion.dart';
import 'pantallas/inicio_sesion/registro.dart';
import 'pantallas/legal/eliminar_cuenta.dart';
import 'pantallas/legal/privacidad.dart';
import 'pantallas/legal/reclamo.dart';
import 'pantallas/mensajes/chat.dart';
import 'pantallas/servicio/calificar.dart';
import 'pantallas/servicio/perfil_cuidador.dart';
import 'pantallas/servicio/servicio.dart';
import 'pantallas/shell.dart';

/// Rutas sin sesión iniciada.
const _publicas = {'/', '/ingresar', '/codigo'};

/// Avisa a go_router cuando cambia la sesión o el documento del usuario.
class _Refresco extends ChangeNotifier {
  _Refresco(Ref ref) {
    ref.listen(sesionProvider, (_, _) => notifyListeners());
    ref.listen(usuarioProvider, (_, _) => notifyListeners());
  }
}

final rutasProvider = Provider<GoRouter>((ref) {
  final refresco = _Refresco(ref);
  ref.onDispose(refresco.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresco,
    redirect: (context, estado) {
      final ruta = estado.matchedLocation;
      final sesion = ref.read(sesionProvider);
      if (sesion.isLoading && !sesion.hasValue) return '/cargando';
      if (sesion.value == null) {
        return _publicas.contains(ruta) ? null : '/';
      }
      final usuario = ref.read(usuarioProvider);
      if (usuario.isLoading && !usuario.hasValue) return ruta == '/cargando' ? null : '/cargando';
      final u = usuario.value;
      if (u == null) return ruta == '/registro' || ruta == '/permiso-ubicacion' ? null : '/registro';
      if (u.estadoCuenta == 'eliminacion_pendiente') return ruta == '/recuperar-cuenta' ? null : '/recuperar-cuenta';
      if (_publicas.contains(ruta) || ruta == '/registro' || ruta == '/cargando' || ruta == '/recuperar-cuenta') {
        return '/app';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/cargando',
        builder: (_, _) => const Scaffold(body: Cargando()),
      ),
      GoRoute(path: '/', builder: (_, _) => const PantallaBienvenida()),
      GoRoute(
        path: '/ingresar',
        builder: (_, e) => PantallaCelular(esLogin: e.uri.queryParameters['login'] == '1'),
      ),
      GoRoute(path: '/codigo', builder: (_, _) => const PantallaCodigo()),
      GoRoute(path: '/registro', builder: (_, _) => const PantallaRegistro()),
      GoRoute(path: '/permiso-ubicacion', builder: (_, _) => const PantallaPermisoUbicacion()),
      GoRoute(path: '/recuperar-cuenta', builder: (_, _) => const PantallaRecuperarCuenta()),
      GoRoute(path: '/app', builder: (_, _) => const ShellMican()),
      GoRoute(
        path: '/solicitar',
        builder: (_, e) => PantallaSolicitar(tipo: TipoServicio.desde(e.uri.queryParameters['tipo'])),
      ),
      GoRoute(
        path: '/servicio/:id',
        builder: (_, e) => PantallaServicio(id: e.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'calificar',
            builder: (_, e) => PantallaCalificar(servicioId: e.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/cuidador/:uid',
        builder: (_, e) => PantallaPerfilCuidador(
          uid: e.pathParameters['uid']!,
          servicioId: e.uri.queryParameters['servicio'],
          precio: int.tryParse(e.uri.queryParameters['precio'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/contraoferta',
        redirect: (_, e) => e.extra is SolicitudCercana ? null : '/app',
        builder: (_, e) => PantallaContraoferta(solicitud: e.extra! as SolicitudCercana),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (_, e) => PantallaChat(chatId: e.pathParameters['id']!),
      ),
      GoRoute(path: '/mascotas', builder: (_, _) => const PantallaMascotas()),
      GoRoute(path: '/mascotas/nueva', builder: (_, _) => const PantallaAgregarMascota()),
      GoRoute(
        path: '/mascotas/:id',
        builder: (_, e) => PantallaAgregarMascota(mascotaId: e.pathParameters['id']),
      ),
      GoRoute(path: '/billetera', builder: (_, _) => const PantallaBilletera()),
      GoRoute(path: '/recargar', builder: (_, _) => const PantallaRecargar()),
      GoRoute(path: '/verificacion', builder: (_, _) => const PantallaVerificacion()),
      GoRoute(path: '/premium', builder: (_, _) => const PantallaPremium()),
      GoRoute(path: '/privacidad', builder: (_, _) => const PantallaPrivacidad()),
      GoRoute(
        path: '/reclamo',
        builder: (_, e) => PantallaReclamo(servicioId: e.uri.queryParameters['servicio']),
      ),
      GoRoute(path: '/eliminar-cuenta', builder: (_, _) => const PantallaEliminarCuenta()),
    ],
  );
});
