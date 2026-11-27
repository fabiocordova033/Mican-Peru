import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../componentes/base.dart';
import '../../componentes/estructura.dart';
import '../../datos/modelos.dart';
import '../../datos/proveedores.dart';
import '../../tema/colores.dart';
import '../../tema/iconos.dart';
import '../../tema/tipografia.dart';
import '../../util/formato.dart';
import '../../util/ui.dart';
import '../servicio/fotos.dart';

/// Conversación de un servicio (`chats/{servicioId}`). Las fotos que sube el
/// cuidador llegan aquí como mensajes de tipo "foto".
class PantallaChat extends ConsumerStatefulWidget {
  const PantallaChat({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<PantallaChat> createState() => _PantallaChatState();
}

class _PantallaChatState extends ConsumerState<PantallaChat> {
  final _texto = TextEditingController();
  int _vistos = -1;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  /// Las reglas solo permiten poner en 0 el contador propio.
  void _marcarLeido() {
    final uid = ref.read(uidProvider);
    if (uid == null) return;
    ref.read(firestoreProvider).doc('chats/${widget.chatId}').update({'noLeidos.$uid': 0}).catchError((_) {});
  }

  Future<void> _enviar() async {
    final texto = _texto.text.trim();
    final uid = ref.read(uidProvider);
    if (texto.isEmpty || uid == null) return;
    _texto.clear();
    try {
      await ref.read(firestoreProvider).collection('chats/${widget.chatId}/mensajes').add({
        'autorId': uid,
        'tipo': 'texto',
        'texto': texto,
        'creadoEn': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        _texto.text = texto;
        mostrarError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(uidProvider);
    final s = ref.watch(servicioProvider(widget.chatId)).value;
    final chats = ref.watch(chatsProvider).value ?? const <Chat>[];
    final chat = chats.where((c) => c.id == widget.chatId).firstOrNull;
    final mensajes = ref.watch(mensajesProvider(widget.chatId)).value;
    final soyDueno = s?.duenoId == uid;
    final otro = s == null ? 'Chat' : (soyDueno ? (s.cuidadorNombre ?? 'Cuidador') : s.duenoNombre);
    final puedeEscribir = chat?.puedeEscribir ?? true;

    final pendientes = chat?.noLeidos[uid] ?? 0;
    if (pendientes > 0 && mensajes != null && mensajes.length != _vistos) {
      _vistos = mensajes.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _marcarLeido());
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  BotonCircular(
                    icono: MicanIcono.atras,
                    alPresionar: () => context.canPop() ? context.pop() : context.go('/app'),
                  ),
                  const SizedBox(width: 10),
                  Avatar(nombre: otro, tamano: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(otro, style: MicanTexto.cuerpoFuerte, overflow: TextOverflow.ellipsis),
                        if (s != null) Text('${s.tipo.nombre} · ${s.mascota.nombre}', style: MicanTexto.leyenda),
                      ],
                    ),
                  ),
                  if (s != null)
                    BotonCircular(icono: MicanIcono.chevron, alPresionar: () => context.push('/servicio/${s.id}')),
                ],
              ),
            ),
            Expanded(
              child: mensajes == null
                  ? const Cargando()
                  : mensajes.isEmpty
                  ? const Vacio(
                      icono: MicanIcono.mensajes,
                      titulo: 'Escribe el primer mensaje',
                      texto: 'Coordina el recojo o deja indicaciones.',
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      itemCount: mensajes.length,
                      itemBuilder: (_, i) =>
                          _Burbuja(mensaje: mensajes[i], mio: mensajes[i].autorId == uid, servicioId: widget.chatId),
                    ),
            ),
            if (puedeEscribir)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                color: MicanColores.fondoApp,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _texto,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 1000,
                        textCapitalization: TextCapitalization.sentences,
                        style: MicanTexto.cuerpo,
                        onSubmitted: (_) => _enviar(),
                        decoration: InputDecoration(
                          hintText: 'Escribe un mensaje',
                          counterText: '',
                          filled: true,
                          fillColor: MicanColores.superficieTarjeta,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    BotonCircular(
                      icono: MicanIcono.enviar,
                      fondo: MicanColores.primario,
                      colorIcono: Colors.white,
                      tamano: 44,
                      alPresionar: _enviar,
                    ),
                  ],
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(16),
                child: Aviso(icono: MicanIcono.candado, texto: 'Este chat se cerró 24 horas después del servicio.'),
              ),
          ],
        ),
      ),
    );
  }
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({required this.mensaje, required this.mio, required this.servicioId});

  final Mensaje mensaje;
  final bool mio;
  final String servicioId;

  @override
  Widget build(BuildContext context) {
    final m = mensaje;
    final sistema = m.tipo == 'sistema';
    if (sistema) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Text(m.texto, style: MicanTexto.leyenda, textAlign: TextAlign.center),
        ),
      );
    }
    return Align(
      alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
        padding: m.tipo == 'foto' ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mio ? MicanColores.primario : MicanColores.superficieTarjeta,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mio ? 18 : 4),
            bottomRight: Radius.circular(mio ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: mio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (m.tipo == 'foto' && m.ruta != null)
              GestureDetector(
                onTap: () => verFotos(context, servicioId),
                child: MiniaturaFoto(ruta: m.ruta!, tamano: 200, alto: 200),
              )
            else
              Text(m.texto, style: MicanTexto.cuerpo.copyWith(color: mio ? Colors.white : MicanColores.textoPrincipal)),
            Padding(
              padding: m.tipo == 'foto' ? const EdgeInsets.fromLTRB(6, 4, 6, 2) : const EdgeInsets.only(top: 2),
              child: Text(
                hora(m.creadoEn),
                style: MicanTexto.leyenda.copyWith(
                  fontSize: 11,
                  color: mio ? MicanColores.primarioSuave : MicanColores.textoSecundario,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
