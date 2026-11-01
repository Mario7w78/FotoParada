import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:native_exif/native_exif.dart';

class UbicacionException implements Exception {
  const UbicacionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MetadatosExif {
  const MetadatosExif({this.ubicacion, this.fecha});

  final LatLng? ubicacion;
  final DateTime? fecha;
}

class FotoMetadataService {
  /// Lee GPS y fecha del EXIF. Un dato ausente o ilegible se devuelve como nulo
  /// porque ambos son opcionales en una foto.
  Future<MetadatosExif> leerExif(String ruta) async {
    final Exif exif;
    try {
      exif = await Exif.fromPath(ruta);
    } catch (_) {
      return const MetadatosExif();
    }

    final coordenadas = await _oNulo(exif.getLatLong);
    final fecha = await _oNulo(exif.getOriginalDate);
    await _oNulo(exif.close);

    return MetadatosExif(
      ubicacion: coordenadas == null
          ? null
          : _validarCoordenadas(coordenadas.latitude, coordenadas.longitude),
      fecha: fecha,
    );
  }

  Future<LatLng> ubicacionActual() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const UbicacionException(
        'Activa la ubicación del dispositivo o elige el lugar en el mapa.',
      );
    }

    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      throw const UbicacionException(
        'Sin permiso de ubicación. Elige el lugar tocando el mapa.',
      );
    }

    try {
      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LatLng(posicion.latitude, posicion.longitude);
    } on TimeoutException {
      // Sin señal de GPS, lo más cercano es la última posición que tiene Android.
      final ultima = await Geolocator.getLastKnownPosition();
      if (ultima != null) return LatLng(ultima.latitude, ultima.longitude);

      throw const UbicacionException(
        'No se pudo obtener tu ubicación. Elige el lugar tocando el mapa.',
      );
    }
  }

  // Android entrega 0,0 cuando oculta el GPS de la foto a la app, y ese punto
  // en medio del océano no es una ubicación real.
  LatLng? _validarCoordenadas(double latitud, double longitud) {
    if (latitud == 0 && longitud == 0) return null;
    if (latitud.abs() > 90 || longitud.abs() > 180) return null;
    return LatLng(latitud, longitud);
  }

  Future<T?> _oNulo<T>(Future<T?> Function() lectura) async {
    try {
      return await lectura();
    } catch (_) {
      return null;
    }
  }
}
