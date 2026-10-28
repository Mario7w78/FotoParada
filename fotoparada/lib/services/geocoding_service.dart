import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/geocoding_result.dart';

class GeocodingService {
  // Se pasa al ejecutar: flutter run --dart-define=GEOCODE_API_KEY=tu_key
  static const String _apiKey = String.fromEnvironment('GEOCODE_API_KEY');

  Future<List<GeocodingResult>> search(String query) async {
    if (query.trim().isEmpty) return [];
    if (_apiKey.isEmpty) {
      throw Exception(
        'Falta GEOCODE_API_KEY. Ejecuta con --dart-define=GEOCODE_API_KEY=...',
      );
    }

    final uri = Uri.https('geocode.maps.co', '/search', {
      'q': query.trim(),
      'api_key': _apiKey,
    });

    final response = await http.get(
      uri,
      headers: {
        'User-Agent': 'FotoParada/1.0 ',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((item) => GeocodingResult.fromJson(item as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 429) {
      throw Exception('Demasiadas peticiones. Espera un momento.');
    } else if (response.statusCode == 403) {
      throw Exception('API key inválida o bloqueada.');
    } else {
      throw Exception('Error en la geocodificación (${response.statusCode})');
    }
  }
}
