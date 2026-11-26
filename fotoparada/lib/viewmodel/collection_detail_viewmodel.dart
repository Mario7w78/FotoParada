import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/coleccion_model.dart';
import '../models/foto_model.dart';
import '../services/auth_service.dart';
import '../services/coleccion_service.dart';
import '../services/photo_service.dart';
import '../services/recuerdos_exception.dart';

/// Integrante 4 - Contenido de una colección: lugares y fotos guardados.
class CollectionDetailViewModel extends ChangeNotifier {
  CollectionDetailViewModel({
    required this._coleccion,
    ColeccionService? coleccionService,
    PhotoService? photoService,
    AuthService? authService,
  })  : _service = coleccionService ?? ColeccionService(),
        _photoService = photoService ?? PhotoService(),
        _authService = authService ?? AuthService();

  final ColeccionService _service;
  final PhotoService _photoService;
  final AuthService _authService;

  StreamSubscription<List<ElementoColeccion>>? _subElementos;
  StreamSubscription<List<Coleccion>>? _subColecciones;

  /// Se actualiza en vivo (nombre, contador) mientras la pantalla está abierta.
  Coleccion _coleccion;
  Coleccion get coleccion => _coleccion;

  /// Colección "Mis viajes" del usuario, destino de "Ya lo visité".
  Coleccion? _misViajes;

  /// Otras colecciones, para "Mover a...".
  List<Coleccion> _otras = [];
  List<Coleccion> get otrasColecciones => _otras;

  List<ElementoColeccion> _elementos = [];
  List<ElementoColeccion> get elementos => _elementos;

  List<ElementoColeccion> get lugares =>
      _elementos.where((e) => !e.esFoto).toList();

  List<ElementoColeccion> get fotos =>
      _elementos.where((e) => e.esFoto).toList();

  bool get puedeMarcarVisitado =>
      _coleccion.tipo == TipoColeccion.quieroVisitar && _misViajes != null;

  /// La colección fue eliminada desde otro lugar mientras se veía.
  bool _eliminada = false;
  bool get eliminada => _eliminada;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _errorAccion;
  String? get errorAccion => _errorAccion;

  final Set<String> _ocupados = {};
  bool estaOcupado(ElementoColeccion elemento) =>
      _ocupados.contains(elemento.id);

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _subElementos?.cancel();
    _subColecciones?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  void iniciar() {
    _subElementos?.cancel();
    _subColecciones?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subElementos = _service.obtenerElementos(_coleccion.id).listen(
      (elementos) {
        _elementos = elementos;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object error) {
        _isLoading = false;
        _errorMessage = RecuerdosException.mensajeDe(
          error,
          'No se pudo cargar la colección.',
        );
        notifyListeners();
      },
    );

    final uid = _authService.uid;
    if (uid == null) return;
    _subColecciones = _service.obtenerColecciones(uid).listen(
      (colecciones) {
        final actual = colecciones.where((c) => c.id == _coleccion.id);
        if (actual.isEmpty) {
          _eliminada = true;
        } else {
          _coleccion = actual.first;
        }
        _misViajes = colecciones
            .where((c) => c.tipo == TipoColeccion.misViajes)
            .firstOrNull;
        _otras = colecciones.where((c) => c.id != _coleccion.id).toList();
        notifyListeners();
      },
      // Si falla, la pantalla sigue funcionando sin "mover".
      onError: (Object _) {},
    );
  }

  /// Solo colecciones personalizadas.
  Future<bool> editarColeccion(String nombre, String descripcion) async {
    final repetido = _otras.any(
      (c) => c.nombre.trim().toLowerCase() == nombre.trim().toLowerCase(),
    );
    if (repetido) {
      _errorAccion = 'Ya tienes una colección con ese nombre.';
      notifyListeners();
      return false;
    }
    return _accionColeccion(
      () => _service.editarColeccion(
        _coleccion,
        nombre: nombre,
        descripcion: descripcion,
      ),
    );
  }

  /// Al eliminarse, [eliminada] pasa a true y la pantalla se cierra.
  Future<bool> eliminarColeccion() =>
      _accionColeccion(() => _service.eliminarColeccion(_coleccion));

  Future<bool> _accionColeccion(Future<void> Function() accion) async {
    _errorAccion = null;
    try {
      await accion();
      return true;
    } catch (error) {
      _errorAccion = RecuerdosException.mensajeDe(
        error,
        'No se pudo completar la acción. Intenta de nuevo.',
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> quitar(ElementoColeccion elemento) {
    return _sobre(
      elemento,
      () => _service.quitarElemento(_coleccion.id, elemento.id),
    );
  }

  /// Pasa un lugar de "Quiero visitar" a "Mis viajes".
  Future<bool> marcarVisitado(ElementoColeccion elemento) {
    final destino = _misViajes;
    if (destino == null) return Future.value(false);
    return moverA(elemento, destino);
  }

  Future<bool> moverA(ElementoColeccion elemento, Coleccion destino) {
    return _sobre(
      elemento,
      () => _service.moverElemento(
        elemento: elemento,
        origenId: _coleccion.id,
        destinoId: destino.id,
      ),
    );
  }

  Future<bool> guardarNota(ElementoColeccion elemento, String nota) {
    return _sobre(
      elemento,
      () => _service.actualizarNota(_coleccion.id, elemento.id, nota),
    );
  }

  /// Trae la foto original para abrir su detalle. Null si ya no existe o ya
  /// no es visible (por ejemplo, su dueño la volvió privada).
  Future<Foto?> abrirFoto(ElementoColeccion elemento) async {
    _errorAccion = null;
    try {
      final foto = await _photoService.obtenerPorId(elemento.fotoId);
      if (foto == null) {
        _errorAccion = 'Esta foto ya no existe. Puedes quitarla de la colección.';
      }
      return foto;
    } catch (_) {
      _errorAccion = 'Esta foto ya no está disponible para ti.';
      return null;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> _sobre(
    ElementoColeccion elemento,
    Future<void> Function() accion,
  ) async {
    if (!_ocupados.add(elemento.id)) return false;
    _errorAccion = null;
    notifyListeners();
    try {
      await accion();
      return true;
    } catch (error) {
      _errorAccion = RecuerdosException.mensajeDe(
        error,
        'No se pudo completar la acción. Intenta de nuevo.',
      );
      return false;
    } finally {
      _ocupados.remove(elemento.id);
      notifyListeners();
    }
  }
}
