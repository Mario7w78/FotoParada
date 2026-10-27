import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class MapViewModel extends ChangeNotifier {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  bool _isLoading = false;
  String? _errorMessage;

  MapController get mapController => _mapController;
  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool _mapReady = false;

  void onMapReady() {
    _mapReady = true;
    _moveToCurrentPosition();
  }

  Future<void> fetchCurrentLocation() async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentPosition = await _determinePosition();
      _moveToCurrentPosition();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _moveToCurrentPosition() {
    final pos = _currentPosition;
    if (!_mapReady || pos == null) return;
    try {
      _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
    } catch (_) {

    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled){
      return throw Exception('Location services are disabled');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied){
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied){
        return throw Exception('Locations permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return throw Exception(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }
}