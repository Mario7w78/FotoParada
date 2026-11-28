import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/foto_model.dart';
import '../models/reto_model.dart';
import '../repositories/foto_repository.dart';
import '../services/auth_service.dart';
import '../services/challenge_service.dart';
import '../services/interaccion_exception.dart';

class ChallengeDetailViewModel extends ChangeNotifier {
  ChallengeDetailViewModel({
    required this.reto,
    ChallengeService? challengeService,
    FotoRepository? fotoRepository,
    AuthService? authService,
  })  : _challengeService = challengeService ?? ChallengeService(),
        _fotoRepository = fotoRepository ?? FotoRepository(),
        _authService = authService ?? AuthService();

  final Reto reto;
  final ChallengeService _challengeService;
  final FotoRepository _fotoRepository;
  final AuthService _authService;

  StreamSubscription<List<ParticipacionReto>>? _suscripcion;

  String? get uid => _authService.uid;

  bool get esCreador => uid != null && reto.creadorUid == uid;

  List<ParticipacionReto> _participantes = [];

  /// Mis fotos en camino: true si se está enviando, false si se está retirando.
  final Map<String, bool> _enCamino = {};

  /// Los del servidor, con mis cambios en camino ya aplicados.
  List<ParticipacionReto> get participantes => _conCambios(_enCamino);

  /// Los participantes con [cambios] aplicados a mi participación.
  List<ParticipacionReto> _conCambios(Map<String, bool> cambios) {
    final miUid = uid;
    if (miUid == null || cambios.isEmpty) return _participantes;

    final mia = _participantes.where((p) => p.uid == miUid).firstOrNull;
    final ids = [
      for (final id in mia?.fotoIds ?? const <String>[])
        if (cambios[id] != false) id,
    ];
    for (final cambio in cambios.entries) {
      if (cambio.value && !ids.contains(cambio.key)) ids.add(cambio.key);
    }
    final nombre = _authService.displayName.trim();
    final ajustada = ParticipacionReto(
      uid: miUid,
      nombreUsuario:
          mia?.nombreUsuario ?? (nombre.isEmpty ? 'Usuario' : nombre),
      fotoIds: ids,
      fechaActualizacion: mia?.fechaActualizacion ?? DateTime.now(),
    );
    return [
      for (final p in _participantes) p.uid == miUid ? ajustada : p,
      if (mia == null && ids.isNotEmpty) ajustada,
    ];
  }

  ParticipacionReto? get miParticipacion {
    for (final participacion in participantes) {
      if (participacion.uid == uid) return participacion;
    }
    return null;
  }

  int get misFotosEnviadas => miParticipacion?.fotoIds.length ?? 0;

  double get progreso =>
      (misFotosEnviadas / reto.fotosObjetivo).clamp(0, 1).toDouble();

  bool get completado => misFotosEnviadas >= reto.fotosObjetivo;

  int get completaron =>
      participantes.where((p) => p.completo(reto)).length;

  /// Fotos enviadas al reto ya descargadas, por id.
  final Map<String, Foto> _fotos = {};
  final Set<String> _pedidas = {};

  /// Fotos enviadas por todos, de la más reciente a la más antigua. Omite las
  /// que ya no existen o se volvieron privadas.
  List<Foto> get fotosEnviadas {
    final lista = participantes
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
        final foto = await _fotoRepository.obtenerPorId(id);
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
    final mias = await _fotoRepository.obtenerMisFotos(uidActual).first;
    return mias
        .where((foto) => !enviadas.contains(foto.id))
        .map((foto) => (foto: foto, motivo: reto.motivoNoCumple(foto)))
        .toList();
  }

  /// La foto cuenta en el progreso al instante y se descuenta si falla.
  Future<bool> enviarFoto(Foto foto) async {
    final uidActual = uid;
    if (uidActual == null || _enCamino.containsKey(foto.id)) return false;

    final yaDescargada = _fotos.containsKey(foto.id);
    _fotos[foto.id] = foto;
    _pedidas.add(foto.id);
    return _cambiarFoto(
      foto,
      enviar: true,
      porDefecto: 'No se pudo enviar la foto. Intenta de nuevo.',
      accion: () {
        final nombre = _authService.displayName.trim();
        return _challengeService.enviarFoto(
          reto: reto,
          foto: foto,
          uid: uidActual,
          nombreUsuario: nombre.isEmpty ? 'Usuario' : nombre,
        );
      },
      alFallar: () {
        if (yaDescargada) return;
        _fotos.remove(foto.id);
        _pedidas.remove(foto.id);
      },
    );
  }

  Future<bool> quitarFoto(Foto foto) async {
    final uidActual = uid;
    if (uidActual == null || foto.uid != uidActual) return false;
    if (_enCamino.containsKey(foto.id)) return false;

    return _cambiarFoto(
      foto,
      enviar: false,
      porDefecto: 'No se pudo quitar la foto.',
      accion: () => _challengeService.quitarFoto(
        retoId: reto.id,
        uid: uidActual,
        fotoId: foto.id,
      ),
    );
  }

  Future<bool> _cambiarFoto(
    Foto foto, {
    required bool enviar,
    required String porDefecto,
    required Future<void> Function() accion,
    void Function()? alFallar,
  }) async {
    _errorAccion = null;
    _enCamino[foto.id] = enviar;
    notifyListeners();

    try {
      await accion();
      // La lista local queda como la del servidor aunque aún no haya llegado.
      _participantes = _conCambios({foto.id: enviar});
      return true;
    } catch (error) {
      _errorAccion =
          error is InteraccionException ? error.message : porDefecto;
      alFallar?.call();
      return false;
    } finally {
      _enCamino.remove(foto.id);
      notifyListeners();
    }
  }

  Future<bool> eliminarReto() async {
    if (!esCreador) return false;
    _errorAccion = null;
    try {
      await _challengeService.eliminarReto(reto.id);
      return true;
    } catch (error) {
      _errorAccion = error is InteraccionException
          ? error.message
          : 'No se pudo eliminar el reto.';
      notifyListeners();
      return false;
    }
  }
}
