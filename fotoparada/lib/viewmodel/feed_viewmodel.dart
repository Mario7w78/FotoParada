import 'package:flutter/foundation.dart';

import '../models/foto_model.dart';
import '../services/api_service.dart';

class FeedViewModel extends ChangeNotifier {
  FeedViewModel({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  List<Foto> _fotos = [];
  List<Foto> get fotos => _fotos;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> cargarFotos() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _fotos = await _apiService.obtenerFotos();
    } catch (_) {
      _errorMessage = 'No se pudieron cargar las fotos.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
