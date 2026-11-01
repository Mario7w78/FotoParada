import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../models/foto_model.dart';
import 'foto_widgets.dart';

/// Campos de una foto, compartidos por las pantallas de subir y editar.
class FormularioFoto extends StatelessWidget {
  const FormularioFoto({
    super.key,
    required this.tituloController,
    required this.descripcionController,
    required this.onTituloChanged,
    required this.onDescripcionChanged,
    required this.categoria,
    required this.onCategoriaChanged,
    required this.privacidad,
    required this.onPrivacidadChanged,
    required this.punto,
    required this.centrarMapa,
    required this.onMapaTap,
    required this.onDedoSobreMapa,
    required this.isLoadingUbicacion,
    required this.nombreLugar,
    required this.fecha,
    this.origenUbicacion,
    this.accionUbicacion,
    this.onFechaTap,
  });

  final TextEditingController tituloController;
  final TextEditingController descripcionController;
  final ValueChanged<String> onTituloChanged;
  final ValueChanged<String> onDescripcionChanged;
  final CategoriaFoto categoria;
  final ValueChanged<CategoriaFoto> onCategoriaChanged;
  final PrivacidadFoto privacidad;
  final ValueChanged<PrivacidadFoto> onPrivacidadChanged;
  final LatLng? punto;

  /// Si es true, el mapa se mueve hasta [punto] cuando este cambia. Debe ser
  /// false cuando el usuario eligió el punto: ya lo está mirando.
  final bool centrarMapa;
  final ValueChanged<LatLng> onMapaTap;

  /// Permite a la pantalla desactivar su scroll mientras se usa el mapa.
  final ValueChanged<bool> onDedoSobreMapa;
  final bool isLoadingUbicacion;
  final String nombreLugar;
  final DateTime? fecha;
  final String? origenUbicacion;
  final Widget? accionUbicacion;

  /// Si es null, la fecha no se puede cambiar.
  final VoidCallback? onFechaTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: tituloController,
          textCapitalization: TextCapitalization.sentences,
          onChanged: onTituloChanged,
          decoration: const InputDecoration(
            labelText: 'Título',
            prefixIcon: Icon(Icons.title),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: descripcionController,
          textCapitalization: TextCapitalization.sentences,
          onChanged: onDescripcionChanged,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Descripción',
            prefixIcon: Icon(Icons.notes),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        const _TituloSeccion('Categoría'),
        Wrap(
          spacing: 8,
          children: [
            for (final opcion in CategoriaFoto.values)
              ChoiceChip(
                label: Text(
                  '${opcion.name[0].toUpperCase()}${opcion.name.substring(1)}',
                ),
                selected: categoria == opcion,
                onSelected: (_) => onCategoriaChanged(opcion),
              ),
          ],
        ),
        const SizedBox(height: 24),
        const _TituloSeccion('Privacidad'),
        SegmentedButton<PrivacidadFoto>(
          showSelectedIcon: false,
          segments: [
            for (final opcion in PrivacidadFoto.values)
              ButtonSegment(
                value: opcion,
                icon: Icon(iconoPrivacidad(opcion)),
                label: Text(etiquetaPrivacidad(opcion)),
              ),
          ],
          selected: {privacidad},
          onSelectionChanged: (seleccion) =>
              onPrivacidadChanged(seleccion.first),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(child: _TituloSeccion('Ubicación')),
            ?accionUbicacion,
          ],
        ),
        _MiniMapa(
          punto: punto,
          centrar: centrarMapa,
          onTap: onMapaTap,
          onDedoSobreMapa: onDedoSobreMapa,
        ),
        const SizedBox(height: 8),
        _construirDatosUbicacion(),
        const SizedBox(height: 16),
        _construirFecha(),
      ],
    );
  }

  Widget _construirDatosUbicacion() {
    final String lugar;
    if (isLoadingUbicacion) {
      lugar = 'Obteniendo ubicación...';
    } else if (punto == null) {
      lugar = 'Toca el mapa para elegir el lugar';
    } else if (nombreLugar.isNotEmpty) {
      lugar = nombreLugar;
    } else {
      lugar =
          '${punto!.latitude.toStringAsFixed(5)}, ${punto!.longitude.toStringAsFixed(5)}';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.place, color: Colors.blue),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lugar, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (origenUbicacion != null)
                Text(
                  origenUbicacion!,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _construirFecha() {
    return InkWell(
      onTap: onFechaTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.event, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                fecha == null
                    ? 'Fecha de la foto: sin definir'
                    : 'Fecha de la foto: ${DateFormat('dd/MM/yyyy HH:mm').format(fecha!)}',
              ),
            ),
            if (onFechaTap != null)
              const Icon(Icons.edit, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _MiniMapa extends StatefulWidget {
  const _MiniMapa({
    required this.punto,
    required this.centrar,
    required this.onTap,
    required this.onDedoSobreMapa,
  });

  final LatLng? punto;
  final bool centrar;
  final ValueChanged<LatLng> onTap;
  final ValueChanged<bool> onDedoSobreMapa;

  @override
  State<_MiniMapa> createState() => _MiniMapaState();
}

class _MiniMapaState extends State<_MiniMapa> {
  static const double _zoomEnfocado = 15;

  final _mapController = MapController();
  bool _mapaListo = false;
  late LatLng? _ultimoPunto = widget.punto;

  @override
  void didUpdateWidget(_MiniMapa oldWidget) {
    super.didUpdateWidget(oldWidget);
    _centrar();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _centrar() {
    final punto = widget.punto;
    if (!_mapaListo || punto == null || punto == _ultimoPunto) return;
    _ultimoPunto = punto;
    if (!widget.centrar) return;

    // Mover el mapa redibuja FlutterMap, y eso no se puede hacer durante build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mapController.move(punto, _zoomEnfocado);
    });
  }

  @override
  Widget build(BuildContext context) {
    final punto = widget.punto;
    return Listener(
      onPointerDown: (_) => widget.onDedoSobreMapa(true),
      onPointerUp: (_) => widget.onDedoSobreMapa(false),
      onPointerCancel: (_) => widget.onDedoSobreMapa(false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 220,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _ultimoPunto ?? const LatLng(0, 0),
              initialZoom: _ultimoPunto == null ? 2 : _zoomEnfocado,
              minZoom: 2,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onMapReady: () {
                _mapaListo = true;
                _centrar();
              },
              onTap: (_, punto) => widget.onTap(punto),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.fotoparada',
              ),
              MarkerLayer(
                markers: [
                  if (punto != null)
                    Marker(
                      point: punto,
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.blue,
                        size: 40,
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
      ),
    );
  }
}
