import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../componentes/base.dart';
import '../../componentes/estructura.dart';
import '../../componentes/tarjetas.dart';
import '../../config/entorno.dart';
import '../../datos/modelos.dart';
import '../../datos/proveedores.dart';
import '../../tema/colores.dart';
import '../../tema/iconos.dart';
import '../../tema/tipografia.dart';
import '../../util/formato.dart';
import '../../util/ui.dart';
import '../legal/documentos_legales.dart';
import '../shell.dart';

/// Pestaña "Cuenta": perfil, modo dueño/cuidador, Premium, privacidad y salida.
class PantallaCuenta extends ConsumerWidget {
  const PantallaCuenta({super.key});

  Future<void> _cambiarModo(BuildContext context, WidgetRef ref, Usuario u) async {
    final api = ref.read(apiProvider);
    if (u.rolActivo == Rol.cuidador) {
      await intentar(context, () => api.cambiarRolActivo(Rol.dueno));
    } else if (u.esCuidador) {
      await intentar(context, () => api.cambiarRolActivo(Rol.cuidador));
    } else {
      final ok = await confirmar(
        context,
        titulo: 'Hazte cuidador',
        texto:
            'Para verificarte necesitamos tu DNI, una selfie y tu certificado de antecedentes. Son datos sensibles: '
            'solo los ve el equipo de verificación y el certificado se borra al aprobarte (Ley 29733). ¿Autorizas su uso?',
        si: 'Sí, autorizo',
        no: 'Ahora no',
      );
      if (!ok || !context.mounted) return;
      final hecho = await intentar(context, api.activarRolCuidador);
      if (hecho && context.mounted) context.push('/verificacion');
    }
    ref.read(pestanaProvider.notifier).ir(0);
  }

