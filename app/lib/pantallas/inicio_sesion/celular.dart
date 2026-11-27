import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../componentes/base.dart';
import '../../componentes/estructura.dart';
import '../../tema/colores.dart';
import '../../tema/iconos.dart';
import '../../tema/tipografia.dart';
import '../../util/formato.dart';
import '../../util/ui.dart';
import 'estado_login.dart';

final _celularPeruano = RegExp(r'^9\d{8}$');

/// Paso previo a la pantalla 13: ingresar el celular (mismo estilo que 13).
class PantallaCelular extends ConsumerStatefulWidget {
  const PantallaCelular({super.key, this.esLogin = false});

  final bool esLogin;

  @override
  ConsumerState<PantallaCelular> createState() => _PantallaCelularState();
}

class _PantallaCelularState extends ConsumerState<PantallaCelular> {
  final _c = TextEditingController();
  String? _error;

  Future<void> _enviar() async {
    final n = _c.text.replaceAll(' ', '');
    if (!_celularPeruano.hasMatch(n)) {
      setState(() => _error = 'Usa un celular peruano de 9 dígitos que empiece con 9.');
      return;
    }
    setState(() => _error = null);
    try {
      await ref.read(loginProvider.notifier).enviarCodigo(n);
      if (mounted && ref.read(loginProvider).verificationId != null) context.push('/codigo');
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final enviando = ref.watch(loginProvider).enviando;
    return PantallaMican(
      titulo: widget.esLogin ? 'Iniciar sesión' : 'Crear cuenta',
      espacio: 18,
      barraAccion: BarraAccion(
        children: [
          Expanded(
            child: Boton('Enviar código', cargando: enviando, alPresionar: _enviar),
          ),
        ],
      ),
      children: [
        Text('¿Cuál es tu celular?', style: MicanTexto.titulo1),
        Text(
          'Te enviaremos un código por SMS para verificar que es tuyo.',
          style: MicanTexto.cuerpo.copyWith(color: MicanColores.textoSecundario),
        ),
        CampoTexto(
          etiqueta: 'Celular',
          controlador: _c,
          prefijo: '+51  ',
          pista: '987 654 321',
          teclado: TextInputType.phone,
          maxCaracteres: 9,
          alCambiar: (_) => setState(() => _error = null),
        ),
        if (_error != null) Aviso(texto: _error!, fondo: MicanColores.errorSuave, color: MicanColores.error),
        const NotaConIcono(
          icono: MicanIcono.candado,
          texto: 'Tu número no se muestra a otros usuarios hasta que acepten un servicio contigo.',
        ),
      ],
    );
  }
}

/// Pantalla 13 · Registro con celular (código SMS de 6 dígitos).
class PantallaCodigo extends ConsumerStatefulWidget {
  const PantallaCodigo({super.key});

  @override
  ConsumerState<PantallaCodigo> createState() => _PantallaCodigoState();
}

class _PantallaCodigoState extends ConsumerState<PantallaCodigo> {
  static const _vigencia = Duration(minutes: 5);
  static const _esperaReenvio = Duration(seconds: 60);

  final _c = TextEditingController();
  final _foco = FocusNode();
  late final Timer _reloj;
  bool _verificando = false;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _foco.requestFocus());
  }

  @override
  void dispose() {
    _reloj.cancel();
    _c.dispose();
    _foco.dispose();
    super.dispose();
  }

  Future<void> _verificar() async {
    if (_c.text.length != 6) return;
    setState(() => _verificando = true);
    final ok = await ref.read(loginProvider.notifier).verificar(_c.text);
    if (!mounted) return;
    setState(() => _verificando = false);
    if (!ok) _c.clear();
    // Si funcionó, el router redirige solo (registro o inicio).
  }

  Future<void> _reenviar() async {
    _c.clear();
    await intentar(context, () => ref.read(loginProvider.notifier).enviarCodigo(ref.read(loginProvider).telefono));
  }

  @override
  Widget build(BuildContext context) {
    final e = ref.watch(loginProvider);
    final transcurrido = e.enviadoEn == null ? Duration.zero : DateTime.now().difference(e.enviadoEn!);
    final vence = _vigencia - transcurrido;
    final reenviarEn = _esperaReenvio - transcurrido;
    final bloqueado = e.intentosFallidos >= 3;

    return PantallaMican(
      titulo: 'Crear cuenta',
      espacio: 18,
      barraAccion: BarraAccion(
        children: [
          Expanded(
            child: Boton(
              'Verificar',
              cargando: _verificando,
              alPresionar: _c.text.length == 6 && !bloqueado ? _verificar : null,
            ),
          ),
        ],
      ),
      children: [
        Text('Ingresa el código que enviamos', style: MicanTexto.titulo1),
        Text(
          vence.isNegative
              ? 'El código venció. Pide uno nuevo.'
              : 'Lo enviamos por SMS al ${telefonoLegible(e.e164)}. Vence en ${mmss(vence.inSeconds)}.',
          style: MicanTexto.cuerpo.copyWith(color: MicanColores.textoSecundario),
        ),
        GestureDetector(
          onTap: () => _foco.requestFocus(),
          child: Stack(
            children: [
              Opacity(
                opacity: 0,
                child: SizedBox(
                  height: 60,
                  child: TextField(
                    controller: _c,
                    focusNode: _foco,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                    onChanged: (v) {
                      setState(() {});
                      if (v.length == 6) _verificar();
                    },
                  ),
                ),
              ),
              IgnorePointer(
                child: _Digitos(codigo: _c.text, enfocado: _foco.hasFocus),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Text('¿No llegó? ', style: MicanTexto.etiqueta.copyWith(color: MicanColores.textoSecundario)),
            GestureDetector(
              onTap: reenviarEn.isNegative ? _reenviar : null,
              child: Text(
                reenviarEn.isNegative ? 'Reenviar código' : 'Reenviar en ${mmss(reenviarEn.inSeconds)}',
                style: MicanTexto.etiqueta.copyWith(color: MicanColores.primario),
              ),
            ),
          ],
        ),
        if (e.error != null) Aviso(texto: e.error!, fondo: MicanColores.errorSuave, color: MicanColores.error),
        const NotaConIcono(
          icono: MicanIcono.candado,
          texto: 'Al continuar aceptas los Términos y la Política de privacidad.',
        ),
      ],
    );
  }
}

class _Digitos extends StatelessWidget {
  const _Digitos({required this.codigo, required this.enfocado});

  final String codigo;
  final bool enfocado;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 6; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: MicanColores.superficieTarjeta,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: enfocado && i == codigo.length ? MicanColores.primario : MicanColores.bordeSuave,
                  width: enfocado && i == codigo.length ? 2 : 1,
                ),
              ),
              child: Text(i < codigo.length ? codigo[i] : '', style: MicanTexto.titulo1),
            ),
          ),
        ],
      ],
    );
  }
}
