import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../componentes/base.dart';
import '../../componentes/estructura.dart';
import '../../componentes/tarjetas.dart';
import '../../datos/modelos.dart';
import '../../datos/proveedores.dart';
import '../../tema/colores.dart';
import '../../tema/iconos.dart';
import '../../tema/tipografia.dart';
import '../../util/formato.dart';

/// Pantalla 12 · Mensajes. Hay un chat por servicio; se abre al confirmar y
/// se cierra 24 h después de terminar.
class PantallaMensajes extends ConsumerWidget {
  const PantallaMensajes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(chatsProvider);
    final lista = chats.value ?? const <Chat>[];
    final abiertos = lista.where((c) => c.puedeEscribir).toList();
    final cerrados = lista.where((c) => !c.puedeEscribir).toList();
    return PantallaMican(
      titulo: 'Mensajes',
      mostrarAtras: false,
      children: [
        if (chats.isLoading && lista.isEmpty)
          const Cargando()
        else if (lista.isEmpty)
          const Vacio(
            icono: MicanIcono.mensajes,
            titulo: 'Aún no tienes mensajes',
            texto: 'Cuando se confirme un servicio podrás escribirte con la otra persona aquí.',
          )
        else ...[
          if (abiertos.isNotEmpty) ListaTarjeta(children: [for (final c in abiertos) _FilaChat(chat: c)]),
          if (cerrados.isNotEmpty) ...[
            const TituloSeccion('Anteriores'),
            ListaTarjeta(children: [for (final c in cerrados) _FilaChat(chat: c)]),
          ],
          const NotaConIcono(
            icono: MicanIcono.candado,
            texto: 'Por tu seguridad, no compartas datos de pago fuera de Yape, Plin o efectivo al terminar.',
          ),
        ],
      ],
    );
  }
}

class _FilaChat extends ConsumerWidget {
  const _FilaChat({required this.chat});

  final Chat chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(uidProvider);
    final s = ref.watch(servicioProvider(chat.id)).value;
    final soyDueno = s?.duenoId == uid;
    final nombre = s == null ? 'Servicio' : (soyDueno ? (s.cuidadorNombre ?? 'Cuidador') : s.duenoNombre);
    final noLeidos = chat.noLeidos[uid] ?? 0;
    return FilaLista(
      inicio: Avatar(nombre: nombre, tamano: 48),
      titulo: s == null ? nombre : '$nombre · ${s.mascota.nombre}',
      subtitulo: chat.ultimoMensaje ?? (s == null ? '' : '${s.tipo.nombre} · ${fechaRelativa(s.creadoEn)}'),
      colorSubtitulo: noLeidos > 0 ? MicanColores.textoPrincipal : MicanColores.textoSecundario,
      alPresionar: () => context.push('/chat/${chat.id}'),
      final_: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(horaChat(chat.actualizadoEn), style: MicanTexto.leyenda),
          if (noLeidos > 0) ...[
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(minWidth: 20),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: MicanColores.acento, borderRadius: BorderRadius.circular(10)),
              child: Text(
                '$noLeidos',
                textAlign: TextAlign.center,
                style: MicanTexto.nav.copyWith(color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
