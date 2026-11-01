import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fotoparada/services/imagen_compresor.dart';
import 'package:image/image.dart' as img;

/// Ruido aleatorio: el peor caso para JPEG, porque casi no se puede comprimir.
img.Image crearRuido(int ancho, int alto) {
  final azar = Random(1);
  final imagen = img.Image(width: ancho, height: alto);
  for (final pixel in imagen) {
    pixel
      ..r = azar.nextInt(256)
      ..g = azar.nextInt(256)
      ..b = azar.nextInt(256);
  }
  return imagen;
}

img.Image crearLisa(int ancho, int alto) {
  final imagen = img.Image(width: ancho, height: alto);
  img.fill(imagen, color: img.ColorRgb8(40, 120, 200));
  return imagen;
}

bool esJpeg(Uint8List bytes) =>
    bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;

void main() {
  test('reduce a 1080 px de ancho y a 300 px la miniatura', () {
    final resultado = comprimirImagen(
      img.encodeJpg(crearLisa(2000, 1500)),
    );

    final imagen = img.decodeJpg(resultado.imagen)!;
    final miniatura = img.decodeJpg(resultado.miniatura)!;
    expect(imagen.width, 1080);
    expect(imagen.height, 810);
    expect(miniatura.width, 300);
    expect(esJpeg(resultado.imagen), isTrue);
    expect(esJpeg(resultado.miniatura), isTrue);
  });

  test('no agranda una imagen más pequeña que el máximo', () {
    final resultado = comprimirImagen(img.encodeJpg(crearLisa(200, 100)));

    expect(img.decodeJpg(resultado.imagen)!.width, 200);
    expect(img.decodeJpg(resultado.miniatura)!.width, 200);
  });

  test('cumple los límites incluso con el peor caso', () {
    final resultado = comprimirImagen(
      img.encodeJpg(crearRuido(1920, 1440), quality: 100),
    );

    expect(resultado.imagen.length, lessThanOrEqualTo(maxBytesImagen));
    expect(resultado.miniatura.length, lessThanOrEqualTo(maxBytesMiniatura));
  });

  test('imagen, miniatura y base64 caben en un documento de Firestore', () {
    final limiteBase64 =
        (maxBytesImagen + maxBytesMiniatura + 2) ~/ 3 * 4;

    // Deja sitio para título, descripción y el resto de los campos.
    expect(limiteBase64, lessThan(1024 * 1024 - 30 * 1024));
  });

  test('aplica la rotación EXIF antes de medir el ancho', () {
    final vertical = crearLisa(2000, 1500)..exif.imageIfd.orientation = 6;

    final resultado = comprimirImagen(img.encodeJpg(vertical));

    final imagen = img.decodeJpg(resultado.imagen)!;
    expect(imagen.width, 1080);
    expect(imagen.height, 1440);
  });

  test('no conserva los metadatos de la foto', () {
    final conGps = crearLisa(400, 300);
    conGps.exif.gpsIfd
      ..gpsLatitude = 12.5
      ..gpsLongitude = 76.25;
    expect(img.decodeJpg(img.encodeJpg(conGps))!.exif.gpsIfd.isEmpty, isFalse);

    final resultado = comprimirImagen(img.encodeJpg(conGps));

    expect(img.decodeJpg(resultado.imagen)!.exif.gpsIfd.isEmpty, isTrue);
    expect(img.decodeJpg(resultado.miniatura)!.exif.gpsIfd.isEmpty, isTrue);
  });

  test('convierte PNG a JPEG poniendo blanco lo transparente', () {
    final transparente = img.Image(width: 50, height: 50, numChannels: 4);

    final resultado = comprimirImagen(img.encodePng(transparente));

    expect(esJpeg(resultado.imagen), isTrue);
    final pixel = img.decodeJpg(resultado.imagen)!.getPixel(25, 25);
    expect(pixel.r, greaterThan(250));
    expect(pixel.g, greaterThan(250));
    expect(pixel.b, greaterThan(250));
  });

  test('rechaza un archivo que no es una imagen', () {
    expect(
      () => comprimirImagen(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8])),
      throwsA(isA<ImagenNoValidaException>()),
    );
    expect(
      () => comprimirImagen(Uint8List(0)),
      throwsA(isA<ImagenNoValidaException>()),
    );
  });

  test('el compresor funciona en otro isolate', () async {
    final resultado = await ImagenCompresor().comprimir(
      img.encodeJpg(crearLisa(1200, 800)),
    );

    expect(img.decodeJpg(resultado.imagen)!.width, 1080);
  });
}
