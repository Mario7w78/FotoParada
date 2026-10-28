import 'package:flutter/material.dart';
import 'package:fotoparada/viewmodel/map_viewmodel.dart';
import 'package:latlong2/latlong.dart';
import '../../../models/geocoding_result.dart';

class LocationSearchBar extends StatefulWidget {
  const LocationSearchBar({super.key, required this.mapViewModel});

  final MapViewModel mapViewModel;

  @override
  State<LocationSearchBar> createState() => _LocationSearchBarState();
}

class _LocationSearchBarState extends State<LocationSearchBar> {
  @override
  Widget build(BuildContext context) {
    return Autocomplete<GeocodingResult>(
      displayStringForOption: (r) => r.displayName,
      optionsBuilder: (value) async {
        final q = value.text.trim();
        if (q.length < 3) return const Iterable<GeocodingResult>.empty();
        final results = await widget.mapViewModel.searchDebounced(q);
        return results ?? const Iterable<GeocodingResult>.empty();
      },
      onSelected: (r) {
        FocusScope.of(context).unfocus();
        widget.mapViewModel.moveTo(LatLng(r.latitude, r.longitude));
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          onSubmitted: (_) => onFieldSubmitted(),
          decoration: const InputDecoration(
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
        );
      },
    );
  }
}
