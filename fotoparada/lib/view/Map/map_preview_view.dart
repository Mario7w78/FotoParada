import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fotoparada/view/Map/map_view.dart';

class MapPreviewView extends StatefulWidget {
  const MapPreviewView({super.key});

  @override
  State<MapPreviewView> createState() => _MapPreviewViewState();
}

class _MapPreviewViewState extends State<MapPreviewView> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        print('!Widget presionado');
      },
      child: Expanded(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          height: 300,
          child: MapView(),
        ),
      ),
    );
  }
}
