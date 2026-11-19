import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/reto_model.dart';
import '../services/auth_service.dart';
import '../services/challenge_service.dart';
import '../services/interaccion_exception.dart';

enum FiltroRetos { activos, mios, finalizados }

class ChallengesViewModel extends ChangeNotifier {
  ChallengesViewModel({
    ChallengeService? challengeService,
    AuthService? authService,
  })  : _challengeService = challengeService ?? ChallengeService(),
        _authService = authService ?? AuthService();

  final ChallengeService _challengeService;
  final AuthService _authService;

  StreamSubscription<List<Reto>>? _suscripcion;

  List<Reto> _todos = [];

  FiltroRetos _filtro = FiltroRetos.activos;
  FiltroRetos get filtro => _filtro;

  bool _isLoading = false;
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

  List<Reto> get retos {
    final ahora = DateTime.now();
    switch (_filtro) {
      case FiltroRetos.activos:
        return _todos.where((reto) => reto.estaActivo(ahora)).toList();
      case FiltroRetos.mios:
        return _todos
            .where((reto) => reto.creadorUid == _authService.uid)
            .toList();
      case FiltroRetos.finalizados:
        // Los que terminaron hace menos tiempo, primero.
        return _todos
            .where((reto) => reto.fechaFin.isBefore(ahora))
            .toList()
            .reversed
            .toList();
    }
  }

  void iniciar() {
    _suscripcion?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _suscripcion = _challengeService.obtenerRetos().listen(
      (retos) {
        _todos = retos;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object error) {
        _isLoading = false;
        _errorMessage = error is InteraccionException
            ? error.message
            : 'No se pudieron cargar los retos.';
        notifyListeners();
      },
    );
  }

  void cambiarFiltro(FiltroRetos valor) {
    _filtro = valor;
    notifyListeners();
  }
}
