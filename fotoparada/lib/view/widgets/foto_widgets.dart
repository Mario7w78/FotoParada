import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/foto_model.dart';

IconData iconoPrivacidad(PrivacidadFoto privacidad) {
  switch (privacidad) {
    case PrivacidadFoto.publica:
      return Icons.public;
    case PrivacidadFoto.amigos:
      return Icons.group;
    case PrivacidadFoto.privada:
      return Icons.lock;
  }
}

String etiquetaPrivacidad(PrivacidadFoto privacidad) {
  switch (privacidad) {
    case PrivacidadFoto.publica:
      return 'Pública';
    case PrivacidadFoto.amigos:
      return 'Amigos';
    case PrivacidadFoto.privada:
      return 'Privada';
  }
}

/// Muestra la imagen de [url] o, si no hay URL (documentos antiguos), la
/// guardada en [base64]. Ante cualquier fallo muestra un ícono de error.
class ImagenFoto extends StatefulWidget {
  const ImagenFoto({super.key, this.url = '', this.base64 = ''});

  final String url;
  final String base64;

  @override
  State<ImagenFoto> createState() => _ImagenFotoState();
}

class _ImagenFotoState extends State<ImagenFoto> {
  // Se conserva entre redibujados: decodificar en cada build sería costoso y
  // haría parpadear la imagen, porque cada lista de bytes parece una nueva.
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _decodificar(widget.base64);
  }

  @override
  void didUpdateWidget(ImagenFoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.base64 != oldWidget.base64) {
      _bytes = _decodificar(widget.base64);
    }
  }

  Uint8List? _decodificar(String texto) {
    if (texto.isEmpty) return null;
    try {
      return base64Decode(texto);
    } on FormatException {
      return null;
    }
  }

  Widget _construirError() {
    return const ColoredBox(
      color: Colors.white,
      child: Center(child: Icon(Icons.broken_image, color: Colors.grey)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.isNotEmpty) {
      return Image.network(
        widget.url,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progreso) {
          if (progreso == null) return child;
          return const ColoredBox(
            color: Colors.white,
            child: Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (context, error, stackTrace) => _construirError(),
      );
    }

    final bytes = _bytes;
    if (bytes == null) return _construirError();

    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => _construirError(),
    );
  }
}

Future<bool> confirmarEliminarFoto(BuildContext context) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Eliminar esta foto?'),
      content: const Text('Esta acción no se puede deshacer.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return confirmado ?? false;
}

/// Pide un día y devuelve [actual] con ese día, conservando la hora. Devuelve
/// null si el usuario cancela.
Future<DateTime?> elegirFechaToma(
  BuildContext context,
  DateTime actual,
) async {
  final ahora = DateTime.now();
  final dia = await showDatePicker(
    context: context,
    initialDate: actual.isAfter(ahora) ? ahora : actual,
    firstDate: DateTime(1900),
    lastDate: ahora,
    helpText: 'Fecha de la foto',
    cancelText: 'Cancelar',
    confirmText: 'Aceptar',
  );
  if (dia == null) return null;

  final fecha = DateTime(
    dia.year,
    dia.month,
    dia.day,
    actual.hour,
    actual.minute,
    actual.second,
  );
  // Elegir hoy con una hora que aún no llega dejaría la foto en el futuro.
  return fecha.isAfter(ahora) ? ahora : fecha;
}
