import 'package:flutter/material.dart';

import '../../tema/tipografia.dart';
import '../../util/ui.dart';

enum DocumentoLegal { terminos, privacidad }

/// Resumen de los documentos legales. El texto definitivo lo redacta el
/// equipo legal; aquí va un borrador que respeta lo que la app ya hace.
Future<void> verDocumentoLegal(BuildContext context, DocumentoLegal doc) {
  final (titulo, parrafos) = switch (doc) {
    DocumentoLegal.terminos => (
      'Términos y condiciones',
      const [
        'Mican conecta a dueños de perros y gatos con cuidadores independientes verificados. Mican no presta el servicio de cuidado: lo hace el cuidador que aceptes.',
        'El dueño propone un precio o elige un paquete fijo. Los cuidadores cercanos pueden aceptar o contraofertar; cada oferta vence en 60 segundos.',
        'El pago del servicio se hace directamente al cuidador (Yape, Plin o efectivo) al terminar.',
        'Para recibir solicitudes, el cuidador mantiene saldo recargado. Por cada servicio completado Mican descuenta una comisión del 12 % de ese saldo.',
        'Debes tener 18 años o más. Puedes eliminar tu cuenta cuando quieras desde Privacidad y mis datos.',
        'Si algo sale mal, usa el botón de emergencia durante el servicio o el Libro de Reclamaciones.',
      ],
    ),
    DocumentoLegal.privacidad => (
      'Política de privacidad',
      const [
        'Responsable: Mican Perú S.A.C. Tratamos tus datos según la Ley 29733 de Protección de Datos Personales.',
        'Usamos tu celular para crear tu cuenta y tu ubicación solo para encontrar cuidadores cercanos y mostrar la ruta mientras hay un servicio en curso (también con la app en segundo plano, solo durante el servicio).',
        'Tu DNI y teléfono no se muestran a la otra parte hasta que acepten un servicio, y dejan de verse 24 horas después de terminar.',
        'Los documentos del cuidador (DNI, selfie, antecedentes) solo los ve el equipo de verificación. El certificado de antecedentes se borra al aprobarse.',
        'Las promociones de patrocinadores son opcionales y puedes retirarlas cuando quieras.',
        'Puedes ejercer tus derechos ARCO (acceso, rectificación, cancelación y oposición) desde la app.',
      ],
    ),
  };
  return mostrarHoja(
    context,
    builder: (c) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: MicanTexto.titulo1),
        const SizedBox(height: 12),
        for (final p in parrafos) ...[Text(p, style: MicanTexto.cuerpo), const SizedBox(height: 10)],
      ],
    ),
  );
}
