import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../Utils/debounce.dart';
import '../models/geocoding_result.dart';
import '../services/geocoding_service.dart';

class MapViewModel extends ChangeNotifier {
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
  String? get errorMessage => _errorMessage;

  void moveTo(LatLng point) {
    _center = point;
    notifyListeners();
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
