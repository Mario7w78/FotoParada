import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../viewmodel/upload_photo_viewmodel.dart';
import 'widgets/formulario_foto.dart';
import 'widgets/foto_widgets.dart';

class UploadPhotoView extends StatefulWidget {
  const UploadPhotoView({super.key});

  @override
  State<UploadPhotoView> createState() => _UploadPhotoViewState();
}

class _UploadPhotoViewState extends State<UploadPhotoView> {
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _viewModel = UploadPhotoViewModel();

  // Mientras un dedo está sobre el mapa, el scroll de la pantalla se desactiva
  // para que el gesto mueva el mapa y no la página.
  bool _dedoSobreMapa = false;

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  LatLng? get _puntoSeleccionado {
    final latitud = _viewModel.latitud;
    final longitud = _viewModel.longitud;
    if (latitud == null || longitud == null) return null;
    return LatLng(latitud, longitud);
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

  Future<void> _elegirFecha() async {
    final fecha = await elegirFechaToma(
      context,
      _viewModel.fechaToma ?? DateTime.now(),
    );
    if (fecha != null) _viewModel.cambiarFechaToma(fecha);
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
              FormularioFoto(
                tituloController: _tituloController,
                descripcionController: _descripcionController,
                onTituloChanged: _viewModel.cambiarTitulo,
                onDescripcionChanged: _viewModel.cambiarDescripcion,
                categoria: _viewModel.categoria,
                onCategoriaChanged: _viewModel.cambiarCategoria,
                privacidad: _viewModel.privacidad,
                onPrivacidadChanged: _viewModel.cambiarPrivacidad,
                punto: _puntoSeleccionado,
                centrarMapa:
                    _viewModel.origenUbicacion != OrigenUbicacion.manual,
                onMapaTap: (punto) => _viewModel.cambiarUbicacion(
                  punto.latitude,
                  punto.longitude,
                ),
                onDedoSobreMapa: (activo) =>
                    setState(() => _dedoSobreMapa = activo),
                isLoadingUbicacion: _viewModel.isLoadingUbicacion,
                nombreLugar: _viewModel.nombreLugar,
                origenUbicacion: _textoOrigenUbicacion(),
                accionUbicacion: TextButton.icon(
                  onPressed: _viewModel.isLoadingUbicacion
                      ? null
                      : () => _ejecutar(_viewModel.obtenerUbicacion),
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text('Detectar'),
                ),
                fecha: _viewModel.fechaToma,
                onFechaTap: _viewModel.fechaEditable ? _elegirFecha : null,
              ),
              const SizedBox(height: 24),
              _construirBotonPublicar(),
            ],
          ),
        ),
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
