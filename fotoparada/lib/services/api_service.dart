import 'dart:convert'; // Para usar json.decode
import 'package:http/http.dart' as http; // Paquete HTTP nativo
import '../models/foto_model.dart'; // Importamos el modelo

class ApiService {
  // Utilizamos una API pública real para que puedas ver resultados inmediatos
  final String _baseUrl = 'https://picsum.photos/v2/list?page=1&limit=10';

  // Función asíncrona para obtener la lista de fotos
  Future<List<Foto>> obtenerFotos() async {
    try {
      // Realizamos la petición HTTP GET
      final response = await http.get(Uri.parse(_baseUrl));

      // Comprobamos si la respuesta del servidor es exitosa (código 200)
      if (response.statusCode == 200) {
        // Decodificamos el JSON del cuerpo de la respuesta (esperando una lista)
        List<dynamic> jsonList = json.decode(response.body);
        
        // Convertimos la lista JSON a una lista de objetos Foto
        return jsonList.map((json) {
          return Foto(
            // Transformamos el ID de string a int (Picsum devuelve string)
            id: int.tryParse(json['id']) ?? 0,
            urlImagen: json['download_url'] ?? '',
            titulo: 'Foto por ${json['author']}', // Picsum usa "author"
            latitud: 0.0, // Valores de ejemplo para simular ubicación
            longitud: 0.0,
          );
        }).toList();
      } else {
        // Lanzamos una excepción si el estado no es 200
        throw Exception('Error en el servidor: Código ${response.statusCode}');
      }
    } catch (e) {
      // Capturamos y lanzamos cualquier error de red o de parseo
      throw Exception('Fallo la conexión con el servidor: $e');
    }
  }
}
