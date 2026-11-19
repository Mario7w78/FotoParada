import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/foto_model.dart';
import '../models/reto_model.dart';
import '../services/auth_service.dart';
import '../services/challenge_service.dart';
import '../services/interaccion_exception.dart';
import '../services/photo_service.dart';

class ChallengeDetailViewModel extends ChangeNotifier {
  ChallengeDetailViewModel({
    required this.reto,
    ChallengeService? challengeService,
    PhotoService? photoService,
    AuthService? authService,
  })  : _challengeService = challengeService ?? ChallengeService(),
        _photoService = photoService ?? PhotoService(),
        _authService = authService ?? AuthService();

  final Reto reto;
  final ChallengeService _challengeService;
  final PhotoService _photoService;
  final AuthService _authService;

  StreamSubscription<List<ParticipacionReto>>? _suscripcion;

  String? get uid => _authService.uid;

  bool get esCreador => uid != null && reto.creadorUid == uid;

  List<ParticipacionReto> _participantes = [];
  List<ParticipacionReto> get participantes => _participantes;

  ParticipacionReto? get miParticipacion {
    for (final participacion in _participantes) {
      if (participacion.uid == uid) return participacion;
    }
    return null;
  }

  int get misFotosEnviadas => miParticipacion?.fotoIds.length ?? 0;

  double get progreso =>
      (misFotosEnviadas / reto.fotosObjetivo).clamp(0, 1).toDouble();

  bool get completado => misFotosEnviadas >= reto.fotosObjetivo;

  int get completaron =>
      _participantes.where((p) => p.completo(reto)).length;

  /// Fotos enviadas al reto ya descargadas, por id.
  final Map<String, Foto> _fotos = {};
  final Set<String> _pedidas = {};

  /// Fotos enviadas por todos, de la más reciente a la más antigua. Omite las
  /// que ya no existen o se volvieron privadas.
  List<Foto> get fotosEnviadas {
    final lista = _participantes
        .expand((participacion) => participacion.fotoIds)
        .map((id) => _fotos[id])
        .whereType<Foto>()
        .toList();
    lista.sort((a, b) => b.fechaSubida.compareTo(a.fechaSubida));
    return lista;
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _errorAccion;
  String? get errorAccion => _errorAccion;

  bool _isEnviando = false;
  bool get isEnviando => _isEnviando;

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

    _suscripcion = _challengeService.obtenerParticipantes(reto.id).listen(
      (participantes) {
        _participantes = participantes;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        _cargarFotos();
      },
      onError: (Object error) {
        _isLoading = false;
        _errorMessage = error is InteraccionException
            ? error.message
            : 'No se pudo cargar el reto.';
        notifyListeners();
      },
    );
  }

  Future<void> _cargarFotos() async {
    final faltantes = _participantes
        .expand((participacion) => participacion.fotoIds)
        .where(_pedidas.add)
        .toList();
    if (faltantes.isEmpty) return;

    await Future.wait(faltantes.map((id) async {
      try {
        final foto = await _photoService.obtenerPorId(id);
        if (foto != null) _fotos[id] = foto;
      } catch (_) {
        // Sin permiso (foto privada) o borrada: simplemente no se muestra.
      }
    }));
    notifyListeners();
  }

  /// Fotos propias para elegir cuál enviar, cada una con el motivo por el que
  /// no sirve (null si cumple las condiciones del reto).
  Future<List<({Foto foto, String? motivo})>> misFotosParaEnviar() async {
    final uidActual = uid;
    if (uidActual == null) return const [];

    final enviadas = miParticipacion?.fotoIds.toSet() ?? const <String>{};
    final mias = await _photoService.obtenerMisFotos(uidActual).first;
    return mias
        .where((foto) => !enviadas.contains(foto.id))
        .map((foto) => (foto: foto, motivo: reto.motivoNoCumple(foto)))
        .toList();
  }

  Future<bool> enviarFoto(Foto foto) async {
    final uidActual = uid;
    if (uidActual == null || _isEnviando) return false;

    _isEnviando = true;
    _errorAccion = null;
    notifyListeners();

    try {
      final nombre = _authService.displayName.trim();
      await _challengeService.enviarFoto(
        reto: reto,
        foto: foto,
        uid: uidActual,
        nombreUsuario: nombre.isEmpty ? 'Usuario' : nombre,
      );
      _fotos[foto.id] = foto;
      _pedidas.add(foto.id);
      return true;
    } on InteraccionException catch (e) {
      _errorAccion = e.message;
      return false;
    } catch (_) {
      _errorAccion = 'No se pudo enviar la foto. Intenta de nuevo.';
      return false;
    } finally {
      _isEnviando = false;
      notifyListeners();
    }
  }

  Future<bool> quitarFoto(Foto foto) async {
    final uidActual = uid;
    if (uidActual == null || foto.uid != uidActual) return false;
    _errorAccion = null;

    try {
      await _challengeService.quitarFoto(
        retoId: reto.id,
        uid: uidActual,
        fotoId: foto.id,
      );
      return true;
    } on InteraccionException catch (e) {
      _errorAccion = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> eliminarReto() async {
    if (!esCreador) return false;
    _errorAccion = null;
    try {
      await _challengeService.eliminarReto(reto.id);
      return true;
    } on InteraccionException catch (e) {
      _errorAccion = e.message;
      notifyListeners();
      return false;
    }
  }
}
