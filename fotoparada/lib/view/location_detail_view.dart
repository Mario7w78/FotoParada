import 'package:flutter/material.dart';
import '../models/coleccion_model.dart';
import '../models/foto_model.dart';
import '../routes/app_routes.dart';
import '../viewmodel/location_detail_viewmodel.dart';
import 'widgets/recuerdos_widgets.dart';

class LocationDetailView extends StatefulWidget {
  const LocationDetailView({
    super.key,
    required this.nombreLugar,
  });

  final String nombreLugar;

  @override
  State<LocationDetailView> createState() => _LocationDetailViewState();
}

class _LocationDetailViewState extends State<LocationDetailView> {
  late final LocationDetailViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    // Instanciamos el ViewModel con el lugar que recibimos por parámetro
    _viewModel = LocationDetailViewModel(nombreLugar: widget.nombreLugar);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nombreLugar),
        centerTitle: true,
        // Integrante 4: línea de tiempo y guardar el lugar en una colección.
        actions: [
          IconButton(
            tooltip: 'Línea de tiempo',
            icon: const Icon(Icons.timeline),
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.timeline,
              arguments: widget.nombreLugar,
            ),
          ),
          ListenableBuilder(
            listenable: _viewModel,
            builder: (context, _) {
              final foto = _viewModel.fotos.firstOrNull;
              return IconButton(
                tooltip: 'Guardar lugar',
                icon: const Icon(Icons.bookmark_add_outlined),
                onPressed: foto == null
                    ? null
                    : () => mostrarGuardarEnColeccion(
                          context,
                          ElementoColeccion.desdeLugar(Lugar.desdeFoto(foto)),
                        ),
              );
            },
          ),
        ],
      ),
      // ListenableBuilder escucha los cambios del ChangeNotifier (el ViewModel)
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          return Column(
            children: [
              _construirFiltros(),
              const Divider(height: 1),
              Expanded(
                child: _construirContenido(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _construirFiltros() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Botón para Recientes
          ChoiceChip(
            label: const Text('Más recientes'),
            selected: _viewModel.modoActual == ModoOrdenamiento.recientes,
            onSelected: (selected) {
              if (selected) {
                _viewModel.cambiarModoOrdenamiento(ModoOrdenamiento.recientes);
              }
            },
          ),
          // Botón para Populares
          ChoiceChip(
            label: const Text('Más populares'),
            selected: _viewModel.modoActual == ModoOrdenamiento.populares,
            onSelected: (selected) {
              if (selected) {
                _viewModel.cambiarModoOrdenamiento(ModoOrdenamiento.populares);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _construirContenido() {
    if (_viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.errorMessage != null) {
      return Center(
        child: Text(
          _viewModel.errorMessage!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (_viewModel.fotos.isEmpty) {
      return const Center(
        child: Text('No hay fotos públicas en este lugar todavía.'),
      );
    }

    // Grid tipo Instagram para ver el feed del lugar
    return GridView.builder(
      padding: const EdgeInsets.all(4.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 3 columnas
        crossAxisSpacing: 4.0,
        mainAxisSpacing: 4.0,
      ),
      itemCount: _viewModel.fotos.length,
      itemBuilder: (context, index) {
        final foto = _viewModel.fotos[index];
        return _buildMiniatura(foto);
      },
    );
  }

  Widget _buildMiniatura(Foto foto) {
    return Stack(
      fit: StackFit.expand,
      children: [
        foto.urlMiniatura.isNotEmpty || foto.urlImagen.isNotEmpty
            ? Image.network(
                foto.urlMiniatura.isNotEmpty ? foto.urlMiniatura : foto.urlImagen,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image, color: Colors.grey),
              )
            : Container(color: Colors.grey.shade300, child: const Icon(Icons.image)),
        
        if (_viewModel.modoActual == ModoOrdenamiento.populares)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.favorite, size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '${foto.likes}',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
