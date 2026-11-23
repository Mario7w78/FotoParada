import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:fotoparada/viewmodel/map_viewmodel.dart';
import 'package:latlong2/latlong.dart';

import '../../models/foto_model.dart';
import '../../routes/app_routes.dart';
import '../widgets/foto_widgets.dart';
import '../widgets/interaccion_widgets.dart';

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
                  for (final punto in widget.viewModel.puntosInteres)
                    Marker(
                      point: punto.centro,
                      width: 44,
                      height: 44,
                      child: punto.cantidad == 1
                          ? _MarcadorFoto(foto: punto.fotos.first)
                          : _MarcadorGrupo(punto: punto),
                    ),
                  if (pos != null)
                    Marker(
                      point: LatLng(pos.latitude, pos.longitude),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () {
                          // TODO: Pasar el nombre real del lugar
                          Navigator.pushNamed(
                            context, 
                            '/location-detail', 
                            arguments: 'Ubicación actual'
                          );
                        },
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.blue,
                          size: 40,
                        ),
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

/// Marcador de una foto pública: un círculo azul con el ícono de su categoría.
/// Al tocarlo se abre la foto.
class _MarcadorFoto extends StatelessWidget {
  const _MarcadorFoto({required this.foto});

  final Foto foto;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.photoInteractions,
        arguments: foto,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.blue, width: 2),
        ),
        child: Icon(
          iconoCategoria(foto.categoria),
          color: Colors.blue,
          size: 18,
        ),
      ),
    );
  }
}

/// Marcador de varias fotos en el mismo lugar: muestra cuántas son y, al
/// tocarlo, abre la lista para elegir una.
class _MarcadorGrupo extends StatelessWidget {
  const _MarcadorGrupo({required this.punto});

  final PuntoInteres punto;

  void _abrirLista(BuildContext context) {
    final lugar = punto.fotos.first.nombreLugar;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (sheetContext, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                lugar.isEmpty
                    ? '${punto.cantidad} fotos en este lugar'
                    : '${punto.cantidad} fotos · $lugar',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            for (final foto in punto.fotos)
              ListTile(
                leading: SizedBox(
                  width: 56,
                  height: 56,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ImagenFoto(url: foto.urlMiniatura),
                  ),
                ),
                title: Text(
                  foto.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(etiquetaCategoria(foto.categoria)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.pushNamed(
                    context,
                    AppRoutes.photoInteractions,
                    arguments: foto,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _abrirLista(context),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const SizedBox.square(
              dimension: 36,
              child: Icon(Icons.photo_library, color: Colors.white, size: 18),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                '${punto.cantidad}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
