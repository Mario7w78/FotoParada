import 'package:flutter/foundation.dart';

import '../models/foto_model.dart';
import '../services/share_service.dart';

/// Lo que se comparte en ShareLocationView: un lugar y, opcionalmente, la foto
/// tomada ahí.
class ShareLocationArgs {
  final String nombreLugar;
  final double latitud;
  final double longitud;
  final Foto? foto;

  const ShareLocationArgs({
    required this.nombreLugar,
    required this.latitud,
    required this.longitud,
    this.foto,
  });

  factory ShareLocationArgs.desdeFoto(Foto foto) {
    return ShareLocationArgs(
      nombreLugar: foto.nombreLugar,
      latitud: foto.latitud,
      longitud: foto.longitud,
      foto: foto,
    );
  }
}

class ShareLocationViewModel extends ChangeNotifier {
  ShareLocationViewModel({
    required this.args,
    ShareService? shareService,
  }) : _shareService = shareService ?? ShareService();

  final ShareLocationArgs args;
  final ShareService _shareService;

  ProveedorMapa _proveedor = ProveedorMapa.googleMaps;
  ProveedorMapa get proveedor => _proveedor;

  bool _incluirFoto = true;
  bool get incluirFoto => _incluirFoto;

  bool get tieneFoto => args.foto != null && args.foto!.urlImagen.isNotEmpty;

  bool _isCompartiendo = false;
  bool get isCompartiendo => _isCompartiendo;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String get nombreLugar => args.nombreLugar.trim().isEmpty
      ? 'Ubicación sin nombre'
      : args.nombreLugar.trim();

  String get enlace => _shareService.enlaceUbicacion(
        args.latitud,
        args.longitud,
        proveedor: _proveedor,
      );

  String get texto => _shareService.textoParaCompartir(
        nombreLugar: args.nombreLugar,
        latitud: args.latitud,
        longitud: args.longitud,
        foto: args.foto,
        incluirFoto: _incluirFoto,
        proveedor: _proveedor,
      );

  void cambiarProveedor(ProveedorMapa valor) {
    _proveedor = valor;
    notifyListeners();
  }

  void cambiarIncluirFoto(bool valor) {
    _incluirFoto = valor;
    notifyListeners();
  }

  Future<bool> compartir() async {
    if (_isCompartiendo) return false;
    _isCompartiendo = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _shareService.compartir(texto: texto, asunto: nombreLugar);
      return true;
    } catch (_) {
      _errorMessage = 'No se pudo abrir el menú para compartir.';
      return false;
    } finally {
      _isCompartiendo = false;
      notifyListeners();
    }
  }

  Future<bool> copiarEnlace() async {
    _errorMessage = null;
    try {
      await _shareService.copiar(texto);
      return true;
    } catch (_) {
      _errorMessage = 'No se pudo copiar el enlace.';
      notifyListeners();
      return false;
    }
  }
}
