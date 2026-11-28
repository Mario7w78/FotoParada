import 'package:flutter/foundation.dart';

import '../Utils/cambios_optimistas.dart';
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

  /// Con el contador ya ajustado a los cambios en camino.
  List<Coleccion> get colecciones => [
        for (final c in _colecciones)
          estaGuardadoEn(c) == _marcadas.contains(c.id)
              ? c
              : c.conCantidad(c.cantidad + (estaGuardadoEn(c) ? 1 : -1)),
      ];

  /// Ids de las colecciones que según el servidor tienen el elemento.
  Set<String> _marcadas = {};

  /// Casillas tocadas que se están enviando, por id de colección.
  final CambiosOptimistas<String, bool> _cambios = CambiosOptimistas();

  bool estaGuardadoEn(Coleccion coleccion) =>
      _cambios.valor(coleccion.id, _marcadas.contains(coleccion.id));

  bool get guardadoEnAlguna => _colecciones.any(estaGuardadoEn);

  /// Colecciones nuevas que el servidor aún está creando.
  final Map<String, Future<void>> _creando = {};

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

  /// Guarda o quita el elemento de [coleccion]. La casilla cambia al instante y
  /// vuelve atrás si el servidor falla.
  Future<bool> alternar(Coleccion coleccion) async {
    final id = coleccion.id;
    _errorAccion = null;
    final envio = _cambios.aplicar(
      clave: id,
      nuevo: !estaGuardadoEn(coleccion),
      confirmado: _marcadas.contains(id),
      enviar: (_, guardar) async {
        // Una colección recién creada debe existir antes de guardar en ella.
        final creacion = _creando[id];
        if (creacion != null) await creacion;
        if (guardar) {
          final agregado = await _service.agregarElemento(id, elemento);
          _marcadas = {..._marcadas, id};
          if (agregado) _cambiarCantidad(id, 1);
        } else {
          await _service.quitarElemento(id, elemento.id);
          _marcadas = {..._marcadas}..remove(id);
          _cambiarCantidad(id, -1);
        }
      },
    );
    notifyListeners();

    try {
      await envio;
      return true;
    } catch (error) {
      _errorAccion = RecuerdosException.mensajeDe(
        error,
        'No se pudo guardar. Intenta de nuevo.',
      );
      return false;
    } finally {
      if (!_cambios.enviando(id)) _cambios.descartar(id);
      notifyListeners();
    }
  }

  void _cambiarCantidad(String coleccionId, int diferencia) {
    _colecciones = [
      for (final c in _colecciones)
        c.id == coleccionId ? c.conCantidad(c.cantidad + diferencia) : c,
    ];
  }

  /// Crea una colección y guarda ahí el elemento. Aparece marcada al instante.
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
    final Coleccion nueva;
    try {
      nueva = _service.prepararColeccion(uid: uid, nombre: nombre);
    } catch (error) {
      _errorAccion = RecuerdosException.mensajeDe(
        error,
        'No se pudo crear la colección.',
      );
      notifyListeners();
      return false;
    }

    _colecciones = [..._colecciones, nueva];
    final creacion = _service.guardarColeccion(nueva);
    _creando[nueva.id] = creacion;
    final marcado = alternar(nueva);

    try {
      await creacion;
    } catch (error) {
      await marcado;
      _colecciones = _colecciones.where((c) => c.id != nueva.id).toList();
      _errorAccion = RecuerdosException.mensajeDe(
        error,
        'No se pudo crear la colección.',
      );
      notifyListeners();
      return false;
    } finally {
      _creando.remove(nueva.id);
    }
    return marcado;
  }
}
