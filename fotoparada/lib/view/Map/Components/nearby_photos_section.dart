import 'package:flutter/material.dart';

import '../../../models/foto_model.dart';
import '../../../routes/app_routes.dart';
import '../../../viewmodel/map_viewmodel.dart';
import '../../widgets/foto_widgets.dart';
import '../../widgets/interaccion_widgets.dart';

typedef _FotoCercana = ({Foto foto, double distancia});

/// "Descubre cerca de ti": las fotos públicas más cercanas a la posición
/// actual. Tocar una abre su detalle.
class NearbyPhotosSection extends StatelessWidget {
  const NearbyPhotosSection({super.key, required this.mapViewModel});

  final MapViewModel mapViewModel;

  void _abrir(BuildContext context, Foto foto) {
    Navigator.pushNamed(context, AppRoutes.photoInteractions, arguments: foto);
  }

  void _verTodas(BuildContext contextoPantalla) {
    showModalBottomSheet<void>(
      context: contextoPantalla,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, controller) {
          final fotos = mapViewModel.fotosCercanas;
          return ListView.builder(
            controller: controller,
            padding: const EdgeInsets.all(12),
            itemCount: fotos.length,
            itemBuilder: (context, index) {
              final cercana = fotos[index];
              return ListTile(
                leading: SizedBox(
                  width: 56,
                  height: 56,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ImagenFoto(url: cercana.foto.urlMiniatura),
                  ),
                ),
                title: Text(
                  cercana.foto.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(_detalle(cercana)),
                onTap: () {
                  Navigator.pop(context);
                  _abrir(contextoPantalla, cercana.foto);
                },
              );
            },
          );
        },
      ),
    );
  }

  String _detalle(_FotoCercana cercana) {
    final lugar = cercana.foto.nombreLugar;
    final distancia = formatearDistancia(cercana.distancia);
    return lugar.isEmpty ? distancia : '$lugar · $distancia';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: mapViewModel,
      builder: (context, _) {
        final fotos = mapViewModel.fotosCercanas;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Descubre cerca de ti',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                if (fotos.isNotEmpty)
                  TextButton(
                    onPressed: () => _verTodas(context),
                    child: const Text('Ver Todos'),
                  ),
              ],
            ),
            _construirContenido(context, fotos),
          ],
        );
      },
    );
  }

  Widget _construirContenido(BuildContext context, List<_FotoCercana> fotos) {
    if (mapViewModel.currentPosition == null) {
      return const _MensajeVacio(
        'Activa tu ubicación para ver las fotos cercanas.',
      );
    }
    if (fotos.isEmpty) {
      final radio = formatearDistancia(MapViewModel.radioExploracionMetros);
      return _MensajeVacio('Todavía no hay fotos a menos de $radio.');
    }

    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: fotos.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (_, index) => _TarjetaCercana(
          cercana: fotos[index],
          detalle: _detalle(fotos[index]),
          onTap: () => _abrir(context, fotos[index].foto),
        ),
      ),
    );
  }
}

class _MensajeVacio extends StatelessWidget {
  const _MensajeVacio(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(texto, style: const TextStyle(color: Colors.grey)),
    );
  }
}

class _TarjetaCercana extends StatelessWidget {
  const _TarjetaCercana({
    required this.cercana,
    required this.detalle,
    required this.onTap,
  });

  final _FotoCercana cercana;
  final String detalle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ImagenFoto(url: cercana.foto.urlMiniatura),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              cercana.foto.titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              detalle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
