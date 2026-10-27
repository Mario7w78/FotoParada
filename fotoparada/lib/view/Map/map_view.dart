import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:fotoparada/viewmodel/map_viewmodel.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  static const LatLng _initialCenter = LatLng(0, 0);
  static const double _initialZoom = 13;

  final MapViewModel _viewModel = MapViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.fetchCurrentLocation();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ListenableBuilder(listenable: _viewModel, builder: (context, _){
        final pos = _viewModel.currentPosition;
        return FlutterMap(
          mapController: _viewModel.mapController,
          options: MapOptions(
            initialCenter: _initialCenter,
            initialZoom: _initialZoom,
            minZoom: 3,
            maxZoom: 18,
            onMapReady: _viewModel.onMapReady,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.fotoparada',
            ),
            const MarkerLayer(
              markers: [
                Marker(
                  point: _initialCenter,
                  width: 40,
                  height: 40,
                  child: Icon(Icons.location_on, color: Colors.blue, size: 40),
                ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [TextSourceAttribution('OpenStreetMap contributors')],
            ),
          ],
        );
      })
    );
  }
}