  Future<void> _salir(BuildContext context, WidgetRef ref) async {
    final ok = await confirmar(
      context,
      titulo: '¿Cerrar sesión?',
      texto: 'Podrás volver a entrar con tu celular.',
      si: 'Cerrar sesión',
    );
    if (ok) {
      ref.read(pestanaProvider.notifier).ir(0);
      await ref.read(authProvider).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(usuarioProvider).value;
    final perfil = ref.watch(miPerfilProvider).value;
    if (u == null) return const Scaffold(body: Cargando());
    final cuidador = u.rolActivo == Rol.cuidador;

    return PantallaMican(
      titulo: 'Cuenta',
      mostrarAtras: false,
      children: [
        Tarjeta(
          alPresionar: () => mostrarHoja(
            context,
            builder: (_) => _EditarPerfil(usuario: u, perfil: perfil),
          ),
          child: Row(
            children: [
              Avatar(nombre: u.nombre, fotoUrl: perfil?.fotoUrl, tamano: 60),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.nombre, style: MicanTexto.titulo2),
                    Text(u.telefono.isEmpty ? '' : telefonoLegible(u.telefono), style: MicanTexto.leyenda),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Pildora(
                          texto: cuidador ? 'Modo cuidador' : 'Modo dueño',
                          fondo: MicanColores.primarioSuave,
                          color: MicanColores.primario,
                          compacta: true,
                        ),
                        if (u.esPremium)
                          const Pildora(
                            texto: 'Premium',
                            icono: MicanIcono.corona,
                            fondo: MicanColores.acentoSuave,
                            color: MicanColores.acento,
                            compacta: true,
                          ),
                        if (cuidador && perfil != null) InsigniaNivel(perfil.nivel),
                      ],
                    ),
                  ],
                ),
              ),
              const Icono(MicanIcono.chevron, tamano: 20),
            ],
          ),
        ),
        if (u.estadoCuenta == 'eliminacion_pendiente')
          Tarjeta(
            color: MicanColores.errorSuave,
            sombra: false,
            alPresionar: () => context.push('/recuperar-cuenta'),
            child: Text(
              'Tu cuenta se eliminará el ${u.eliminarEn == null ? 'pronto' : fechaRelativa(u.eliminarEn, conHora: false)}. Toca para recuperarla.',
              style: MicanTexto.cuerpoFuerte.copyWith(color: MicanColores.error),
            ),
          ),
        ListaTarjeta(
          children: [
            if (cuidador) ...[
              FilaLista(
                icono: MicanIcono.billetera,
                titulo: 'Billetera',
                subtitulo: 'Saldo y recargas',
                alPresionar: () => context.push('/billetera'),
                final_: _chevron,
              ),
              FilaLista(
                icono: MicanIcono.escudo,
                titulo: 'Verificación',
                subtitulo: 'DNI, antecedentes y selfie',
                alPresionar: () => context.push('/verificacion'),
                final_: _chevron,
              ),
              FilaLista(
                icono: MicanIcono.estrella,
                titulo: 'Mi nivel',
                subtitulo: 'Cómo subir de nivel',
                alPresionar: () => mostrarHoja(context, builder: (_) => const _HojaNivel()),
                final_: _chevron,
              ),
            ] else ...[
              FilaLista(
                icono: MicanIcono.huella,
                titulo: 'Mis mascotas',
                alPresionar: () => context.push('/mascotas'),
                final_: _chevron,
              ),
              FilaLista(
                icono: MicanIcono.corona,
                fondoIcono: MicanColores.acentoSuave,
                colorIcono: MicanColores.acento,
                titulo: 'Mican Premium',
                subtitulo: u.esPremium
                    ? (u.enPrueba ? 'En prueba gratis' : 'Activo')
                    : '7 días gratis · S/ 7.50 al mes',
                alPresionar: () => context.push('/premium'),
                final_: _chevron,
              ),
            ],
            FilaLista(
              icono: cuidador ? MicanIcono.huella : MicanIcono.verificado,
              titulo: cuidador
                  ? 'Cambiar a modo dueño'
                  : (u.esCuidador ? 'Cambiar a modo cuidador' : 'Quiero ser cuidador'),
              subtitulo: cuidador ? 'Pide servicios para tus mascotas' : 'Gana dinero cuidando mascotas',
              alPresionar: () => _cambiarModo(context, ref, u),
              final_: _chevron,
            ),
          ],
        ),
        ListaTarjeta(
          children: [
            FilaLista(
              icono: MicanIcono.candado,
              titulo: 'Privacidad y mis datos',
              alPresionar: () => context.push('/privacidad'),
              final_: _chevron,
            ),
            FilaLista(
              icono: MicanIcono.documento,
              titulo: 'Libro de reclamaciones',
              alPresionar: () => context.push('/reclamo'),
              final_: _chevron,
            ),
            FilaLista(
              icono: MicanIcono.documento,
              titulo: 'Términos y condiciones',
              alPresionar: () => verDocumentoLegal(context, DocumentoLegal.terminos),
              final_: _chevron,
            ),
            FilaLista(
              icono: MicanIcono.mensajes,
              titulo: 'Ayuda y soporte',
              alPresionar: () => launchUrl(Uri(scheme: 'tel', path: Entorno.telefonoSoporte)),
              final_: _chevron,
            ),
          ],
        ),
        Boton('Cerrar sesión', tipo: TipoBoton.contorno, alPresionar: () => _salir(context, ref)),
        Center(
          child: TextButton(
            onPressed: () => context.push('/eliminar-cuenta'),
            child: Text('Eliminar mi cuenta', style: MicanTexto.etiqueta.copyWith(color: MicanColores.error)),
          ),
        ),
      ],
    );
  }

  static const _chevron = Icono(MicanIcono.chevron, tamano: 20, color: MicanColores.textoSecundario);
}

class _EditarPerfil extends ConsumerStatefulWidget {
  const _EditarPerfil({required this.usuario, required this.perfil});

  final Usuario usuario;
  final Perfil? perfil;

  @override
  ConsumerState<_EditarPerfil> createState() => _EditarPerfilState();
}

class _EditarPerfilState extends ConsumerState<_EditarPerfil> {
  late final _nombre = TextEditingController(text: widget.usuario.nombre);
  late final _experiencia = TextEditingController(text: widget.perfil?.experiencia ?? '');
  late String? _foto = widget.perfil?.fotoUrl;
  bool _guardando = false;

