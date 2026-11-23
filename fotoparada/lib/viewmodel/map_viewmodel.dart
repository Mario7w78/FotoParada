import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../Utils/debounce.dart';
import '../models/foto_model.dart';
import '../models/geocoding_result.dart';
import '../services/geocoding_service.dart';
import '../services/photo_service.dart';

/// Fotos tomadas en el mismo lugar, que el mapa dibuja como un solo marcador.
class PuntoInteres {
  const PuntoInteres({required this.centro, required this.fotos});

  final LatLng centro;
  final List<Foto> fotos;

  int get cantidad => fotos.length;
}

class MapViewModel extends ChangeNotifier {
  MapViewModel({PhotoService? photoService})
    : _photoService = photoService ?? PhotoService() {
    _escucharFotos();
  }

  final PhotoService _photoService;
  StreamSubscription<List<Foto>>? _suscripcion;

  List<Foto> _fotos = [];
  String? _errorFotos;

  /// null muestra todas las categorías.
  CategoriaFoto? _categoria;
  CategoriaFoto? get categoria => _categoria;

  /// Fotos públicas que se dibujan como marcadores en el mapa.
  List<Foto> get fotos => _fotos;
  String? get errorFotos => _errorFotos;

  /// Las fotos a menos de esta distancia de la primera de un punto se
  /// agrupan en él.
  static const double radioAgrupacionMetros = 100;

  /// Fotos agrupadas por lugar, para mostrar cuántas hay en cada punto.
  List<PuntoInteres> get puntosInteres {
    const medidor = Distance();
    final centros = <LatLng>[];
    final grupos = <List<Foto>>[];

    for (final foto in _fotos) {
      final punto = LatLng(foto.latitud, foto.longitud);
      final indice = centros.indexWhere(
        (centro) =>
            medidor.as(LengthUnit.Meter, centro, punto) <=
            radioAgrupacionMetros,
      );
      if (indice == -1) {
        centros.add(punto);
        grupos.add([foto]);
      } else {
        grupos[indice].add(foto);
      }
    }

    return [
      for (var i = 0; i < centros.length; i++)
        PuntoInteres(centro: centros[i], fotos: grupos[i]),
    ];
  }

  /// Distancia máxima a la que una foto se considera "cerca de ti".
  static const double radioExploracionMetros = 5000;

  /// Fotos a menos de [radioExploracionMetros] de la posición actual, de la
  /// más cercana a la más lejana. Vacía mientras no se conozca la posición.
  List<({Foto foto, double distancia})> get fotosCercanas {
    final pos = _currentPosition;
    if (pos == null) return const [];

    const medidor = Distance();
    final origen = LatLng(pos.latitude, pos.longitude);
    final cercanas = <({Foto foto, double distancia})>[];
    for (final foto in _fotos) {
      final distancia = medidor.as(
        LengthUnit.Meter,
        origen,
        LatLng(foto.latitud, foto.longitud),
      );
      if (distancia <= radioExploracionMetros) {
        cercanas.add((foto: foto, distancia: distancia));
      }
    }
    cercanas.sort((a, b) => a.distancia.compareTo(b.distancia));
    return cercanas;
  }

  void cambiarCategoria(CategoriaFoto? valor) {
    if (_categoria == valor) return;
    _categoria = valor;
    _fotos = [];
    _escucharFotos();
    notifyListeners();
  }

  void _escucharFotos() {
    _suscripcion?.cancel();
    _errorFotos = null;
    final consulta = _categoria == null
        ? _photoService.obtenerFotosPublicas()
        : _photoService.obtenerFotosPublicasPorCategoria(_categoria!);

    _suscripcion = consulta.listen(
      (fotos) {
        _fotos = fotos;
        _errorFotos = null;
        notifyListeners();
      },
      onError: (Object error) {
        _errorFotos = error is PhotoException
            ? error.message
            : 'No se pudieron cargar las fotos del mapa.';
        notifyListeners();
      },
    );
  }

  final GeocodingService _geocodingService = GeocodingService();
  late final _debouncedSearch = debounce(_geocodingService.search);

  List<GeocodingResult> _searchResults = [];

  Position? _currentPosition;
  LatLng? _center;

  bool _isLoading = false;
  bool _isSearching = false;

  String? _searchError;
  String? _errorMessage;

  Position? get currentPosition => _currentPosition;
  // Punto en el que deben centrarse los mapas que usan este viewmodel.
  LatLng? get center => _center;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get errorMessage => _errorMessage;

  void moveTo(LatLng point) {
    _center = point;
    notifyListeners();
  }

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

  Future<void> searchPlaces(String query) async {
    _isSearching = true;
    _searchError = null;
    _searchResults = [];
    notifyListeners();

    try {
      _searchResults = await _geocodingService.search(query);
    } catch (e) {
      _searchError = e.toString();
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<void> fetchCurrentLocation() async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final pos = await _determinePosition();
      _currentPosition = pos;
      _center = LatLng(pos.latitude, pos.longitude);
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return throw Exception('Location services are disabled');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return throw Exception('Locations permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return throw Exception(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<Iterable<GeocodingResult>?> searchDebounced(String query) async {
    if (query.trim().length < 3) {
      _searchResults = [];
      notifyListeners();
      return const [];
    }

    _isSearching = true;
    _searchError = null;
    notifyListeners();

    try {
      final results = await _debouncedSearch(query);
      _searchResults = results?.toList() ?? [];
      return _searchResults;
    } catch (e) {
      _searchError = e.toString();
      debugPrint('Error en la búsqueda: $_searchError');
      return const [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }
}
