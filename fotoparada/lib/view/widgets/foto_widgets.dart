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

/// Imagen de una foto guardada, con indicador de carga y manejo de error.
class ImagenFotoRed extends StatelessWidget {
  const ImagenFotoRed({super.key, required this.url, this.anchoEnCache});

  final String url;

  /// Ancho al que se decodifica: evita cargar en memoria la imagen completa
  /// cuando solo se muestra una miniatura.
  final int? anchoEnCache;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: anchoEnCache,
      loadingBuilder: (context, child, progreso) {
        if (progreso == null) return child;
        return const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => const ColoredBox(
        color: Colors.white,
        child: Center(child: Icon(Icons.broken_image, color: Colors.grey)),
      ),
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
