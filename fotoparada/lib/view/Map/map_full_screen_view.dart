import 'package:flutter/material.dart';
import 'package:fotoparada/view/Map/Components/location_search_bar.dart';
import 'package:fotoparada/view/Map/map_view.dart';
import 'package:fotoparada/viewmodel/map_viewmodel.dart';

class MapFullScreenView extends StatefulWidget {
  const MapFullScreenView({super.key, required this.mapViewModel});
  final MapViewModel mapViewModel;

  @override
  State<MapFullScreenView> createState() => _MapFullScreenViewState();
}

class _MapFullScreenViewState extends State<MapFullScreenView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Mapa", style: TextStyle(fontWeight: .bold),),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
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
                child: LocationSearchBar(mapViewModel: widget.mapViewModel),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
