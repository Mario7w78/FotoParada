import 'package:flutter/material.dart';

import '../models/coleccion_model.dart';
import '../routes/app_routes.dart';
import '../viewmodel/collections_viewmodel.dart';
import 'widgets/interaccion_widgets.dart';
import 'widgets/recuerdos_widgets.dart';

/// Integrante 4 - Pestaña "Guardado": colecciones de fotos y lugares.
class CollectionsView extends StatefulWidget {
  const CollectionsView({super.key, this.viewModel});

  /// Permite inyectar un viewmodel en las pruebas.
  final CollectionsViewModel? viewModel;

  @override
  State<CollectionsView> createState() => _CollectionsViewState();
}

class _CollectionsViewState extends State<CollectionsView> {
  late final CollectionsViewModel _viewModel =
      widget.viewModel ?? CollectionsViewModel();

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

  void _mostrarMensaje(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _crear() async {
    final datos = await pedirDatosColeccion(context);
    if (datos == null) return;
    final creada =
        await _viewModel.crearColeccion(datos.nombre, datos.descripcion);
    _mostrarMensaje(
      creada != null
          ? 'Colección "${creada.nombre}" creada'
          : _viewModel.errorAccion ?? 'No se pudo crear la colección.',
    );
  }

  Future<void> _editar(Coleccion coleccion) async {
    final datos = await pedirDatosColeccion(
      context,
      titulo: 'Editar colección',
      nombre: coleccion.nombre,
      descripcion: coleccion.descripcion,
    );
    if (datos == null) return;
    final exito = await _viewModel.editarColeccion(
      coleccion,
      datos.nombre,
      datos.descripcion,
    );
    if (!exito) {
      _mostrarMensaje(_viewModel.errorAccion ?? 'No se pudo editar.');
    }
  }

  Future<void> _eliminar(Coleccion coleccion) async {
    final confirmado = await confirmarEliminarColeccion(context, coleccion);
    if (!confirmado) return;
    final exito = await _viewModel.eliminarColeccion(coleccion);
    _mostrarMensaje(
      exito
          ? 'Colección eliminada'
          : _viewModel.errorAccion ?? 'No se pudo eliminar.',
    );
  }

  void _abrir(Coleccion coleccion) {
    Navigator.pushNamed(
      context,
      AppRoutes.collectionDetail,
      arguments: coleccion,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) => RefreshIndicator(
            onRefresh: _viewModel.iniciar,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                EncabezadoPantalla(
                  etiqueta: 'Recuerdos',
                  titulo: 'Mis colecciones',
                  acciones: [
                    BotonIconoClaro(
                      icono: Icons.add,
                      tooltip: 'Nueva colección',
                      color: ColoresFotoParada.azul,
                      onPressed: _viewModel.isGuardando ? null : _crear,
                    ),
                  ],
                ),
                ..._construirCuerpo(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _construirCuerpo() {
    if (_viewModel.isLoading && _viewModel.colecciones.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (_viewModel.errorMessage != null && _viewModel.colecciones.isEmpty) {
      return [
        MensajeCentrado(
          icono: Icons.error_outline,
          texto: _viewModel.errorMessage!,
          esError: true,
          accion: TextButton(
            onPressed: _viewModel.iniciar,
            child: const Text('Reintentar'),
          ),
        ),
      ];
    }

    final personalizadas = _viewModel.personalizadas;
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'Tienes ${textoCantidad(_viewModel.totalGuardados)} guardados en '
          '${_viewModel.colecciones.length} colecciones.',
          style: const TextStyle(color: ColoresFotoParada.gris),
        ),
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            for (final (i, coleccion) in _viewModel.predeterminadas.indexed) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: _TarjetaPredeterminada(
                  coleccion: coleccion,
                  onTap: () => _abrir(coleccion),
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 28),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: EncabezadoSeccion(
          icono: Icons.collections_bookmark_outlined,
          titulo: 'Mis colecciones (${personalizadas.length})',
          accion: TextButton.icon(
            onPressed: _viewModel.isGuardando ? null : _crear,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nueva'),
          ),
        ),
      ),
      const SizedBox(height: 12),
      if (personalizadas.isEmpty)
        const MensajeCentrado(
          icono: Icons.bookmark_add_outlined,
          texto: 'Crea colecciones como "Cafés favoritos" o "Murales de '
              'Lima" y guarda ahí fotos y lugares desde su detalle.',
        )
      else
        for (final coleccion in personalizadas)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _TarjetaColeccion(
              key: ValueKey(coleccion.id),
              coleccion: coleccion,
              onTap: () => _abrir(coleccion),
              onEditar: () => _editar(coleccion),
              onEliminar: () => _eliminar(coleccion),
            ),
          ),
    ];
  }
}

Future<bool> confirmarEliminarColeccion(
  BuildContext context,
  Coleccion coleccion,
) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('¿Eliminar "${coleccion.nombre}"?'),
      content: Text(
        'Se quitarán ${textoCantidad(coleccion.cantidad)} guardados. Las '
        'fotos originales no se borran.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return confirmado ?? false;
}

/// Tarjeta grande de "Quiero visitar" y "Mis viajes".
class _TarjetaPredeterminada extends StatelessWidget {
  const _TarjetaPredeterminada({required this.coleccion, required this.onTap});

  final Coleccion coleccion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = colorColeccion(coleccion.tipo);
    return AspectRatio(
      aspectRatio: 0.8,
      child: coleccion.portadaUrl.isNotEmpty
          ? FotoConDegradado(
              url: coleccion.portadaUrl,
              titulo: coleccion.nombre,
              subtitulo: textoCantidad(coleccion.cantidad),
              onTap: onTap,
            )
          : TarjetaBlanca(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(iconoColeccion(coleccion.tipo), color: color),
                  ),
                  const Spacer(),
                  Text(
                    coleccion.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ColoresFotoParada.azulOscuro,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    textoCantidad(coleccion.cantidad),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ColoresFotoParada.gris),
                  ),
                ],
              ),
            ),
    );
  }
}

class _TarjetaColeccion extends StatelessWidget {
  const _TarjetaColeccion({
    super.key,
    required this.coleccion,
    required this.onTap,
    required this.onEditar,
    required this.onEliminar,
  });

  final Coleccion coleccion;
  final VoidCallback onTap;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return TarjetaBlanca(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      child: Row(
        children: [
          PortadaColeccion(coleccion: coleccion),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coleccion.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ColoresFotoParada.azulOscuro,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (coleccion.descripcion.isNotEmpty)
                  Text(
                    coleccion.descripcion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ColoresFotoParada.gris),
                  ),
                const SizedBox(height: 4),
                EtiquetaDato(
                  icono: Icons.bookmark_outline,
                  texto: textoCantidad(coleccion.cantidad),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opciones',
            icon: const Icon(Icons.more_vert, color: ColoresFotoParada.gris),
            onSelected: (opcion) =>
                opcion == 'editar' ? onEditar() : onEliminar(),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'editar',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Editar'),
                ),
              ),
              PopupMenuItem(
                value: 'eliminar',
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.red),
                  title: Text('Eliminar', style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
