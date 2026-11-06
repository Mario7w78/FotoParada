import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fotoparada/services/imgbb_service.dart';
import 'package:fotoparada/services/photo_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final Uint8List bytesPrueba = Uint8List.fromList([0xFF, 0xD8, 0xFF, 1, 2, 3]);

http.Response json(Map<String, dynamic> cuerpo, int status) {
  return http.Response(
    jsonEncode(cuerpo),
    status,
    headers: {'content-type': 'application/json'},
  );
}

Matcher errorCon(String texto) => throwsA(
      isA<PhotoException>().having((e) => e.message, 'message', texto),
    );

void main() {
  group('subirImagen', () {
    test('envía la imagen como archivo y devuelve sus URLs', () async {
      late http.Request recibida;
      final servicio = ImgbbService(
        apiKey: 'clave123',
        client: MockClient((peticion) async {
          recibida = peticion;
          return json({
            'data': {
              'url': 'https://i.ibb.co/abc/foto.jpg',
              'display_url': 'https://i.ibb.co/abc/foto.jpg',
              'thumb': {'url': 'https://i.ibb.co/abc/foto-mini.jpg'},
              'delete_url': 'https://ibb.co/abc/borrar',
            },
            'success': true,
            'status': 200,
          }, 200);
        }),
      );

      final subida = await servicio.subirImagen(bytesPrueba);

      expect(subida.url, 'https://i.ibb.co/abc/foto.jpg');
      expect(subida.urlMiniatura, 'https://i.ibb.co/abc/foto-mini.jpg');
      expect(subida.urlEliminar, 'https://ibb.co/abc/borrar');

      expect(recibida.method, 'POST');
      expect(recibida.url.host, 'api.imgbb.com');
      expect(recibida.url.path, '/1/upload');
      expect(recibida.url.queryParameters, {'key': 'clave123'});
      expect(recibida.headers['content-type'], startsWith('multipart/form-data'));

      // Los bytes van tal cual, no en base64, y sin caducidad.
      final cuerpo = latin1.decode(recibida.bodyBytes);
      expect(cuerpo, contains('name="image"; filename="foto.jpg"'));
      expect(cuerpo, contains(latin1.decode(bytesPrueba)));
      expect(cuerpo, isNot(contains(base64Encode(bytesPrueba))));
      expect(cuerpo, isNot(contains('expiration')));
    });

    test('sin miniatura usa la URL de la imagen', () async {
      final servicio = ImgbbService(
        apiKey: 'clave',
        client: MockClient((_) async => json({
              'data': {'url': 'https://i.ibb.co/abc/foto.jpg'},
              'success': true,
              'status': 200,
            }, 200)),
      );

      final subida = await servicio.subirImagen(bytesPrueba);

      expect(subida.urlMiniatura, 'https://i.ibb.co/abc/foto.jpg');
      expect(subida.urlEliminar, isEmpty);
    });

    test('success=false da el mensaje de ImgBB', () async {
      final servicio = ImgbbService(
        apiKey: 'clave',
        client: MockClient((_) async => json({
              'error': {'message': 'Imagen no válida', 'code': 310},
              'success': false,
              'status': 200,
            }, 200)),
      );

      await expectLater(
        servicio.subirImagen(bytesPrueba),
        errorCon('No se pudo subir la imagen: Imagen no válida'),
      );
    });

    test('un status 400 da el mensaje de ImgBB', () async {
      final servicio = ImgbbService(
        apiKey: 'mala',
        client: MockClient((_) async => json({
              'status_code': 400,
              'error': {'message': 'Invalid API v1 key.', 'code': 100},
              'success': false,
              'status': 400,
            }, 400)),
      );

      await expectLater(
        servicio.subirImagen(bytesPrueba),
        errorCon('No se pudo subir la imagen: Invalid API v1 key.'),
      );
    });

    test('un error sin JSON indica el status', () async {
      final servicio = ImgbbService(
        apiKey: 'clave',
        client: MockClient((_) async => http.Response('<html>', 502)),
      );

      await expectLater(
        servicio.subirImagen(bytesPrueba),
        errorCon('No se pudo subir la imagen: error 502'),
      );
    });

    test('si tarda demasiado da error de conexión', () async {
      final servicio = ImgbbService(
        apiKey: 'clave',
        timeout: const Duration(milliseconds: 50),
        client: MockClient((_) => Completer<http.Response>().future),
      );

      await expectLater(
        servicio.subirImagen(bytesPrueba),
        errorCon('Sin conexión. Intenta de nuevo.'),
      );
    });

    test('sin red da error de conexión', () async {
      final sinRed = ImgbbService(
        apiKey: 'clave',
        client: MockClient((_) => throw const SocketException('sin red')),
      );
      final clienteFalla = ImgbbService(
        apiKey: 'clave',
        client: MockClient((_) => throw http.ClientException('fallo')),
      );

      await expectLater(
        sinRed.subirImagen(bytesPrueba),
        errorCon('Sin conexión. Intenta de nuevo.'),
      );
      await expectLater(
        clienteFalla.subirImagen(bytesPrueba),
        errorCon('Sin conexión. Intenta de nuevo.'),
      );
    });

    test('sin clave no hace la petición', () async {
      var peticiones = 0;
      final servicio = ImgbbService(
        apiKey: '',
        client: MockClient((_) async {
          peticiones++;
          return http.Response('', 200);
        }),
      );

      expect(servicio.tieneClave, isFalse);
      await expectLater(
        servicio.subirImagen(bytesPrueba),
        errorCon('Falta IMGBB_API_KEY. Revisa claves.json'),
      );
      expect(peticiones, 0);
    });
  });
}
