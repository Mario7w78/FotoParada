import 'package:flutter/material.dart';

/// Abre la imagen de [url] a pantalla completa, sin recortes.
Future<void> verFotoCompleta(
  BuildContext context, {
  required String url,
  String titulo = '',
}) {
  return Navigator.push(
    context,
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => FotoCompletaView(url: url, titulo: titulo),
    ),
  );
}

/// La foto entera sobre fondo negro. Se puede ampliar con dos dedos.
class FotoCompletaView extends StatelessWidget {
  const FotoCompletaView({super.key, required this.url, this.titulo = ''});

  final String url;
  final String titulo;

  Widget _construirError() {
    return const Center(
      child: Icon(Icons.broken_image, color: Colors.grey, size: 64),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: const CloseButton(),
        title: Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: url.isEmpty
            ? _construirError()
            : InteractiveViewer(
                maxScale: 4,
                child: SizedBox.expand(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progreso) {
                      if (progreso == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) =>
                        _construirError(),
                  ),
                ),
              ),
      ),
    );
  }
}
