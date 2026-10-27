import 'package:flutter/material.dart';

import 'map_preview_view.dart';
import 'map_view.dart';

class MapHomeView extends StatelessWidget {
  const MapHomeView({super.key});

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
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search, color: Colors.blue),
                      hint: Text(
                        "Buscar un lugar o una ciudad",
                        style: TextStyle(color: Colors.blueGrey),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                  MapPreviewView(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
