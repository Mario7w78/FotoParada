import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../services/share_service.dart';
import '../viewmodel/share_location_viewmodel.dart';
import 'widgets/foto_widgets.dart';
import 'widgets/interaccion_widgets.dart';
import 'widgets/mapa_punto.dart';

/// Genera un enlace a una ubicación (y opcionalmente a la foto) y lo comparte.
class ShareLocationView extends StatefulWidget {
  const ShareLocationView({super.key, required this.args, this.viewModel});

  final ShareLocationArgs args;

  /// Permite inyectar un viewmodel en las pruebas.
  final ShareLocationViewModel? viewModel;

  @override
  State<ShareLocationView> createState() => _ShareLocationViewState();
}

class _ShareLocationViewState extends State<ShareLocationView> {
  late final ShareLocationViewModel _viewModel =
      widget.viewModel ?? ShareLocationViewModel(args: widget.args);

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _compartir() async {
    final exito = await _viewModel.compartir();
    if (!exito && mounted && _viewModel.errorMessage != null) {
      _mostrarMensaje(_viewModel.errorMessage!);
    }
  }

  Future<void> _copiar() async {
    final exito = await _viewModel.copiarEnlace();
    if (!mounted) return;
    _mostrarMensaje(
      exito ? 'Enlace copiado' : _viewModel.errorMessage ?? 'Error al copiar',
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) => ListView(
            children: [
              EncabezadoPantalla(
                etiqueta: 'Compartir ubicación',
                titulo: _viewModel.nombreLugar,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MapaPunto(punto: LatLng(args.latitud, args.longitud)),
                    const SizedBox(height: 8),
                    Text(
                      '${args.latitud.toStringAsFixed(5)}, '
                      '${args.longitud.toStringAsFixed(5)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: ColoresFotoParada.gris),
                    ),
                    if (_viewModel.tieneFoto) ...[
                      const SizedBox(height: 16),
                      _construirFoto(),
                    ],
                    const SizedBox(height: 24),
                    const EncabezadoSeccion(
                      icono: Icons.map_outlined,
                      titulo: 'Abrir con',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final proveedor in ProveedorMapa.values)
                          ChipPildora(
                            etiqueta: proveedor.etiqueta,
                            seleccionado: _viewModel.proveedor == proveedor,
                            onSelected: () =>
                                _viewModel.cambiarProveedor(proveedor),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const EncabezadoSeccion(
                      icono: Icons.link,
                      titulo: 'Vista previa del mensaje',
                    ),
                    const SizedBox(height: 8),
                    TarjetaBlanca(
                      child: SelectableText(
                        _viewModel.texto,
                        style: const TextStyle(height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _viewModel.isCompartiendo ? null : _compartir,
                      style: FilledButton.styleFrom(
                        backgroundColor: ColoresFotoParada.azul,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.share),
                      label: const Text('Compartir'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _copiar,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.copy),
                      label: const Text('Copiar enlace'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirFoto() {
    final foto = widget.args.foto!;
    return TarjetaBlanca(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 56,
              height: 56,
              child: ImagenFoto(
                url: foto.urlMiniatura.isNotEmpty
                    ? foto.urlMiniatura
                    : foto.urlImagen,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  foto.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ColoresFotoParada.azulOscuro,
                  ),
                ),
                const Text(
                  'Incluir enlace de la foto',
                  style: TextStyle(color: ColoresFotoParada.gris, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: _viewModel.incluirFoto,
            onChanged: _viewModel.cambiarIncluirFoto,
          ),
        ],
      ),
    );
  }
}
