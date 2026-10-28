import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fotoparada/routes/app_routes.dart';
import 'package:fotoparada/view/Map/map_view.dart';
import 'package:fotoparada/viewmodel/map_viewmodel.dart';

class MapPreviewView extends StatefulWidget {
  const MapPreviewView({super.key, required this.mapViewModel});
  final MapViewModel mapViewModel;

  @override
  State<MapPreviewView> createState() => _MapPreviewViewState();
}

class _MapPreviewViewState extends State<MapPreviewView> {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          debugPrint('MapPreview tapped');
          Navigator.pushNamed(
            context,
            AppRoutes.fullScreenMap,
            arguments: widget.mapViewModel,
          );
        },
        child: IgnorePointer(
          child:  SizedBox(
            height: 300,
            width: double.infinity,
            child: MapView(interactive: false, initialZoom: 15, viewModel: widget.mapViewModel,),
          ),
        )
      ),
    );
  }
}
