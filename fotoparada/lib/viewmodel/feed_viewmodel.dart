import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/foto_model.dart';
import '../services/photo_service.dart';

class FeedViewModel extends ChangeNotifier {
  FeedViewModel({PhotoService? photoService})
      : _photoService = photoService ?? PhotoService();

  final PhotoService _photoService;

  StreamSubscription<List<Foto>>? _suscripcion;

  List<Foto> _fotos = [];
  List<Foto> get fotos => _fotos;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // La vista puede destruirse (p. ej. al cambiar de pestaña) mientras
  // se espera la respuesta de Firestore.
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

  /// Escucha las fotos públicas de Firestore. También sirve para reintentar.
  void cargarFotos() {
    _suscripcion?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _suscripcion = _photoService.obtenerFotosPublicas().listen(
      (fotos) {
        _fotos = fotos;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object error) {
        _isLoading = false;
        _errorMessage = error is PhotoException
            ? error.message
            : 'No se pudieron cargar las fotos.';
        notifyListeners();
      },
    );
  }
}
