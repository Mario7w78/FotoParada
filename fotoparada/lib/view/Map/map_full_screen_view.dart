import 'package:flutter/material.dart';
import 'package:fotoparada/view/Map/Components/location_search_bar.dart';
import 'package:fotoparada/view/Map/map_view.dart';
import 'package:fotoparada/viewmodel/map_viewmodel.dart';

import '../widgets/interaccion_widgets.dart';

class MapFullScreenView extends StatefulWidget {
  const MapFullScreenView({super.key, required this.mapViewModel});
  final MapViewModel mapViewModel;

  @override
  State<MapFullScreenView> createState() => _MapFullScreenViewState();
}

class _MapFullScreenViewState extends State<MapFullScreenView> {
  @override
  Widget build(BuildContext context) {
    // Sin AppBar: el título quedaba encima del mapa y no se leía. El botón
    // para volver va junto a la búsqueda, con fondo blanco.
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MapView(interactive: true, viewModel: widget.mapViewModel),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BotonIconoClaro(
                      icono: Icons.arrow_back,
                      tooltip: 'Volver',
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LocationSearchBar(
                        mapViewModel: widget.mapViewModel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
