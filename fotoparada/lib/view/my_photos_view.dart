import 'package:flutter/material.dart';

import '../models/foto_model.dart';
import '../routes/app_routes.dart';
import '../viewmodel/my_photos_viewmodel.dart';
import 'widgets/foto_widgets.dart';

class MyPhotosView extends StatefulWidget {
  const MyPhotosView({super.key, this.viewModel});

  /// Solo se indica en pruebas: por defecto la vista crea el suyo.
  final MyPhotosViewModel? viewModel;

  @override
  State<MyPhotosView> createState() => _MyPhotosViewState();
}

class _MyPhotosViewState extends State<MyPhotosView> {
  late final MyPhotosViewModel _viewModel =
      widget.viewModel ?? MyPhotosViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.iniciar();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _mostrarOpciones(Foto foto) async {
    final eliminar = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.delete, color: Colors.red),
          title: const Text(
            'Eliminar foto',
            style: TextStyle(color: Colors.red),
          ),
          onTap: () => Navigator.pop(context, true),
        ),
      ),
    );
    if (eliminar != true || !mounted) return;

    if (!await confirmarEliminarFoto(context) || !mounted) return;

    final exito = await _viewModel.eliminarFoto(foto);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          exito
              ? 'Foto eliminada'
              : _viewModel.errorEliminar ?? 'No se pudo eliminar la foto.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis fotos'),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _construirFiltros(),
            Expanded(child: _construirCuerpo()),
          ],
        ),
      ),
    );
  }

  Widget _construirFiltros() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          _construirFiltro(null, 'Todas', Icons.photo_library),
          for (final privacidad in PrivacidadFoto.values)
            _construirFiltro(
              privacidad,
              etiquetaPrivacidad(privacidad),
              iconoPrivacidad(privacidad),
            ),
        ],
      ),
    );
  }

  Widget _construirFiltro(
    PrivacidadFoto? valor,
    String etiqueta,
    IconData icono,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        showCheckmark: false,
        avatar: Icon(icono, size: 18),
        label: Text(etiqueta),
        selected: _viewModel.filtro == valor,
        onSelected: (_) => _viewModel.cambiarFiltro(valor),
      ),
    );
  }

  Widget _construirCuerpo() {
    if (_viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _viewModel.errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _viewModel.iniciar,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_viewModel.sinFotos) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.photo_camera, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Todavía no has subido fotos.'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.upload),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Subir mi primera foto'),
              ),
            ],
          ),
        ),
      );
    }

    final fotos = _viewModel.fotos;
    if (fotos.isEmpty) {
      return const Center(child: Text('No tienes fotos con esta privacidad.'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: fotos.length,
      itemBuilder: (context, index) => _construirMiniatura(fotos[index]),
    );
  }

  Widget _construirMiniatura(Foto foto) {
    final eliminando = _viewModel.estaEliminando(foto);
    return ClipRRect(
      key: ValueKey(foto.id),
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImagenFoto(base64: foto.miniaturaBase64),
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconoPrivacidad(foto.privacidad),
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
          if (eliminando)
            const ColoredBox(
              color: Colors.black54,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.editPhoto,
                  arguments: foto,
                ),
                onLongPress: () => _mostrarOpciones(foto),
              ),
            ),
        ],
      ),
    );
  }
}
