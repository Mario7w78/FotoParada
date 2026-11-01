import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../models/foto_model.dart';
import '../viewmodel/upload_photo_viewmodel.dart';

class UploadPhotoView extends StatefulWidget {
  const UploadPhotoView({super.key});

  @override
  State<UploadPhotoView> createState() => _UploadPhotoViewState();
}

class _UploadPhotoViewState extends State<UploadPhotoView> {
  static const double _zoomEnfocado = 15;

  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _mapController = MapController();
  final _viewModel = UploadPhotoViewModel();

  bool _mapaListo = false;
  LatLng? _ultimoPuntoCentrado;

  // Mientras un dedo está sobre el mapa, el scroll de la pantalla se desactiva
  // para que el gesto mueva el mapa y no la página.
  bool _dedoSobreMapa = false;

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_centrarMapa);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_centrarMapa);
    _tituloController.dispose();
    _descripcionController.dispose();
    _mapController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  LatLng? get _puntoSeleccionado {
    final latitud = _viewModel.latitud;
    final longitud = _viewModel.longitud;
    if (latitud == null || longitud == null) return null;
    return LatLng(latitud, longitud);
  }

  void _centrarMapa() {
    final punto = _puntoSeleccionado;
    // Si el usuario eligió el punto, el mapa ya está donde él lo está mirando.
    if (!_mapaListo ||
        punto == null ||
        punto == _ultimoPuntoCentrado ||
        _viewModel.origenUbicacion == OrigenUbicacion.manual) {
      return;
    }
    _ultimoPuntoCentrado = punto;
    _mapController.move(punto, _zoomEnfocado);
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  Future<void> _ejecutar(Future<void> Function() accion) async {
    await accion();
    if (!mounted) return;
    if (_viewModel.errorMessage != null) {
      _mostrarMensaje(_viewModel.errorMessage!);
    }
  }

  Future<void> _publicar() async {
    FocusScope.of(context).unfocus();
    final exito = await _viewModel.publicar();
    if (!mounted) return;

    if (exito) {
      _mostrarMensaje('¡Foto publicada!');
      Navigator.pop(context);
    } else if (_viewModel.errorMessage != null) {
      _mostrarMensaje(_viewModel.errorMessage!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subir foto'),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) => SingleChildScrollView(
          physics: _dedoSobreMapa ? const NeverScrollableScrollPhysics() : null,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _construirVistaPrevia(),
              const SizedBox(height: 16),
              _construirBotonesImagen(),
              const SizedBox(height: 24),
              TextFormField(
                controller: _tituloController,
                textCapitalization: TextCapitalization.sentences,
                onChanged: _viewModel.cambiarTitulo,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descripcionController,
                textCapitalization: TextCapitalization.sentences,
                onChanged: _viewModel.cambiarDescripcion,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  prefixIcon: Icon(Icons.notes),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              _construirTituloSeccion('Categoría'),
              _construirCategorias(),
              const SizedBox(height: 24),
              _construirTituloSeccion('Privacidad'),
              _construirPrivacidad(),
              const SizedBox(height: 24),
              _construirEncabezadoUbicacion(),
              _construirMapa(),
              const SizedBox(height: 8),
              _construirDatosUbicacion(),
              const SizedBox(height: 16),
              _construirFecha(),
              const SizedBox(height: 24),
              _construirBotonPublicar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirTituloSeccion(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _construirVistaPrevia() {
    final imagen = _viewModel.imagen;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 220,
        child: imagen == null
            ? const ColoredBox(
                color: Colors.white,
                child: Center(
                  child: Icon(Icons.image_outlined, size: 80, color: Colors.grey),
                ),
              )
            : Image.file(
                imagen,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image, size: 100),
              ),
      ),
    );
  }

  Widget _construirBotonesImagen() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _ejecutar(_viewModel.elegirDeCamara),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Cámara'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _ejecutar(_viewModel.elegirDeGaleria),
            icon: const Icon(Icons.photo_library),
            label: const Text('Galería'),
          ),
        ),
      ],
    );
  }

  Widget _construirCategorias() {
    return Wrap(
      spacing: 8,
      children: [
        for (final categoria in CategoriaFoto.values)
          ChoiceChip(
            label: Text(
              '${categoria.name[0].toUpperCase()}${categoria.name.substring(1)}',
            ),
            selected: _viewModel.categoria == categoria,
            onSelected: (_) => _viewModel.cambiarCategoria(categoria),
          ),
      ],
    );
  }

  Widget _construirPrivacidad() {
    return SegmentedButton<PrivacidadFoto>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: PrivacidadFoto.publica,
          icon: Icon(Icons.public),
          label: Text('Pública'),
        ),
        ButtonSegment(
          value: PrivacidadFoto.amigos,
          icon: Icon(Icons.group),
          label: Text('Amigos'),
        ),
        ButtonSegment(
          value: PrivacidadFoto.privada,
          icon: Icon(Icons.lock),
          label: Text('Privada'),
        ),
      ],
      selected: {_viewModel.privacidad},
      onSelectionChanged: (seleccion) =>
          _viewModel.cambiarPrivacidad(seleccion.first),
    );
  }

  Widget _construirEncabezadoUbicacion() {
    return Row(
      children: [
        Expanded(child: _construirTituloSeccion('Ubicación')),
        TextButton.icon(
          onPressed: _viewModel.isLoadingUbicacion
              ? null
              : () => _ejecutar(_viewModel.obtenerUbicacion),
          icon: const Icon(Icons.my_location, size: 18),
          label: const Text('Detectar'),
        ),
      ],
    );
  }

  Widget _construirMapa() {
    final punto = _puntoSeleccionado;
    return Listener(
      onPointerDown: (_) => setState(() => _dedoSobreMapa = true),
      onPointerUp: (_) => setState(() => _dedoSobreMapa = false),
      onPointerCancel: (_) => setState(() => _dedoSobreMapa = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 220,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(0, 0),
              initialZoom: 2,
              minZoom: 2,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onMapReady: () {
                _mapaListo = true;
                _centrarMapa();
              },
              onTap: (_, punto) =>
                  _viewModel.cambiarUbicacion(punto.latitude, punto.longitude),
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

  Widget _construirDatosUbicacion() {
    final punto = _puntoSeleccionado;
    final String lugar;
    if (_viewModel.isLoadingUbicacion) {
      lugar = 'Obteniendo ubicación...';
    } else if (punto == null) {
      lugar = 'Toca el mapa para elegir el lugar';
    } else if (_viewModel.nombreLugar.isNotEmpty) {
      lugar = _viewModel.nombreLugar;
    } else {
      lugar =
          '${punto.latitude.toStringAsFixed(5)}, ${punto.longitude.toStringAsFixed(5)}';
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
              if (_textoOrigenUbicacion() != null)
                Text(
                  _textoOrigenUbicacion()!,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String? _textoOrigenUbicacion() {
    switch (_viewModel.origenUbicacion) {
      case OrigenUbicacion.foto:
        return 'Tomada de los datos de la foto';
      case OrigenUbicacion.manual:
        return 'Elegida en el mapa';
      case OrigenUbicacion.gps:
        // Avisa de que no es necesariamente donde se tomó una foto de galería.
        return _viewModel.origenImagen == OrigenImagen.galeria
            ? 'La foto no trae ubicación: se usó tu posición actual'
            : 'Tu posición actual';
      case null:
        return null;
    }
  }

  Widget _construirFecha() {
    final fecha = _viewModel.fechaToma;
    return Row(
      children: [
        const Icon(Icons.event, color: Colors.blue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            fecha == null
                ? 'Fecha de la foto: sin definir'
                : 'Fecha de la foto: ${DateFormat('dd/MM/yyyy HH:mm').format(fecha)}',
          ),
        ),
      ],
    );
  }

  Widget _construirBotonPublicar() {
    if (_viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ElevatedButton(
      onPressed: _publicar,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      child: const Text('Publicar', style: TextStyle(fontSize: 18)),
    );
  }
}
