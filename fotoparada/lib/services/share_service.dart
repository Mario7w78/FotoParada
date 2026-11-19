import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/foto_model.dart';

enum ProveedorMapa {
  googleMaps('Google Maps'),
  openStreetMap('OpenStreetMap');

  const ProveedorMapa(this.etiqueta);

  final String etiqueta;
}

/// Genera los enlaces de fotos y ubicaciones y los entrega a la hoja de
/// compartir del sistema o al portapapeles.
class ShareService {
  /// Enlace que abre [latitud], [longitud] en el mapa de [proveedor]. Se usan
  /// mapas web para que el enlace funcione aunque quien lo reciba no tenga la
  /// app instalada.
  String enlaceUbicacion(
    double latitud,
    double longitud, {
    ProveedorMapa proveedor = ProveedorMapa.googleMaps,
  }) {
    final lat = latitud.toStringAsFixed(6);
    final lng = longitud.toStringAsFixed(6);

    switch (proveedor) {
      case ProveedorMapa.googleMaps:
        return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      case ProveedorMapa.openStreetMap:
        return 'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng'
            '#map=17/$lat/$lng';
    }
  }

  /// Texto para compartir un lugar. Si se pasa [foto], incluye su título y el
  /// enlace a la imagen.
  String textoParaCompartir({
    required String nombreLugar,
    required double latitud,
    required double longitud,
    Foto? foto,
    bool incluirFoto = true,
    ProveedorMapa proveedor = ProveedorMapa.googleMaps,
  }) {
    final lugar = nombreLugar.trim().isEmpty
        ? 'este lugar'
        : nombreLugar.trim();
    final lineas = <String>[];

    if (foto != null && incluirFoto && foto.urlImagen.isNotEmpty) {
      lineas.add('📸 "${foto.titulo}" en $lugar');
      lineas.add('Foto: ${foto.urlImagen}');
    } else {
      lineas.add('📍 Te comparto $lugar');
    }
    lineas.add(
      'Ubicación: ${enlaceUbicacion(latitud, longitud, proveedor: proveedor)}',
    );
    lineas.add('Compartido desde FotoParada');

    return lineas.join('\n');
  }

  Future<void> compartir({required String texto, String? asunto}) async {
    await SharePlus.instance.share(ShareParams(text: texto, subject: asunto));
  }

  Future<void> copiar(String texto) {
    return Clipboard.setData(ClipboardData(text: texto));
  }
}
