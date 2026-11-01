import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/foto_model.dart';
import '../viewmodel/edit_photo_viewmodel.dart';
import 'widgets/formulario_foto.dart';
import 'widgets/foto_widgets.dart';

class EditPhotoView extends StatefulWidget {
  const EditPhotoView({super.key, required this.foto, this.viewModel});

  final Foto foto;

  /// Solo se indica en pruebas: por defecto la vista crea el suyo.
  final EditPhotoViewModel? viewModel;

  @override
  State<EditPhotoView> createState() => _EditPhotoViewState();
}

class _EditPhotoViewState extends State<EditPhotoView> {
  late final EditPhotoViewModel _viewModel =
      widget.viewModel ?? EditPhotoViewModel(foto: widget.foto);
  late final _tituloController = TextEditingController(text: widget.foto.titulo);
  late final _descripcionController =
      TextEditingController(text: widget.foto.descripcion);

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

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    final exito = await _viewModel.guardar();
    if (!mounted) return;

    if (exito) {
      _mostrarMensaje('Cambios guardados');
      Navigator.pop(context);
    } else if (_viewModel.errorMessage != null) {
      _mostrarMensaje(_viewModel.errorMessage!);
    }
  }

  Future<void> _eliminar() async {
    FocusScope.of(context).unfocus();
    if (!await confirmarEliminarFoto(context) || !mounted) return;

    final exito = await _viewModel.eliminar();
    if (!mounted) return;

    if (exito) {
      _mostrarMensaje('Foto eliminada');
      Navigator.pop(context);
    } else if (_viewModel.errorMessage != null) {
      _mostrarMensaje(_viewModel.errorMessage!);
    }
  }

  Future<void> _elegirFecha() async {
    final fecha = await elegirFechaToma(context, _viewModel.foto.fechaToma);
    if (fecha != null) _viewModel.cambiarFechaToma(fecha);
  }

  Future<void> _confirmarSalida() async {
    if (_viewModel.isLoading) return;

    final descartar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Descartar los cambios?'),
        content: const Text('Tienes cambios sin guardar en esta foto.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir editando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (descartar == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => PopScope<void>(
        canPop: !_viewModel.hayCambios && !_viewModel.isLoading,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _confirmarSalida();
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Editar foto'),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            physics:
                _dedoSobreMapa ? const NeverScrollableScrollPhysics() : null,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 300,
                    child: ImagenFoto(base64: widget.foto.imagenBase64),
                  ),
                ),
                const SizedBox(height: 24),
                FormularioFoto(
                  tituloController: _tituloController,
                  descripcionController: _descripcionController,
                  onTituloChanged: _viewModel.cambiarTitulo,
                  onDescripcionChanged: _viewModel.cambiarDescripcion,
                  categoria: _viewModel.foto.categoria,
                  onCategoriaChanged: _viewModel.cambiarCategoria,
                  privacidad: _viewModel.foto.privacidad,
                  onPrivacidadChanged: _viewModel.cambiarPrivacidad,
                  punto: LatLng(
                    _viewModel.foto.latitud,
                    _viewModel.foto.longitud,
                  ),
                  centrarMapa: false,
                  onMapaTap: (punto) => _viewModel.cambiarUbicacion(
                    punto.latitude,
                    punto.longitude,
                  ),
                  onDedoSobreMapa: (activo) =>
                      setState(() => _dedoSobreMapa = activo),
                  isLoadingUbicacion: _viewModel.isLoadingUbicacion,
                  nombreLugar: _viewModel.foto.nombreLugar,
                  fecha: _viewModel.foto.fechaToma,
                  onFechaTap: _elegirFecha,
                ),
                const SizedBox(height: 24),
                ..._construirAcciones(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _construirAcciones() {
    if (_viewModel.isLoading) {
      return const [Center(child: CircularProgressIndicator())];
    }
    return [
      ElevatedButton(
        onPressed: _viewModel.hayCambios ? _guardar : null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        child: const Text('Guardar cambios', style: TextStyle(fontSize: 18)),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _eliminar,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          foregroundColor: Colors.red,
        ),
        icon: const Icon(Icons.delete),
        label: const Text('Eliminar foto'),
      ),
    ];
  }
}
