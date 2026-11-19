import 'dart:async';

import 'package:flutter/foundation.dart';

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
  List<Comentario> get comentarios => _comentarios;

  List<Reaccion> _reacciones = [];

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Error al cargar: se muestra en lugar de los comentarios.
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Error de la última acción (comentar, reaccionar o eliminar).
  String? _errorAccion;
  String? get errorAccion => _errorAccion;

  bool _isEnviando = false;
  bool get isEnviando => _isEnviando;

  bool _isReaccionando = false;
  bool get isReaccionando => _isReaccionando;

  final Set<String> _eliminando = {};
  bool estaEliminando(Comentario comentario) =>
      _eliminando.contains(comentario.id);

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

  TipoReaccion? get miReaccion {
    for (final reaccion in _reacciones) {
      if (reaccion.uid == uid) return reaccion.tipo;
    }
    return null;
  }

  int get totalReacciones => _reacciones.length;

  int conteo(TipoReaccion tipo) =>
      _reacciones.where((reaccion) => reaccion.tipo == tipo).length;

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
        notifyListeners();
      },
      onError: (Object error) {
        _errorAccion =
            _mensaje(error, 'No se pudieron cargar las reacciones.');
        notifyListeners();
      },
    );
  }

  Future<bool> reaccionar(TipoReaccion tipo) async {
    final uidActual = uid;
    if (uidActual == null) {
      _errorAccion = 'Debes iniciar sesión para reaccionar.';
      notifyListeners();
      return false;
    }
    if (_isReaccionando) return false;

    _isReaccionando = true;
    _errorAccion = null;
    notifyListeners();

    try {
      await _interactionService.reaccionar(
        fotoId: foto.id,
        uid: uidActual,
        tipo: tipo,
      );
      return true;
    } catch (error) {
      _errorAccion = _mensaje(error, 'No se pudo guardar tu reacción.');
      return false;
    } finally {
      _isReaccionando = false;
      notifyListeners();
    }
  }

  /// Devuelve true si se publicó, para que la vista limpie el campo de texto.
  Future<bool> enviarComentario(String texto) async {
    final uidActual = uid;
    if (uidActual == null) {
      _errorAccion = 'Debes iniciar sesión para comentar.';
      notifyListeners();
      return false;
    }
    if (_isEnviando) return false;

    _isEnviando = true;
    _errorAccion = null;
    notifyListeners();

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
      return false;
    } finally {
      _isEnviando = false;
      notifyListeners();
    }
  }

  Future<bool> eliminarComentario(Comentario comentario) async {
    if (!puedeEliminar(comentario)) return false;
    if (!_eliminando.add(comentario.id)) return false;
    _errorAccion = null;
    notifyListeners();

    try {
      await _interactionService.eliminarComentario(foto.id, comentario.id);
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
