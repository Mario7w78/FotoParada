import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../models/foto_model.dart';
import '../viewmodel/create_challenge_viewmodel.dart';
import 'widgets/envio_segundo_plano.dart';
import 'widgets/interaccion_widgets.dart';
import 'widgets/mapa_punto.dart';

class CreateChallengeView extends StatefulWidget {
  const CreateChallengeView({super.key, this.viewModel});

  /// Permite inyectar un viewmodel en las pruebas.
  final CreateChallengeViewModel? viewModel;

  @override
  State<CreateChallengeView> createState() => _CreateChallengeViewState();
}

class _CreateChallengeViewState extends State<CreateChallengeView> {
  late final CreateChallengeViewModel _viewModel =
      widget.viewModel ?? CreateChallengeViewModel();
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _elegirFechaFin() async {
    final ahora = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _viewModel.fechaFin,
      firstDate: ahora,
      lastDate: ahora.add(const Duration(days: 365)),
      helpText: 'Fecha de fin del reto',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (fecha != null) _viewModel.cambiarFechaFin(fecha);
  }

  Future<void> _usarMiUbicacion() async {
    await _viewModel.usarMiUbicacion();
    if (mounted && _viewModel.errorMessage != null) {
      _mostrarMensaje(_viewModel.errorMessage!);
    }
  }

  void _crear() {
    FocusScope.of(context).unfocus();
    final invalido = _viewModel.errorDeValidacion;
    if (invalido != null) return _mostrarMensaje(invalido);

    final viewModel = _viewModel;
    cerrarYEnviar(
      context,
      envio: () async => await viewModel.crear() != null,
      error: () => viewModel.errorMessage,
      mensaje: '¡Reto publicado!',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) => ListView(
            children: [
              const EncabezadoPantalla(
                etiqueta: 'Nuevo reto',
                titulo: 'Propón un reto fotográfico',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _campoTexto(
                      controller: _tituloController,
                      etiqueta: 'Título',
                      ayuda: 'Ej.: Encuentra un mural y fotografíalo',
                      icono: Icons.emoji_events_outlined,
                      onChanged: _viewModel.cambiarTitulo,
                    ),
                    const SizedBox(height: 12),
                    _campoTexto(
                      controller: _descripcionController,
                      etiqueta: 'Descripción',
                      ayuda: 'Explica qué hay que fotografiar',
                      icono: Icons.notes,
                      maxLines: 3,
                      onChanged: _viewModel.cambiarDescripcion,
                    ),
                    const SizedBox(height: 24),
                    const EncabezadoSeccion(
                      icono: Icons.category_outlined,
                      titulo: 'Categoría',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        ChipPildora(
                          etiqueta: 'Cualquiera',
                          seleccionado: _viewModel.categoria == null,
                          onSelected: () => _viewModel.cambiarCategoria(null),
                        ),
                        for (final categoria in CategoriaFoto.values)
                          ChipPildora(
                            etiqueta: etiquetaCategoria(categoria),
                            icono: iconoCategoria(categoria),
                            seleccionado: _viewModel.categoria == categoria,
                            onSelected: () =>
                                _viewModel.cambiarCategoria(categoria),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const EncabezadoSeccion(
                      icono: Icons.flag_outlined,
                      titulo: 'Objetivo y plazo',
                    ),
                    const SizedBox(height: 8),
                    _construirObjetivo(),
                    const SizedBox(height: 24),
                    const EncabezadoSeccion(
                      icono: Icons.place_outlined,
                      titulo: 'Lugar (opcional)',
                    ),
                    const SizedBox(height: 8),
                    _construirUbicacion(),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: _viewModel.isGuardando ? null : _crear,
                      style: FilledButton.styleFrom(
                        backgroundColor: ColoresFotoParada.azul,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: _viewModel.isGuardando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.publish),
                      label: const Text('Publicar reto'),
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

  Widget _campoTexto({
    required TextEditingController controller,
    required String etiqueta,
    required String ayuda,
    required IconData icono,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: etiqueta,
        hintText: ayuda,
        prefixIcon: Icon(icono),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _construirObjetivo() {
    final objetivo = _viewModel.fotosObjetivo;
    return TarjetaBlanca(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.photo_library_outlined,
                color: ColoresFotoParada.azul,
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Fotos para completarlo')),
              IconButton(
                onPressed: objetivo > 1
                    ? () => _viewModel.cambiarFotosObjetivo(objetivo - 1)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$objetivo',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              IconButton(
                onPressed: objetivo < 10
                    ? () => _viewModel.cambiarFotosObjetivo(objetivo + 1)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event, color: ColoresFotoParada.azul),
            title: const Text('Termina el'),
            trailing: Text(
              DateFormat('dd/MM/yyyy').format(_viewModel.fechaFin),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: _elegirFechaFin,
          ),
        ],
      ),
    );
  }

  Widget _construirUbicacion() {
    if (!_viewModel.tieneUbicacion) {
      return OutlinedButton.icon(
        onPressed: _viewModel.isLoadingUbicacion ? null : _usarMiUbicacion,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: _viewModel.isLoadingUbicacion
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.my_location),
        label: const Text('Usar mi ubicación actual'),
      );
    }

    final punto = LatLng(_viewModel.latitud!, _viewModel.longitud!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MapaPunto(
          punto: punto,
          radioMetros: _viewModel.radioMetros,
          zoom: 14,
          altura: 160,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                _viewModel.nombreLugar.isEmpty
                    ? '${punto.latitude.toStringAsFixed(5)}, '
                        '${punto.longitude.toStringAsFixed(5)}'
                    : _viewModel.nombreLugar,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: ColoresFotoParada.azulOscuro),
              ),
            ),
            TextButton(
              onPressed: _viewModel.quitarUbicacion,
              child: const Text('Quitar'),
            ),
          ],
        ),
        const Text(
          'Las fotos deben tomarse dentro de:',
          style: TextStyle(color: ColoresFotoParada.gris),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final radio in CreateChallengeViewModel.radiosDisponibles)
              ChipPildora(
                etiqueta: formatearDistancia(radio),
                seleccionado: _viewModel.radioMetros == radio,
                onSelected: () => _viewModel.cambiarRadio(radio),
              ),
          ],
        ),
      ],
    );
  }
}
