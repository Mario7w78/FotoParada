import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:fotoparada/viewmodel/map_viewmodel.dart';
import 'package:latlong2/latlong.dart';

class MapView extends StatefulWidget {
  const MapView({
    super.key,
    this.interactive = true,
    this.initialCenter,
    this.initialZoom = 13,
    required this.viewModel,
  });

  final MapViewModel viewModel;
  final bool interactive;
  final LatLng? initialCenter;
  final double initialZoom;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  static const LatLng _initialCenter = LatLng(0, 0);
  static const double _focusZoom = 15;

  // Cada FlutterMap necesita su propio MapController; no se puede compartir.
  final MapController _mapController = MapController();
  bool _mapReady = false;
  LatLng? _lastCenter;

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onViewModelChanged);
    if (widget.viewModel.currentPosition == null) {
      widget.viewModel.fetchCurrentLocation();
    }
  }

  @override
  void dispose() {
    // El viewmodel es compartido: solo se quita el listener, no se libera.
    widget.viewModel.removeListener(_onViewModelChanged);
    _mapController.dispose();
    super.dispose();
  }

  void _onMapReady() {
    _mapReady = true;
    _onViewModelChanged();
  }

  void _onViewModelChanged() {
    final center = widget.viewModel.center;
    if (!_mapReady || center == null || center == _lastCenter) return;
    _lastCenter = center;
    _mapController.move(center, _focusZoom);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final pos = widget.viewModel.currentPosition;
          return FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  widget.initialCenter ??
                  widget.viewModel.center ??
                  _initialCenter,
              initialZoom: widget.initialZoom,
              minZoom: 3,
              maxZoom: 18,
              interactionOptions: InteractionOptions(
                flags: widget.interactive
                    ? InteractiveFlag.all
                    : InteractiveFlag.none,
              ),
              onMapReady: _onMapReady,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.fotoparada',
              ),
              MarkerLayer(
                markers: [
                  if (pos != null)
                    Marker(
                      point: LatLng(pos.latitude, pos.longitude),
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.location_on,
                        color: Colors.blue,
                        size: 40,
                      ),
                    ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
