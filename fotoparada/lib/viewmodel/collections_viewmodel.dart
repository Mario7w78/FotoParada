import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/coleccion_model.dart';
import '../services/auth_service.dart';
import '../services/coleccion_service.dart';
import '../services/recuerdos_exception.dart';

/// Integrante 4 - Lista de colecciones del usuario (pestaña "Guardado").
class CollectionsViewModel extends ChangeNotifier {
  CollectionsViewModel({
    ColeccionService? coleccionService,
    AuthService? authService,
  })  : _service = coleccionService ?? ColeccionService(),
        _authService = authService ?? AuthService();

  final ColeccionService _service;
  final AuthService _authService;

  StreamSubscription<List<Coleccion>>? _suscripcion;

  List<Coleccion> _colecciones = [];
  List<Coleccion> get colecciones => _colecciones;

  List<Coleccion> get predeterminadas =>
      _colecciones.where((c) => c.esPredeterminada).toList();

  List<Coleccion> get personalizadas =>
      _colecciones.where((c) => !c.esPredeterminada).toList();

  int get totalGuardados =>
      _colecciones.fold(0, (total, c) => total + c.cantidad);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Error de la última acción (crear, editar, eliminar).
  String? _errorAccion;
  String? get errorAccion => _errorAccion;

  bool _isGuardando = false;
  bool get isGuardando => _isGuardando;

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

  /// Escucha las colecciones y crea las predeterminadas si faltan. También
  /// sirve para reintentar después de un error.
  Future<void> iniciar() async {
    _suscripcion?.cancel();
    _suscripcion = null;

    final uid = _authService.uid;
    if (uid == null) {
      _isLoading = false;
      _errorMessage = 'Debes iniciar sesión para ver tus colecciones.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _suscripcion = _service.obtenerColecciones(uid).listen(
      (colecciones) {
        _colecciones = colecciones;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object error) {
        _isLoading = false;
        _errorMessage = RecuerdosException.mensajeDe(
          error,
          'No se pudieron cargar tus colecciones.',
        );
        notifyListeners();
      },
    );

    try {
      await _service.asegurarPredeterminadas(uid);
    } catch (error) {
      _errorMessage = RecuerdosException.mensajeDe(
        error,
        'No se pudieron preparar tus colecciones.',
      );
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Devuelve la colección creada o null si falló (motivo en [errorAccion]).
  Future<Coleccion?> crearColeccion(String nombre, String descripcion) async {
    final uid = _authService.uid;
    if (uid == null) {
      _errorAccion = 'Debes iniciar sesión.';
      notifyListeners();
      return null;
    }
    if (_nombreRepetido(nombre)) {
      _errorAccion = 'Ya tienes una colección con ese nombre.';
      notifyListeners();
      return null;
    }
    return _ejecutar(
      () => _service.crearColeccion(
        uid: uid,
        nombre: nombre,
        descripcion: descripcion,
      ),
    );
  }

  Future<bool> editarColeccion(
    Coleccion coleccion,
    String nombre,
    String descripcion,
  ) async {
    if (_nombreRepetido(nombre, excepto: coleccion.id)) {
      _errorAccion = 'Ya tienes una colección con ese nombre.';
      notifyListeners();
      return false;
    }
    final resultado = await _ejecutar(() async {
      await _service.editarColeccion(
        coleccion,
        nombre: nombre,
        descripcion: descripcion,
      );
      return true;
    });
    return resultado ?? false;
  }

  Future<bool> eliminarColeccion(Coleccion coleccion) async {
    final resultado = await _ejecutar(() async {
      await _service.eliminarColeccion(coleccion);
      return true;
    });
    return resultado ?? false;
  }

  bool _nombreRepetido(String nombre, {String? excepto}) {
    final buscado = nombre.trim().toLowerCase();
    return _colecciones.any(
      (c) => c.id != excepto && c.nombre.trim().toLowerCase() == buscado,
    );
  }

  Future<T?> _ejecutar<T>(Future<T> Function() accion) async {
    if (_isGuardando) return null;
    _isGuardando = true;
    _errorAccion = null;
    notifyListeners();
    try {
      return await accion();
    } catch (error) {
      _errorAccion = RecuerdosException.mensajeDe(
        error,
        'No se pudo completar la acción. Intenta de nuevo.',
      );
      return null;
    } finally {
      _isGuardando = false;
      notifyListeners();
    }
  }
}
