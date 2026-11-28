import 'dart:async';

import 'package:flutter/foundation.dart';

import '../Utils/cambios_optimistas.dart';
import '../models/comentario_model.dart';
import '../models/foto_model.dart';
import '../models/reaccion_model.dart';
import '../services/auth_service.dart';
import '../services/interaccion_exception.dart';
import '../services/interaction_service.dart';

class PhotoInteractionsViewModel extends ChangeNotifier {
  PhotoInteractionsViewModel({
    required this.foto,
    InteractionService? interactionService,
    AuthService? authService,
  })  : _interactionService = interactionService ?? InteractionService(),
        _authService = authService ?? AuthService();

  final Foto foto;
  final InteractionService _interactionService;
  final AuthService _authService;

  StreamSubscription<List<Comentario>>? _subComentarios;
  StreamSubscription<List<Reaccion>>? _subReacciones;

  String? get uid => _authService.uid;

  List<Comentario> _comentarios = [];

  /// Sin los que se están eliminando.
  List<Comentario> get comentarios => _eliminando.isEmpty
      ? _comentarios
      : _comentarios.where((c) => !_eliminando.contains(c.id)).toList();

  List<Reaccion> _reacciones = [];

  /// Mi reacción mientras se envía. La clave es mi uid.
  final CambiosOptimistas<String, TipoReaccion?> _miCambio =
      CambiosOptimistas();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Error al cargar: se muestra en lugar de los comentarios.
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Error de la última acción (comentar, reaccionar o eliminar).
  String? _errorAccion;
  String? get errorAccion => _errorAccion;

  final Set<String> _eliminando = {};

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _subComentarios?.cancel();
    _subReacciones?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  TipoReaccion? get _miReaccionEnServidor {
    for (final reaccion in _reacciones) {
      if (reaccion.uid == uid) return reaccion.tipo;
    }
    return null;
  }

  TipoReaccion? get miReaccion {
    final miUid = uid;
    if (miUid == null) return null;
    return _miCambio.valor(miUid, _miReaccionEnServidor);
  }

  int get totalReacciones =>
      _reacciones.where((r) => r.uid != uid).length +
      (miReaccion == null ? 0 : 1);

  int conteo(TipoReaccion tipo) =>
      _reacciones.where((r) => r.uid != uid && r.tipo == tipo).length +
      (miReaccion == tipo ? 1 : 0);

  /// Quita el cambio superpuesto cuando el servidor ya muestra lo mismo.
  void _conciliarReaccion() {
    final miUid = uid;
    if (miUid == null || _miCambio.enviando(miUid)) return;
    if (_miCambio.valor(miUid, _miReaccionEnServidor) ==
        _miReaccionEnServidor) {
      _miCambio.descartar(miUid);
    }
  }

  /// El autor del comentario y el dueño de la foto pueden borrarlo.
  bool puedeEliminar(Comentario comentario) =>
      uid != null && (comentario.uid == uid || foto.uid == uid);

  /// Empieza a escuchar comentarios y reacciones. También sirve para
  /// reintentar tras un error.
  void iniciar() {
    _subComentarios?.cancel();
    _subReacciones?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subComentarios =
        _interactionService.obtenerComentarios(foto.id).listen(
      (comentarios) {
        _comentarios = comentarios;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object error) {
        _isLoading = false;
        _errorMessage = _mensaje(error, 'No se pudieron cargar los comentarios.');
        notifyListeners();
      },
    );

    _subReacciones = _interactionService.obtenerReacciones(foto.id).listen(
      (reacciones) {
        _reacciones = reacciones;
        _conciliarReaccion();
        notifyListeners();
      },
      onError: (Object error) {
        _errorAccion =
            _mensaje(error, 'No se pudieron cargar las reacciones.');
        notifyListeners();
      },
    );
  }

  /// La reacción se ve al instante y se envía en segundo plano. Devuelve false
  /// si falló; en ese caso la pantalla vuelve a como estaba.
  Future<bool> reaccionar(TipoReaccion tipo) async {
    final uidActual = uid;
    if (uidActual == null) {
      _errorAccion = 'Debes iniciar sesión para reaccionar.';
      notifyListeners();
      return false;
    }

    final actual = miReaccion;
    _errorAccion = null;
    final envio = _miCambio.aplicar(
      clave: uidActual,
      nuevo: actual == tipo ? null : tipo,
      confirmado: actual,
      // El servicio alterna: repetir la reacción actual la quita.
      enviar: (desde, hacia) => _interactionService.reaccionar(
        fotoId: foto.id,
        uid: uidActual,
        tipo: hacia ?? desde!,
      ),
    );
    notifyListeners();

    try {
      await envio;
      return true;
    } catch (error) {
      _errorAccion = _mensaje(error, 'No se pudo guardar tu reacción.');
      return false;
    } finally {
      _conciliarReaccion();
      notifyListeners();
    }
  }

  /// Devuelve true si se publicó. No bloquea la pantalla: Firestore muestra el
  /// comentario en la lista antes de que el servidor responda.
  Future<bool> enviarComentario(String texto) async {
    final uidActual = uid;
    if (uidActual == null) {
      _errorAccion = 'Debes iniciar sesión para comentar.';
      notifyListeners();
      return false;
    }
    _errorAccion = null;

    try {
      final nombre = _authService.displayName.trim();
      await _interactionService.agregarComentario(
        fotoId: foto.id,
        uid: uidActual,
        nombreUsuario: nombre.isEmpty ? 'Usuario' : nombre,
        texto: texto,
      );
      return true;
    } catch (error) {
      _errorAccion = _mensaje(error, 'No se pudo publicar el comentario.');
      notifyListeners();
      return false;
    }
  }

  /// El comentario se oculta al instante y reaparece si el borrado falla.
  Future<bool> eliminarComentario(Comentario comentario) async {
    if (!puedeEliminar(comentario)) return false;
    if (!_eliminando.add(comentario.id)) return false;
    _errorAccion = null;
    notifyListeners();

    try {
      await _interactionService.eliminarComentario(foto.id, comentario.id);
      // Ya no existe, aunque la lista tarde en actualizarse.
      _comentarios =
          _comentarios.where((c) => c.id != comentario.id).toList();
      return true;
    } catch (error) {
      _errorAccion = _mensaje(error, 'No se pudo eliminar el comentario.');
      return false;
    } finally {
      _eliminando.remove(comentario.id);
      notifyListeners();
    }
  }

  String _mensaje(Object error, String porDefecto) =>
      error is InteraccionException ? error.message : porDefecto;
}
