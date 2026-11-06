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
  test('reduce a 1920 px de ancho y devuelve JPEG', () {
    final resultado = comprimirImagen(img.encodeJpg(crearLisa(3000, 2000)));

    final imagen = img.decodeJpg(resultado)!;
    expect(imagen.width, 1920);
    expect(imagen.height, 1280);
    expect(esJpeg(resultado), isTrue);
  });

  test('no agranda una imagen más pequeña que el máximo', () {
    final resultado = comprimirImagen(img.encodeJpg(crearLisa(200, 100)));

    expect(img.decodeJpg(resultado)!.width, 200);
  });

  test('cumple el límite incluso con el peor caso', () {
    final resultado = comprimirImagen(
      img.encodeJpg(crearRuido(2400, 1800), quality: 100),
    );

    expect(resultado.length, lessThanOrEqualTo(maxBytesImagen));
    expect(img.decodeJpg(resultado)!.width, lessThanOrEqualTo(1920));
  });

  test('aplica la rotación EXIF antes de medir el ancho', () {
    final vertical = crearLisa(3000, 2000)..exif.imageIfd.orientation = 6;

    final resultado = comprimirImagen(img.encodeJpg(vertical));

    final imagen = img.decodeJpg(resultado)!;
    expect(imagen.width, 1920);
    expect(imagen.height, 2880);
  });

  test('no conserva los metadatos de la foto', () {
    final conGps = crearLisa(400, 300);
    conGps.exif.gpsIfd
      ..gpsLatitude = 12.5
      ..gpsLongitude = 76.25;
    expect(img.decodeJpg(img.encodeJpg(conGps))!.exif.gpsIfd.isEmpty, isFalse);

    final resultado = comprimirImagen(img.encodeJpg(conGps));

    expect(img.decodeJpg(resultado)!.exif.gpsIfd.isEmpty, isTrue);
  });

  test('convierte PNG a JPEG poniendo blanco lo transparente', () {
    final transparente = img.Image(width: 50, height: 50, numChannels: 4);

    final resultado = comprimirImagen(img.encodePng(transparente));

    expect(esJpeg(resultado), isTrue);
    final pixel = img.decodeJpg(resultado)!.getPixel(25, 25);
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
      img.encodeJpg(crearLisa(2400, 1600)),
    );

    expect(img.decodeJpg(resultado)!.width, 1920);
  });
}
