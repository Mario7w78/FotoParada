import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/foto_model.dart';
import '../services/photo_service.dart';

/// Define cómo se están ordenando las fotos actualmente.
enum ModoOrdenamiento { recientes, populares }

class LocationDetailViewModel extends ChangeNotifier {
  LocationDetailViewModel({
    required this.nombreLugar,
    PhotoService? photoService,
  }) : _photoService = photoService ?? PhotoService() {
    _cargarFotos();
  }

  final String nombreLugar;
  final PhotoService _photoService;

  StreamSubscription<List<Foto>>? _fotosSubscription;

  // Estado
  List<Foto> _fotos = [];
  List<Foto> get fotos => _fotos;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  ModoOrdenamiento _modoActual = ModoOrdenamiento.recientes;
  ModoOrdenamiento get modoActual => _modoActual;

  /// Cambia entre ver las más recientes o las más populares
  void cambiarModoOrdenamiento(ModoOrdenamiento nuevoModo) {
    if (_modoActual == nuevoModo) return;
    
    _modoActual = nuevoModo;
    _cargarFotos();
  }

  void _cargarFotos() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _fotosSubscription?.cancel();

    Stream<List<Foto>> stream;

    if (_modoActual == ModoOrdenamiento.recientes) {
      stream = _photoService.obtenerFotosPorLugarRecientes(nombreLugar);
    } else {
      stream = _photoService.obtenerFotosPorLugarPopulares(nombreLugar);
    }

    _fotosSubscription = stream.listen(
      (fotosLlegadas) {
        _fotos = fotosLlegadas;
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _fotosSubscription?.cancel();
    super.dispose();
  }
}
