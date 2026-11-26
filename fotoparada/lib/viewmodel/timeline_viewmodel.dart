import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/coleccion_model.dart';
import '../models/foto_model.dart';
import '../models/linea_tiempo.dart';
import '../services/auth_service.dart';
import '../services/recuerdos_exception.dart';
import '../services/recuerdos_service.dart';

enum FiltroLineaTiempo { todas, mias }

/// Integrante 4 - Línea de tiempo fotográfica de un lugar.
class TimelineViewModel extends ChangeNotifier {
  TimelineViewModel({
    required this.nombreLugar,
    RecuerdosService? recuerdosService,
    AuthService? authService,
  })  : _service = recuerdosService ?? RecuerdosService(),
        _authService = authService ?? AuthService();

  final String nombreLugar;
  final RecuerdosService _service;
  final AuthService _authService;

  StreamSubscription<List<Foto>>? _suscripcion;

  List<Foto> _todas = [];

  bool _ascendente = true;

  /// true: de la más antigua a la más reciente.
  bool get ascendente => _ascendente;

  FiltroLineaTiempo _filtro = FiltroLineaTiempo.todas;
  FiltroLineaTiempo get filtro => _filtro;

  String? get uid => _authService.uid;

  List<Foto> get fotos {
    if (_filtro == FiltroLineaTiempo.todas) return _todas;
    return _todas.where((f) => f.uid == uid).toList();
  }

  List<GrupoAnual> get grupos => agruparPorAnio(fotos, ascendente: _ascendente);

  ResumenLineaTiempo? get resumen => ResumenLineaTiempo.desde(fotos);

  /// Se necesitan dos fotos para comparar "antes y después".
  bool get puedeComparar => _todas.length >= 2;

  bool esMia(Foto foto) => foto.uid == uid;

  /// Lugar para guardar en una colección. Usa la foto más reciente como
  /// referencia de coordenadas y portada.
  Lugar? get lugar {
    if (_todas.isEmpty) return null;
    return Lugar.desdeFoto(_todas.last);
  }

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

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

  void iniciar() {
    _suscripcion?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _suscripcion = _service.fotosDelLugar(nombreLugar, uid: uid).listen(
      (fotos) {
        _todas = fotos;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object error) {
        _isLoading = false;
        _errorMessage = RecuerdosException.mensajeDe(
          error,
          'No se pudo cargar la línea de tiempo.',
        );
        notifyListeners();
      },
    );
  }

  void alternarOrden() {
    _ascendente = !_ascendente;
    notifyListeners();
  }

  void cambiarFiltro(FiltroLineaTiempo filtro) {
    if (_filtro == filtro) return;
    _filtro = filtro;
    notifyListeners();
  }
}
