import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'interaccion_widgets.dart';

/// Mapa pequeño, sin gestos, centrado en [punto]. Si se pasa [radioMetros]
/// dibuja el área alrededor del punto (zona válida del check-in o del reto).
class MapaPunto extends StatelessWidget {
  const MapaPunto({
    super.key,
    required this.punto,
    this.radioMetros,
    this.altura = 180,
    this.zoom = 16,
  });

  final LatLng punto;
  final double? radioMetros;
  final double altura;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: altura,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: punto,
            initialZoom: zoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.fotoparada',
            ),
            if (radioMetros != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: punto,
                    radius: radioMetros!,
                    useRadiusInMeter: true,
                    color: ColoresFotoParada.azul.withValues(alpha: 0.15),
                    borderColor: ColoresFotoParada.azul,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: punto,
                  width: 44,
                  height: 44,
                  alignment: Alignment.topCenter,
                  child: const Icon(
                    Icons.location_on,
                    color: ColoresFotoParada.azul,
                    size: 44,
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
        ),
      ),
    );
  }
}
