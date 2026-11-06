import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Tope de la imagen que se sube a ImgBB (admite hasta 32 MB). Se comprime
/// igual para que suba rápido y gaste menos datos.
const int maxBytesImagen = 5 * 1000 * 1000;

class ImagenNoValidaException implements Exception {
  const ImagenNoValidaException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ImagenCompresor {
  /// Se ejecuta en otro isolate porque decodificar una foto bloquearía la
  /// pantalla durante más de un segundo.
  Future<Uint8List> comprimir(Uint8List bytes) =>
      compute(comprimirImagen, bytes);
}

typedef _Paso = ({int ancho, int calidad});

// Se prueban en orden hasta cumplir el límite: primero se sacrifica calidad y,
// si no basta, tamaño.
const List<_Paso> _pasosImagen = [
  (ancho: 1920, calidad: 85),
  (ancho: 1920, calidad: 75),
  (ancho: 1600, calidad: 75),
  (ancho: 1280, calidad: 70),
];

/// Devuelve la imagen en JPEG, sin metadatos y dentro de [maxBytesImagen]. La
/// miniatura no se genera aquí: la crea ImgBB.
Uint8List comprimirImagen(Uint8List bytes) {
  return _comprimirConLimite(_decodificar(bytes), _pasosImagen, maxBytesImagen);
}

img.Image _decodificar(Uint8List bytes) {
  img.Image? imagen;
  try {
    imagen = img.decodeImage(bytes);
  } catch (_) {
    imagen = null;
  }
  if (imagen == null) {
    throw const ImagenNoValidaException(
      'Formato no soportado. Usa una imagen JPG o PNG.',
    );
  }

  // Aplicar la rotación antes de medir, para que el ancho sea el que se ve.
  final orientada = img.bakeOrientation(imagen);
  // No se conservan los metadatos: pesan y pueden incluir el GPS de la foto,
  // aunque el usuario elija otra ubicación.
  orientada.exif = img.ExifData();
  return _sobreFondoBlanco(orientada);
}

// JPEG no admite transparencia: sin esto, lo transparente se vería negro.
img.Image _sobreFondoBlanco(img.Image imagen) {
  if (imagen.numChannels < 4 && imagen.palette == null) return imagen;

  final fondo = img.Image(width: imagen.width, height: imagen.height);
  img.fill(fondo, color: img.ColorRgb8(255, 255, 255));
  return img.compositeImage(fondo, imagen);
}

Uint8List _comprimirConLimite(
  img.Image original,
  List<_Paso> pasos,
  int maxBytes,
) {
  for (final paso in pasos) {
    final jpeg = img.encodeJpg(
      _reducir(original, paso.ancho),
      quality: paso.calidad,
      chroma: img.JpegChroma.yuv420,
    );
    if (jpeg.length <= maxBytes) return jpeg;
  }
  throw const ImagenNoValidaException(
    'La imagen es demasiado grande. Prueba con otra foto.',
  );
}

img.Image _reducir(img.Image original, int ancho) {
  if (original.width <= ancho) return original;
  return img.copyResize(
    original,
    width: ancho,
    interpolation: img.Interpolation.average,
  );
}
