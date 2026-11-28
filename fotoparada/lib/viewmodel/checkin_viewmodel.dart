import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/checkin_model.dart';
import '../services/auth_service.dart';
import '../services/checkin_service.dart';
import '../services/foto_metadata_service.dart';
import '../services/interaccion_exception.dart';

enum EstadoCheckIn { pendiente, verificando, fueraDeRango, validado }

class CheckInViewModel extends ChangeNotifier {
  CheckInViewModel({
    this.lugar,
    CheckInService? checkInService,
    AuthService? authService,
  })  : _checkInService = checkInService ?? CheckInService(),
        _authService = authService ?? AuthService();

  /// Lugar a validar. Si es nulo la vista solo muestra el historial.
  final LugarCheckIn? lugar;
  final CheckInService _checkInService;
  final AuthService _authService;

  StreamSubscription<List<CheckIn>>? _suscripcion;

  EstadoCheckIn _estado = EstadoCheckIn.pendiente;
  EstadoCheckIn get estado => _estado;

  /// Distancia al lugar en la última verificación.
  double? _distanciaMetros;
  double? get distanciaMetros => _distanciaMetros;

  double get radioMetros => CheckInService.radioValidacionMetros;

  List<CheckIn> _historial = [];
  List<CheckIn> get historial => _historial;

  bool _isLoadingHistorial = false;
  bool get isLoadingHistorial => _isLoadingHistorial;

  String? _errorHistorial;
  String? get errorHistorial => _errorHistorial;

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

  /// Ya hizo check-in hoy en este mismo lugar: no hace falta repetirlo.
  bool get yaHizoCheckInHoy {
    final destino = lugar;
    if (destino == null) return false;
    final hoy = DateTime.now();

    return _historial.any((checkIn) {
      final mismoDia = checkIn.fecha.year == hoy.year &&
          checkIn.fecha.month == hoy.month &&
          checkIn.fecha.day == hoy.day;
      if (!mismoDia) return false;
      final distancia = _checkInService.distanciaMetros(
        LatLng(checkIn.latitud, checkIn.longitud),
        LatLng(destino.latitud, destino.longitud),
      );
      return _checkInService.estaDentroDelRadio(distancia);
    });
  }

  void iniciar() {
    _suscripcion?.cancel();
    final uid = _authService.uid;
    if (uid == null) {
      _errorHistorial = 'Debes iniciar sesión para ver tus check-ins.';
      notifyListeners();
      return;
    }

    _isLoadingHistorial = true;
    _errorHistorial = null;
    notifyListeners();

    _suscripcion = _checkInService.obtenerMisCheckIns(uid).listen(
      (lista) {
        _historial = lista;
        _isLoadingHistorial = false;
        _errorHistorial = null;
        if (_estado == EstadoCheckIn.pendiente && yaHizoCheckInHoy) {
          _estado = EstadoCheckIn.validado;
        }
        notifyListeners();
      },
      onError: (Object error) {
        _isLoadingHistorial = false;
        _errorHistorial = error is InteraccionException
            ? error.message
            : 'No se pudo cargar tu historial.';
        notifyListeners();
      },
    );
  }

  /// Obtiene el GPS, mide la distancia al lugar y, si está dentro del radio,
  /// registra el check-in. Devuelve true si quedó validado.
  Future<bool> hacerCheckIn() async {
    final destino = lugar;
    final uid = _authService.uid;
    if (destino == null || _estado == EstadoCheckIn.verificando) return false;
    if (uid == null) {
      _errorMessage = 'Debes iniciar sesión para hacer check-in.';
      notifyListeners();
      return false;
    }

    _estado = EstadoCheckIn.verificando;
    _errorMessage = null;
    notifyListeners();

    try {
      final posicion = await _checkInService.ubicacionActual();
      final distancia = _checkInService.distanciaMetros(
        posicion,
        LatLng(destino.latitud, destino.longitud),
      );
      _distanciaMetros = distancia;

      if (!_checkInService.estaDentroDelRadio(distancia)) {
        _estado = EstadoCheckIn.fueraDeRango;
        return false;
      }

      // Ya se comprobó la distancia: se muestra validado mientras se registra.
      // Si el registro falla, los catch de abajo lo deshacen.
      _estado = EstadoCheckIn.validado;
      notifyListeners();
      await _checkInService.registrar(
        uid: uid,
        lugar: destino,
        distanciaMetros: distancia,
      );
      return true;
    } on UbicacionException catch (e) {
      _estado = EstadoCheckIn.pendiente;
      _errorMessage = e.message;
      return false;
    } on InteraccionException catch (e) {
      _estado = EstadoCheckIn.pendiente;
      _errorMessage = e.message;
      return false;
    } catch (_) {
      _estado = EstadoCheckIn.pendiente;
      _errorMessage = 'No se pudo validar tu ubicación. Intenta de nuevo.';
      return false;
    } finally {
      notifyListeners();
    }
  }
}
