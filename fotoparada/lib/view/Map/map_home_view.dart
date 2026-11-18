import 'package:flutter/material.dart';
import 'package:fotoparada/viewmodel/map_viewmodel.dart';

import '../../services/auth_service.dart';
import 'Components/location_search_bar.dart';
import 'map_preview_view.dart';

class MapHomeView extends StatefulWidget {
  const MapHomeView({super.key, required this.mapViewModel});
  final MapViewModel mapViewModel;

  @override
  State<MapHomeView> createState() => _MapHomeViewState();
}

class _MapHomeViewState extends State<MapHomeView> {
  final AuthService _authService = AuthService();

  /// Saludo según la hora con el primer nombre del usuario que inició sesión.
  String _saludo() {
    final hora = DateTime.now().hour;
    final String saludo;
    if (hora < 12) {
      saludo = 'BUENOS DÍAS';
    } else if (hora < 19) {
      saludo = 'BUENAS TARDES';
    } else {
      saludo = 'BUENAS NOCHES';
    }

    final nombre = _authService.displayName.trim();
    if (nombre.isEmpty) return saludo;
    return '$saludo, ${nombre.split(' ').first.toUpperCase()}';
  }

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
                    _saludo(),
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

