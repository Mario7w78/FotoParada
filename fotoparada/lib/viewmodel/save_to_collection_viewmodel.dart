import 'package:flutter/foundation.dart';

import '../models/coleccion_model.dart';
import '../services/auth_service.dart';
import '../services/coleccion_service.dart';
import '../services/recuerdos_exception.dart';

/// Integrante 4 - Hoja "Guardar en colección" para una foto o un lugar.
class SaveToCollectionViewModel extends ChangeNotifier {
  SaveToCollectionViewModel({
    required this.elemento,
    ColeccionService? coleccionService,
    AuthService? authService,
  })  : _service = coleccionService ?? ColeccionService(),
        _authService = authService ?? AuthService();

  final ElementoColeccion elemento;
  final ColeccionService _service;
  final AuthService _authService;

  List<Coleccion> _colecciones = [];
  List<Coleccion> get colecciones => _colecciones;

  /// Ids de las colecciones que ya tienen el elemento.
  Set<String> _marcadas = {};
  bool estaGuardadoEn(Coleccion coleccion) =>
      _marcadas.contains(coleccion.id);

  bool get guardadoEnAlguna => _marcadas.isNotEmpty;

  final Set<String> _ocupadas = {};
  bool estaOcupada(Coleccion coleccion) => _ocupadas.contains(coleccion.id);

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _errorAccion;
  String? get errorAccion => _errorAccion;

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

  Future<void> cargar() async {
    final uid = _authService.uid;
    if (uid == null) {
      _isLoading = false;
      _errorMessage = 'Debes iniciar sesión para guardar.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _service.asegurarPredeterminadas(uid);
      _colecciones = await _service.obtenerColecciones(uid).first;
      _marcadas = await _service.coleccionesQueContienen(
        _colecciones,
        elemento.id,
      );
    } catch (error) {
      _errorMessage = RecuerdosException.mensajeDe(
        error,
        'No se pudieron cargar tus colecciones.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Guarda o quita el elemento de [coleccion].
  Future<bool> alternar(Coleccion coleccion) async {
    if (!_ocupadas.add(coleccion.id)) return false;
    _errorAccion = null;
    notifyListeners();
    try {
      if (_marcadas.contains(coleccion.id)) {
        await _service.quitarElemento(coleccion.id, elemento.id);
        _marcadas = {..._marcadas}..remove(coleccion.id);
        _cambiarCantidad(coleccion.id, -1);
      } else {
        final agregado =
            await _service.agregarElemento(coleccion.id, elemento);
        _marcadas = {..._marcadas, coleccion.id};
        if (agregado) _cambiarCantidad(coleccion.id, 1);
      }
      return true;
    } catch (error) {
      _errorAccion = RecuerdosException.mensajeDe(
        error,
        'No se pudo guardar. Intenta de nuevo.',
      );
      return false;
    } finally {
      _ocupadas.remove(coleccion.id);
      notifyListeners();
    }
  }

  void _cambiarCantidad(String coleccionId, int diferencia) {
    _colecciones = [
      for (final c in _colecciones)
        c.id == coleccionId ? c.conCantidad(c.cantidad + diferencia) : c,
    ];
  }

  /// Crea una colección y guarda ahí el elemento.
  Future<bool> crearYGuardar(String nombre) async {
    final uid = _authService.uid;
    if (uid == null) return false;
    final repetido = _colecciones.any(
      (c) => c.nombre.trim().toLowerCase() == nombre.trim().toLowerCase(),
    );
    if (repetido) {
      _errorAccion = 'Ya tienes una colección con ese nombre.';
      notifyListeners();
      return false;
    }

    _errorAccion = null;
    try {
      final nueva = await _service.crearColeccion(uid: uid, nombre: nombre);
      _colecciones = [..._colecciones, nueva];
      notifyListeners();
      return await alternar(nueva);
    } catch (error) {
      _errorAccion = RecuerdosException.mensajeDe(
        error,
        'No se pudo crear la colección.',
      );
      notifyListeners();
      return false;
    }
  }
}
