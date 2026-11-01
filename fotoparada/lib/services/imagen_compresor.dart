import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Tamaños máximos pensados para que imagen, miniatura y textos quepan en un
/// documento de Firestore (1 MiB): base64 aumenta los datos en un tercio.
const int maxBytesImagen = 700 * 1000;
const int maxBytesMiniatura = 60 * 1000;

class ImagenNoValidaException implements Exception {
  const ImagenNoValidaException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ImagenesComprimidas {
  const ImagenesComprimidas({required this.imagen, required this.miniatura});

  final Uint8List imagen;
  final Uint8List miniatura;
}

class ImagenCompresor {
  /// Se ejecuta en otro isolate porque decodificar una foto bloquearía la
  /// pantalla durante más de un segundo.
  Future<ImagenesComprimidas> comprimir(Uint8List bytes) =>
      compute(comprimirImagen, bytes);
}

typedef _Paso = ({int ancho, int calidad});

// Se prueban en orden hasta cumplir el límite: primero se sacrifica calidad y,
// si no basta, tamaño.
const List<_Paso> _pasosImagen = [
  (ancho: 1080, calidad: 70),
  (ancho: 1080, calidad: 60),
  (ancho: 1080, calidad: 50),
  (ancho: 1080, calidad: 40),
  (ancho: 960, calidad: 40),
  (ancho: 800, calidad: 40),
  (ancho: 640, calidad: 40),
  (ancho: 480, calidad: 30),
  (ancho: 320, calidad: 30),
];

const List<_Paso> _pasosMiniatura = [
  (ancho: 300, calidad: 60),
  (ancho: 300, calidad: 40),
  (ancho: 200, calidad: 40),
  (ancho: 120, calidad: 30),
];

ImagenesComprimidas comprimirImagen(Uint8List bytes) {
  final original = _decodificar(bytes);
  return ImagenesComprimidas(
    imagen: _comprimirConLimite(original, _pasosImagen, maxBytesImagen),
    miniatura: _comprimirConLimite(
      original,
      _pasosMiniatura,
      maxBytesMiniatura,
    ),
  );
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
