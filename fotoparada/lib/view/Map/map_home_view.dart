import 'package:flutter/material.dart';
import 'package:fotoparada/viewmodel/map_viewmodel.dart';

import 'Components/location_search_bar.dart';
import 'map_preview_view.dart';
import 'map_view.dart';

class MapHomeView extends StatefulWidget {
  const MapHomeView({super.key, required this.mapViewModel});
  final MapViewModel mapViewModel;

  @override
  State<MapHomeView> createState() => _MapHomeViewState();
}

class _MapHomeViewState extends State<MapHomeView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: .all(20),
          child: Column(
            children: [
              Column(
                crossAxisAlignment: .start,
                spacing: 12,
                children: [
                  Text(
                    "BUENOS DÍAS, MARIO",
                    style: TextStyle(color: Colors.blue, fontWeight: .bold),
                  ),
                  Text(
                    "¿Dónde hacemos las fotos hoy?",
                    style: TextStyle(fontWeight: .bold, fontSize: 24),
                  ),
                  LocationSearchBar(mapViewModel: widget.mapViewModel,),
                  MapPreviewView(mapViewModel: widget.mapViewModel,),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Descubre cerca de ti",
                        style: TextStyle(fontWeight: .bold, fontSize: 20),
                      ),
                      TextButton(onPressed: () {}, child: Text("Ver Todos")),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

