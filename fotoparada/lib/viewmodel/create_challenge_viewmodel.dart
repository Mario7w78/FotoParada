import 'package:flutter/foundation.dart';

import '../models/foto_model.dart';
import '../models/reto_model.dart';
import '../services/auth_service.dart';
import '../services/challenge_service.dart';
import '../services/foto_metadata_service.dart';
import '../services/geocoding_service.dart';
import '../services/interaccion_exception.dart';

class CreateChallengeViewModel extends ChangeNotifier {
  CreateChallengeViewModel({
    ChallengeService? challengeService,
    AuthService? authService,
    FotoMetadataService? metadataService,
    GeocodingService? geocodingService,
  })  : _challengeService = challengeService ?? ChallengeService(),
        _authService = authService ?? AuthService(),
        _metadataService = metadataService ?? FotoMetadataService(),
        _geocodingService = geocodingService ?? GeocodingService();

  final ChallengeService _challengeService;
  final AuthService _authService;
  final FotoMetadataService _metadataService;
  final GeocodingService _geocodingService;

  static const List<double> radiosDisponibles = [100, 200, 500, 1000];

  String _titulo = '';
  String _descripcion = '';

  // El texto lo muestran los controladores de la vista, no hace falta redibujar.
  void cambiarTitulo(String valor) => _titulo = valor;
  void cambiarDescripcion(String valor) => _descripcion = valor;

  /// Nula: se acepta cualquier categoría.
  CategoriaFoto? _categoria;
  CategoriaFoto? get categoria => _categoria;

  int _fotosObjetivo = 1;
  int get fotosObjetivo => _fotosObjetivo;

  DateTime _fechaFin = DateTime.now().add(const Duration(days: 7));
  DateTime get fechaFin => _fechaFin;

  double? _latitud;
  double? get latitud => _latitud;

  double? _longitud;
  double? get longitud => _longitud;

  bool get tieneUbicacion => _latitud != null && _longitud != null;

  String _nombreLugar = '';
  String get nombreLugar => _nombreLugar;

  double _radioMetros = Reto.radioPorDefecto;
  double get radioMetros => _radioMetros;

  bool _isLoadingUbicacion = false;
  bool get isLoadingUbicacion => _isLoadingUbicacion;

  bool _isGuardando = false;
  bool get isGuardando => _isGuardando;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

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

  void cambiarCategoria(CategoriaFoto? valor) {
    _categoria = valor;
    notifyListeners();
  }

  void cambiarFotosObjetivo(int valor) {
    _fotosObjetivo = valor.clamp(1, 10);
    notifyListeners();
  }

  void cambiarFechaFin(DateTime valor) {
    // El reto termina al final del día elegido.
    _fechaFin = DateTime(valor.year, valor.month, valor.day, 23, 59, 59);
    notifyListeners();
  }

  void cambiarRadio(double valor) {
    _radioMetros = valor;
    notifyListeners();
  }

  void quitarUbicacion() {
    _latitud = null;
    _longitud = null;
    _nombreLugar = '';
    notifyListeners();
  }

  /// Fija el punto del reto en la ubicación actual del usuario.
  Future<void> usarMiUbicacion() async {
    if (_isLoadingUbicacion) return;
    _isLoadingUbicacion = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final punto = await _metadataService.ubicacionActual();
      _latitud = punto.latitude;
      _longitud = punto.longitude;
      _nombreLugar = '';
      notifyListeners();

      // El nombre es opcional: sin él se muestran las coordenadas.
      try {
        _nombreLugar = await _geocodingService.reverse(
              punto.latitude,
              punto.longitude,
            ) ??
            '';
      } catch (e) {
        debugPrint('No se pudo obtener el nombre del lugar: $e');
      }
    } on UbicacionException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'No se pudo obtener tu ubicación.';
    } finally {
      _isLoadingUbicacion = false;
      notifyListeners();
    }
  }

  /// Devuelve el reto creado, o null si falló (el motivo queda en
  /// [errorMessage]).
  Future<Reto?> crear() async {
    if (_isGuardando) return null;
    final uid = _authService.uid;
    if (uid == null) {
      _errorMessage = 'Debes iniciar sesión para crear un reto.';
      notifyListeners();
      return null;
    }
    if (_isLoadingUbicacion) {
      _errorMessage = 'Espera a que se obtenga la ubicación.';
      notifyListeners();
      return null;
    }

    _isGuardando = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final nombre = _authService.displayName.trim();
      return await _challengeService.crearReto(
        creadorUid: uid,
        creadorNombre: nombre.isEmpty ? 'Usuario' : nombre,
        titulo: _titulo,
        descripcion: _descripcion,
        categoria: _categoria,
        latitud: _latitud,
        longitud: _longitud,
        nombreLugar: _nombreLugar,
        radioMetros: _radioMetros,
        fotosObjetivo: _fotosObjetivo,
        fechaFin: _fechaFin,
      );
    } on InteraccionException catch (e) {
      _errorMessage = e.message;
      return null;
    } catch (_) {
      _errorMessage = 'No se pudo crear el reto. Intenta de nuevo.';
      return null;
    } finally {
      _isGuardando = false;
      notifyListeners();
    }
  }
}
