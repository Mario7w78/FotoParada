import 'package:flutter/foundation.dart';

import '../models/foto_model.dart';
import '../services/geocoding_service.dart';
import '../services/photo_service.dart';

class EditPhotoViewModel extends ChangeNotifier {
  EditPhotoViewModel({
    required Foto foto,
    PhotoService? photoService,
    GeocodingService? geocodingService,
  })  : _original = foto,
        _foto = foto,
        _photoService = photoService ?? PhotoService(),
        _geocodingService = geocodingService ?? GeocodingService();

  final PhotoService _photoService;
  final GeocodingService _geocodingService;

  Foto _original;

  Foto _foto;
  Foto get foto => _foto;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingUbicacion = false;
  bool get isLoadingUbicacion => _isLoadingUbicacion;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Tocar el mapa otra vez invalida el nombre de lugar que aún esté en camino.
  int _ultimaSolicitud = 0;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  // Los espacios sobrantes no cuentan como cambio y no se guardan.
  Map<String, dynamic> get _camposCambiados => _foto
      .copyWith(
        titulo: _foto.titulo.trim(),
        descripcion: _foto.descripcion.trim(),
      )
      .camposCambiados(_original);

  bool get hayCambios => _camposCambiados.isNotEmpty;

  void _actualizar(Foto foto) {
    _foto = foto;
    notifyListeners();
  }

  void cambiarTitulo(String valor) => _actualizar(_foto.copyWith(titulo: valor));

  void cambiarDescripcion(String valor) =>
      _actualizar(_foto.copyWith(descripcion: valor));

  void cambiarCategoria(CategoriaFoto valor) =>
      _actualizar(_foto.copyWith(categoria: valor));

  void cambiarPrivacidad(PrivacidadFoto valor) =>
      _actualizar(_foto.copyWith(privacidad: valor));

  void cambiarFechaToma(DateTime valor) =>
      _actualizar(_foto.copyWith(fechaToma: valor));

  Future<void> cambiarUbicacion(double latitud, double longitud) async {
    final solicitud = ++_ultimaSolicitud;
    _isLoadingUbicacion = true;
    _errorMessage = null;
    // El nombre anterior ya no corresponde a estas coordenadas.
    _actualizar(
      _foto.copyWith(latitud: latitud, longitud: longitud, nombreLugar: ''),
    );

    String nombre = '';
    try {
      nombre = await _geocodingService.reverse(latitud, longitud) ?? '';
    } catch (e) {
      debugPrint('No se pudo obtener el nombre del lugar: $e');
    }

    if (solicitud != _ultimaSolicitud) return;
    _isLoadingUbicacion = false;
    _actualizar(_foto.copyWith(nombreLugar: nombre));
  }

  /// Devuelve true si se guardó. Si no, deja el motivo en [errorMessage].
  Future<bool> guardar() async {
    if (_isLoading || !hayCambios) return false;

    final errorValidacion = _validar();
    if (errorValidacion != null) {
      _errorMessage = errorValidacion;
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _photoService.actualizarFoto(_foto.id, _camposCambiados);
      _foto = _foto.copyWith(
        titulo: _foto.titulo.trim(),
        descripcion: _foto.descripcion.trim(),
      );
      _original = _foto;
      return true;
    } on PhotoException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (_) {
      _errorMessage = 'No se pudieron guardar los cambios. Intenta de nuevo.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Devuelve true si se eliminó. Si no, deja el motivo en [errorMessage].
  Future<bool> eliminar() async {
    if (_isLoading) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Se borra la foto guardada, no el borrador con cambios sin guardar.
      await _photoService.eliminarFoto(_original);
      return true;
    } on PhotoException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (_) {
      _errorMessage = 'No se pudo eliminar la foto. Intenta de nuevo.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String? _validar() {
    if (_foto.titulo.trim().isEmpty) return 'Escribe un título para la foto.';
    if (_isLoadingUbicacion) return 'Espera a que se obtenga la ubicación.';
    return null;
  }
}
