// Prueba real contra ImgBB: sube una imagen con la clave de claves.json.
//   flutter test integration_test -d <emulador> --dart-define-from-file=claves.json
// ImgBB no permite borrar por API: cada ejecución deja una imagen en la cuenta
// (se puede borrar a mano desde la URL de eliminación que se imprime).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fotoparada/services/imagen_compresor.dart';
import 'package:fotoparada/services/imgbb_service.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';

const String _clave = String.fromEnvironment('IMGBB_API_KEY');

/// JPG de 2400x1600 con coordenadas GPS falsas en el EXIF.
Uint8List _jpgConGps() {
  final imagen = img.Image(width: 2400, height: 1600);
  for (final pixel in imagen) {
    pixel
      ..r = pixel.x * 255 ~/ 2400
      ..g = pixel.y * 255 ~/ 1600
      ..b = 120;
  }
  imagen.exif.gpsIfd
    ..gpsLatitude = -12.0464
    ..gpsLongitude = -77.0428;
  return img.encodeJpg(imagen, quality: 95);
}

Future<http.Response> _descargar(String url) =>
    http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'comprime, sube a ImgBB y la imagen publicada no trae GPS',
    (tester) async {
      final original = _jpgConGps();
      // Comprueba que la imagen de partida sí lleva GPS.
      expect(
        img.decodeJpg(original)!.exif.gpsIfd.isEmpty,
        isFalse,
      );

      // runAsync: el binding de pruebas no deja salir a la red con tiempo
      // simulado.
      final resultado = await tester.runAsync(() async {
        final comprimida = await ImagenCompresor().comprimir(original);
        expect(img.decodeJpg(comprimida)!.exif.gpsIfd.isEmpty, isTrue);

        final subida = await ImgbbService().subirImagen(comprimida);
        final imagen = await _descargar(subida.url);
        final miniatura = await _descargar(subida.urlMiniatura);
        return (subida: subida, imagen: imagen, miniatura: miniatura);
      });

      final subida = resultado!.subida;
      // ignore: avoid_print
      print('Subida a ImgBB: ${subida.url}\n'
          'Borrar a mano: ${subida.urlEliminar}');

      expect(subida.url, startsWith('https://'));
      expect(subida.urlEliminar, isNotEmpty);

      for (final respuesta in [resultado.imagen, resultado.miniatura]) {
        expect(respuesta.statusCode, 200, reason: '${respuesta.request?.url}');
        expect(respuesta.headers['content-type'], startsWith('image/'));
      }

      final descargada = img.decodeImage(resultado.imagen.bodyBytes);
      expect(descargada, isNotNull);
      expect(descargada!.width, 1920);
      expect(descargada.exif.gpsIfd.isEmpty, isTrue);
    },
    skip: _clave.isEmpty,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
