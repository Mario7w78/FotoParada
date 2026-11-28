import 'dart:async';

import 'package:flutter/foundation.dart';

import '../Utils/cambios_optimistas.dart';
import '../models/coleccion_model.dart';
import '../models/foto_model.dart';
import '../repositories/foto_repository.dart';
import '../services/auth_service.dart';
import '../services/coleccion_service.dart';
import '../services/recuerdos_exception.dart';

/// Integrante 4 - Contenido de una colección: lugares y fotos guardados.
class CollectionDetailViewModel extends ChangeNotifier {
  CollectionDetailViewModel({
    required this._coleccion,
    ColeccionService? coleccionService,
    FotoRepository? fotoRepository,
    AuthService? authService,
  })  : _service = coleccionService ?? ColeccionService(),
        _fotoRepository = fotoRepository ?? FotoRepository(),
        _authService = authService ?? AuthService();

  final ColeccionService _service;
  final FotoRepository _fotoRepository;
  final AuthService _authService;

  StreamSubscription<List<ElementoColeccion>>? _subElementos;
  StreamSubscription<List<Coleccion>>? _subColecciones;

  /// Se actualiza en vivo (nombre, contador) mientras la pantalla está abierta.
  Coleccion _coleccion;

  /// El contador descuenta lo que se está quitando o moviendo.
  Coleccion get coleccion {
    final saliendo = _elementos.where((e) => _quitando.contains(e.id)).length;
    return saliendo == 0
        ? _coleccion
        : _coleccion.conCantidad(_coleccion.cantidad - saliendo);
  }

  /// Colección "Mis viajes" del usuario, destino de "Ya lo visité".
  Coleccion? _misViajes;

  /// Otras colecciones, para "Mover a...".
  List<Coleccion> _otras = [];
  List<Coleccion> get otrasColecciones => _otras;

  List<ElementoColeccion> _elementos = [];

  /// Lo que se muestra: sin lo que se está quitando y con las notas nuevas.
  List<ElementoColeccion> get elementos => [
        for (final e in _elementos)
          if (!_quitando.contains(e.id))
            _notas.pendiente(e.id) ? e.conNota(_notas.valor(e.id, e.nota)) : e,
      ];

  List<ElementoColeccion> get lugares =>
      elementos.where((e) => !e.esFoto).toList();

  List<ElementoColeccion> get fotos =>
      elementos.where((e) => e.esFoto).toList();

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

  /// Elementos que se están quitando o moviendo.
  final Set<String> _quitando = {};

  /// Notas que se están guardando, por id de elemento.
  final CambiosOptimistas<String, String> _notas = CambiosOptimistas();

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
    return _sacar(
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
    return _sacar(
      elemento,
      () => _service.moverElemento(
        elemento: elemento,
        origenId: _coleccion.id,
        destinoId: destino.id,
      ),
    );
  }

  /// La nota se ve al instante y vuelve a la anterior si falla.
  Future<bool> guardarNota(ElementoColeccion elemento, String nota) async {
    final id = elemento.id;
    final anterior = _elementos
            .where((e) => e.id == id)
            .map((e) => e.nota)
            .firstOrNull ??
        elemento.nota;
    _errorAccion = null;
    final envio = _notas.aplicar(
      clave: id,
      nuevo: nota.trim(),
      confirmado: _notas.valor(id, anterior),
      enviar: (_, nueva) async {
        await _service.actualizarNota(_coleccion.id, id, nueva);
        _elementos = [
          for (final e in _elementos) e.id == id ? e.conNota(nueva) : e,
        ];
      },
    );
    notifyListeners();

    try {
      await envio;
      return true;
    } catch (error) {
      _errorAccion = RecuerdosException.mensajeDe(
        error,
        'No se pudo completar la acción. Intenta de nuevo.',
      );
      return false;
    } finally {
      if (!_notas.enviando(id)) _notas.descartar(id);
      notifyListeners();
    }
  }

  /// Trae la foto original para abrir su detalle. Null si ya no existe o ya
  /// no es visible (por ejemplo, su dueño la volvió privada).
  Future<Foto?> abrirFoto(ElementoColeccion elemento) async {
    _errorAccion = null;
    try {
      final foto = await _fotoRepository.obtenerPorId(elemento.fotoId);
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

  /// Oculta [elemento] mientras [accion] lo saca de esta colección.
  Future<bool> _sacar(
    ElementoColeccion elemento,
    Future<void> Function() accion,
  ) async {
    if (!_quitando.add(elemento.id)) return false;
    _errorAccion = null;
    notifyListeners();
    try {
      await accion();
      // Si la lista aún no se actualizó, se descuenta aquí.
      if (_elementos.any((e) => e.id == elemento.id)) {
        _elementos = _elementos.where((e) => e.id != elemento.id).toList();
      }
      return true;
    } catch (error) {
      _errorAccion = RecuerdosException.mensajeDe(
        error,
        'No se pudo completar la acción. Intenta de nuevo.',
      );
      return false;
    } finally {
      _quitando.remove(elemento.id);
      notifyListeners();
    }
  }
}
