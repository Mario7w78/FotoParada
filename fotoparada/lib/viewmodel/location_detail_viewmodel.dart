import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/foto_model.dart';
import '../services/photo_service.dart';
import '../services/recuerdos_service.dart';

/// Define cómo se están ordenando las fotos actualmente.
enum ModoOrdenamiento { recientes, populares }

class LocationDetailViewModel extends ChangeNotifier {
  LocationDetailViewModel({
    required this.nombreLugar,
    this.latitud,
    this.longitud,
    PhotoService? photoService,
    this._recuerdosService,
  })  : _photoService = photoService ?? PhotoService() {
    _cargarFotos();
  }

  final String nombreLugar;

  /// Si se dan, se muestran las fotos cercanas a este punto en lugar de buscar
  /// por nombre.
  final double? latitud;
  final double? longitud;

  final PhotoService _photoService;
  final RecuerdosService? _recuerdosService;

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

    final Stream<List<Foto>> stream;

    if (latitud != null && longitud != null) {
      stream = _fotosCercanas(latitud!, longitud!);
    } else if (_modoActual == ModoOrdenamiento.recientes) {
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

  /// Fotos públicas alrededor del punto, ordenadas en el teléfono según el
  /// modo elegido.
  Stream<List<Foto>> _fotosCercanas(double latitud, double longitud) {
    final servicio = _recuerdosService ?? RecuerdosService();
    // Sin nombre ni uid: solo cuentan la distancia y las fotos públicas.
    return servicio
        .fotosDelLugar('', latitud: latitud, longitud: longitud)
        .map((fotos) => [...fotos]..sort(_comparar));
  }

  int _comparar(Foto a, Foto b) {
    if (_modoActual == ModoOrdenamiento.populares) {
      final porLikes = b.likes.compareTo(a.likes);
      if (porLikes != 0) return porLikes;
    }
    return b.fechaSubida.compareTo(a.fechaSubida);
  }

  @override
  void dispose() {
    _fotosSubscription?.cancel();
    super.dispose();
  }
}
