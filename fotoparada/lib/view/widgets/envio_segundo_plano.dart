import 'package:flutter/material.dart';

/// Cierra la pantalla sin esperar al servidor y deja [envio] en segundo plano.
///
/// [envio] devuelve false si falló; entonces se avisa con [error] y la opción de
/// reintentar, que conserva lo que el usuario había escrito.
void cerrarYEnviar(
  BuildContext context, {
  required Future<bool> Function() envio,
  required String? Function() error,
  required String mensaje,
  String? mensajeFinal,
}) {
  final mensajes = ScaffoldMessenger.of(context);

  void avisar(String texto, {SnackBarAction? accion}) {
    mensajes
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto), action: accion));
  }

  Future<void> intentar() async {
    // La llamada empieza antes de cualquier espera.
    final pendiente = envio();
    avisar(mensaje);
    if (await pendiente) {
      if (mensajeFinal != null) avisar(mensajeFinal);
      return;
    }
    avisar(
      error() ?? 'No se pudo completar la acción.',
      accion: SnackBarAction(label: 'Reintentar', onPressed: intentar),
    );
  }

  intentar();
  Navigator.pop(context);
}
