import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/foto_model.dart';

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _baseUrl = 'https://picsum.photos/v2/list?page=1&limit=10';

  Future<List<Foto>> obtenerFotos() async {
    final response = await _client.get(Uri.parse(_baseUrl));

    if (response.statusCode != 200) {
      throw Exception('Error en el servidor: Código ${response.statusCode}');
    }

    final List<dynamic> jsonList = json.decode(response.body);

    return jsonList.map((json) {
      return Foto(
        id: int.tryParse(json['id'].toString()) ?? 0,
        urlImagen: json['download_url'] ?? '',
        titulo: 'Foto por ${json['author']}',
        latitud: 0.0,
        longitud: 0.0,
      );
    }).toList();
  }
}