  Future<void> _cambiarFoto() async {
    await intentar(context, () async {
      final url = await ref.read(archivosProvider).fotoUsuario(widget.usuario.uid, 'perfil');
      if (url != null && mounted) setState(() => _foto = url);
    });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final ok = await intentar(
      context,
      () => ref.read(apiProvider).actualizarPerfil({
        'nombre': _nombre.text.trim(),
        'fotoUrl': _foto,
        if (widget.usuario.esCuidador) 'experiencia': _experiencia.text.trim(),
      }),
    );
    if (!mounted) return;
    setState(() => _guardando = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Editar perfil', style: MicanTexto.titulo2),
        const SizedBox(height: 14),
        Center(
          child: GestureDetector(
            onTap: _cambiarFoto,
            child: Column(
              children: [
                Avatar(nombre: _nombre.text, fotoUrl: _foto, tamano: 80),
                const SizedBox(height: 6),
                Text('Cambiar foto', style: MicanTexto.etiqueta.copyWith(color: MicanColores.primario)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        CampoTexto(
          etiqueta: 'Nombre y apellido',
          controlador: _nombre,
          mayusculas: TextCapitalization.words,
          maxCaracteres: 80,
        ),
        if (widget.usuario.esCuidador) ...[
          const SizedBox(height: 12),
          CampoTexto(
            etiqueta: 'Tu experiencia con mascotas',
            controlador: _experiencia,
            lineas: 4,
            maxCaracteres: 1000,
            pista: 'Ej. Tengo 2 perros y paseo mascotas del barrio hace 3 años.',
          ),
        ],
        const SizedBox(height: 18),
        Boton('Guardar', cargando: _guardando, alPresionar: _guardar),
      ],
    );
  }
}

/// "Mi nivel" del cuidador (miProgresoNivel).
class _HojaNivel extends ConsumerWidget {
  const _HojaNivel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(miPerfilProvider).value;
    return FutureBuilder<Json>(
      future: ref.read(apiProvider).miProgresoNivel(),
      builder: (context, snap) {
        final p = snap.data;
        final siguiente = p?['siguiente'] as String?;
        final faltan = entero(p?['serviciosFaltantes']);
        final nota = p?['calificacionRequerida'];
        final dias = entero(p?['requiereSinIncidentesDias']);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mi nivel', style: MicanTexto.titulo2),
            const SizedBox(height: 12),
            Center(child: InsigniaNivel(p?['nivelActual'] as String? ?? perfil?.nivel ?? 'nuevo')),
            const SizedBox(height: 16),
            if (snap.connectionState != ConnectionState.done)
              const Cargando()
            else if (snap.hasError)
              Text(mensajeDeError(snap.error!), style: MicanTexto.cuerpo, textAlign: TextAlign.center)
            else if (siguiente == null)
              Text(
                '¡Llegaste al nivel más alto! Gracias por cuidar tan bien.',
                style: MicanTexto.cuerpo,
                textAlign: TextAlign.center,
              )
            else ...[
              Text('Para ser ${InsigniaNivel.nombre(siguiente)}:', style: MicanTexto.subtitulo),
              const SizedBox(height: 10),
              _Requisito(
                texto: faltan == 0 ? 'Servicios completados' : 'Completa $faltan servicios más',
                hecho: faltan == 0,
              ),
              if (nota is num)
                _Requisito(
                  texto: 'Mantén una calificación de $nota o más',
                  hecho: (perfil?.calificacionPromedio ?? 0) >= nota,
                ),
              if (dias > 0) _Requisito(texto: '$dias días sin incidentes', hecho: false),
            ],
          ],
        );
      },
    );
  }
}

class _Requisito extends StatelessWidget {
  const _Requisito({required this.texto, required this.hecho});

  final String texto;
  final bool hecho;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Casilla(marcada: hecho, redonda: true, colorMarcada: MicanColores.exito),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: MicanTexto.cuerpo)),
        ],
      ),
    );
  }
}
