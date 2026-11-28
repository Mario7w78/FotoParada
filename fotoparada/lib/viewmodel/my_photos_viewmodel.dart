import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/foto_model.dart';
import '../repositories/foto_repository.dart';
import '../services/auth_service.dart';
import '../services/photo_exception.dart';

class MyPhotosViewModel extends ChangeNotifier {
  MyPhotosViewModel({FotoRepository? fotoRepository, AuthService? authService})
      : _fotoRepository = fotoRepository ?? FotoRepository(),
        _authService = authService ?? AuthService();

  final FotoRepository _fotoRepository;
  final AuthService _authService;

  StreamSubscription<List<Foto>>? _suscripcion;

  List<Foto> _todas = [];

  PrivacidadFoto? _filtro;
  PrivacidadFoto? get filtro => _filtro;

  /// Sin las que se están eliminando.
  List<Foto> get fotos => _todas
      .where(
        (foto) =>
            !_eliminando.contains(foto.id) &&
            (_filtro == null || foto.privacidad == _filtro),
      )
      .toList();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Error al cargar la lista: se muestra en lugar de la grilla.
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Error de la última eliminación: la lista sigue siendo válida.
  String? _errorEliminar;
  String? get errorEliminar => _errorEliminar;

  /// El usuario no tiene ninguna foto, sea cual sea el filtro.
  bool get sinFotos =>
      !_isLoading &&
      _errorMessage == null &&
      _todas.every((foto) => _eliminando.contains(foto.id));

  final Set<String> _eliminando = {};
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _suscripcion?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  /// Empieza a escuchar las fotos. También sirve para reintentar tras un error,
  /// porque Firestore cierra la escucha cuando falla.
  void iniciar() {
    _suscripcion?.cancel();
    _suscripcion = null;
    _todas = [];

    final uid = _authService.uid;
    if (uid == null) {
      _isLoading = false;
      _errorMessage = 'Debes iniciar sesión para ver tus fotos.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _suscripcion = _fotoRepository.obtenerMisFotos(uid).listen(
      (fotos) {
        _todas = fotos;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object error) {
        _isLoading = false;
        _errorMessage = error is PhotoException
            ? error.message
            : 'No se pudieron cargar tus fotos.';
        notifyListeners();
      },
    );
  }

  void cambiarFiltro(PrivacidadFoto? valor) {
    _filtro = valor;
    notifyListeners();
  }

  /// Devuelve true si se eliminó. Si no, deja el motivo en [errorEliminar].
  /// La foto desaparece de la lista al instante y vuelve si el borrado falla.
  Future<bool> eliminarFoto(Foto foto) async {
    if (!_eliminando.add(foto.id)) return false;
    _errorEliminar = null;
    notifyListeners();

    try {
      await _fotoRepository.eliminarFoto(foto);
      _todas = _todas.where((f) => f.id != foto.id).toList();
      return true;
    } on PhotoException catch (e) {
      _errorEliminar = e.message;
      return false;
    } catch (_) {
      _errorEliminar = 'No se pudo eliminar la foto. Intenta de nuevo.';
      return false;
    } finally {
      _eliminando.remove(foto.id);
      notifyListeners();
    }
  }
}
