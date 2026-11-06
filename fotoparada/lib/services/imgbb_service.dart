import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'photo_service.dart';

const String mensajeFaltaClaveImgbb = 'Falta IMGBB_API_KEY. Revisa claves.json';

/// URLs que devuelve ImgBB tras subir una imagen.
class ImagenSubida {
  const ImagenSubida({
    required this.url,
    required this.urlMiniatura,
    required this.urlEliminar,
  });

  final String url;
  final String urlMiniatura;

  /// Página web para borrar la imagen a mano: la API no permite borrarla.
  final String urlEliminar;
}

class ImgbbService {
  // Se pasa al ejecutar: flutter run --dart-define-from-file=claves.json
  static const String _apiKeyEntorno = String.fromEnvironment('IMGBB_API_KEY');

  ImgbbService({
    http.Client? client,
    String? apiKey,
    this.timeout = const Duration(seconds: 60),
  })  : _client = client ?? http.Client(),
        _apiKey = apiKey ?? _apiKeyEntorno;

  final http.Client _client;
  final String _apiKey;
  final Duration timeout;

  bool get tieneClave => _apiKey.isNotEmpty;

  /// Sube [bytes] sin fecha de caducidad y devuelve sus URLs.
  Future<ImagenSubida> subirImagen(Uint8List bytes) async {
    if (!tieneClave) {
      throw const PhotoException(mensajeFaltaClaveImgbb);
    }

    final peticion = http.MultipartRequest(
      'POST',
      Uri.https('api.imgbb.com', '/1/upload', {'key': _apiKey}),
    )..files.add(
        http.MultipartFile.fromBytes('image', bytes, filename: 'foto.jpg'),
      );

    final http.Response respuesta;
    try {
      respuesta = await _client
          .send(peticion)
          .then(http.Response.fromStream)
          .timeout(timeout);
    } on SocketException {
      throw const PhotoException('Sin conexión. Intenta de nuevo.');
    } on TimeoutException {
      throw const PhotoException('Sin conexión. Intenta de nuevo.');
    } on http.ClientException {
      // Así llegan los fallos de red en algunas plataformas. No se muestra su
      // mensaje porque incluye la URL con la clave.
      throw const PhotoException('Sin conexión. Intenta de nuevo.');
    }

    final datos = _leerJson(respuesta.body);
    if (respuesta.statusCode != 200 || datos?['success'] != true) {
      throw PhotoException(
        'No se pudo subir la imagen: ${_mensajeError(datos, respuesta)}',
      );
    }

    final data = datos!['data'];
    final url = data is Map ? data['url'] : null;
    if (url is! String || url.isEmpty) {
      throw const PhotoException(
        'No se pudo subir la imagen: respuesta inválida del servidor.',
      );
    }

    final thumb = data['thumb'];
    final miniatura = thumb is Map ? thumb['url'] : null;
    final eliminar = data['delete_url'];
    return ImagenSubida(
      url: url,
      urlMiniatura: miniatura is String && miniatura.isNotEmpty ? miniatura : url,
      urlEliminar: eliminar is String ? eliminar : '',
    );
  }

  Map<String, dynamic>? _leerJson(String cuerpo) {
    try {
      final json = jsonDecode(cuerpo);
      return json is Map<String, dynamic> ? json : null;
    } on FormatException {
      return null;
    }
  }

  String _mensajeError(Map<String, dynamic>? datos, http.Response respuesta) {
    final error = datos?['error'];
    final mensaje = error is Map ? error['message'] : null;
    if (mensaje is String && mensaje.isNotEmpty) return mensaje;
    return 'error ${respuesta.statusCode}';
  }
}
