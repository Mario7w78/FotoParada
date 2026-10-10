import 'package:flutter_test/flutter_test.dart';
import 'package:fotoparada/models/foto_model.dart';

void main() {
  group('Foto.fromJson', () {
    test('construye una Foto desde un mapa JSON', () {
      final foto = Foto.fromJson({
        'id': 1,
        'url_imagen': 'https://example.com/foto.jpg',
        'titulo': 'Foto de prueba',
        'latitud': 0,
        'longitud': 0,
      });

      expect(foto.id, 1);
      expect(foto.urlImagen, 'https://example.com/foto.jpg');
      expect(foto.titulo, 'Foto de prueba');
      expect(foto.latitud, 0.0);
      expect(foto.longitud, 0.0);
    });
  });
}
