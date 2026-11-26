import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/foto_model.dart';
import '../models/linea_tiempo.dart';
import '../services/auth_service.dart';
import '../services/recuerdos_exception.dart';
import '../services/recuerdos_service.dart';

enum ModoComparacion { deslizador, ladoALado }

enum LadoComparacion { antes, despues }

/// Argumentos de la ruta de comparación. Los ids son opcionales: sin ellos se
/// comparan la foto más antigua y la más reciente.
class ComparePhotosArgs {
  const ComparePhotosArgs({
    required this.nombreLugar,
    this.fotoAntesId,
    this.fotoDespuesId,
  });

  final String nombreLugar;
  final String? fotoAntesId;
  final String? fotoDespuesId;
}

/// Integrante 4 - Comparación de una foto antigua con una reciente del mismo
/// lugar.
class ComparePhotosViewModel extends ChangeNotifier {
  ComparePhotosViewModel({
    required this.args,
    RecuerdosService? recuerdosService,
    AuthService? authService,
  })  : _service = recuerdosService ?? RecuerdosService(),
        _authService = authService ?? AuthService();

  final ComparePhotosArgs args;
  final RecuerdosService _service;
  final AuthService _authService;

  String get nombreLugar => args.nombreLugar;

  StreamSubscription<List<Foto>>? _suscripcion;

  /// De la más antigua a la más reciente.
  List<Foto> _fotos = [];
  List<Foto> get fotos => _fotos;

  Foto? _antes;
  Foto? get antes => _antes;

  Foto? _despues;
  Foto? get despues => _despues;

  /// Lado que se cambia al tocar una miniatura.
  LadoComparacion _ladoActivo = LadoComparacion.antes;
  LadoComparacion get ladoActivo => _ladoActivo;

  ModoComparacion _modo = ModoComparacion.deslizador;
  ModoComparacion get modo => _modo;

  /// Posición de la línea del deslizador, de 0 (todo "después") a 1 (todo
  /// "antes").
  double _posicion = 0.5;
  double get posicion => _posicion;

  bool get puedeComparar => _antes != null && _despues != null;

  /// "3 años y 2 meses" entre ambas fotos.
  String get diferencia {
    if (!puedeComparar) return '';
    return describirDiferencia(_antes!.fechaToma, _despues!.fechaToma);
  }

  /// La foto "antes" es posterior a la "después": se avisa en pantalla.
  bool get ordenInvertido =>
      puedeComparar && _antes!.fechaToma.isAfter(_despues!.fechaToma);

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

    _suscripcion =
        _service.fotosDelLugar(nombreLugar, uid: _authService.uid).listen(
      (fotos) {
        _fotos = ordenarPorFechaToma(fotos);
        _ajustarSeleccion();
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object error) {
        _isLoading = false;
        _errorMessage = RecuerdosException.mensajeDe(
          error,
          'No se pudieron cargar las fotos del lugar.',
        );
        notifyListeners();
      },
    );
  }

  /// Mantiene la selección si las fotos siguen existiendo; si no, elige la más
  /// antigua y la más reciente (o las indicadas en [args] la primera vez).
  void _ajustarSeleccion() {
    Foto? buscar(String? id) =>
        id == null ? null : _fotos.where((f) => f.id == id).firstOrNull;

    final par = parInicialParaComparar(_fotos);
    _antes = buscar(_antes?.id) ?? buscar(args.fotoAntesId) ?? par?.antigua;
    _despues =
        buscar(_despues?.id) ?? buscar(args.fotoDespuesId) ?? par?.reciente;
  }

  void cambiarLadoActivo(LadoComparacion lado) {
    _ladoActivo = lado;
    notifyListeners();
  }

  /// Pone [foto] en el lado activo y pasa al otro lado para agilizar la
  /// elección de ambas.
  void elegir(Foto foto) {
    if (_ladoActivo == LadoComparacion.antes) {
      _antes = foto;
      _ladoActivo = LadoComparacion.despues;
    } else {
      _despues = foto;
      _ladoActivo = LadoComparacion.antes;
    }
    notifyListeners();
  }

  void intercambiar() {
    final temporal = _antes;
    _antes = _despues;
    _despues = temporal;
    notifyListeners();
  }

  void cambiarModo(ModoComparacion modo) {
    if (_modo == modo) return;
    _modo = modo;
    notifyListeners();
  }

  void moverDeslizador(double posicion) {
    _posicion = posicion.clamp(0.0, 1.0);
    notifyListeners();
  }
}
