import 'package:flutter/material.dart';

import '../models/coleccion_model.dart';
import '../models/foto_model.dart';
import '../routes/app_routes.dart';
import '../viewmodel/collection_detail_viewmodel.dart';
import 'collections_view.dart';
import 'widgets/envio_segundo_plano.dart';
import 'widgets/foto_widgets.dart';
import 'widgets/interaccion_widgets.dart';
import 'widgets/recuerdos_widgets.dart';

/// Integrante 4 - Contenido de una colección.
class CollectionDetailView extends StatefulWidget {
  const CollectionDetailView({
    super.key,
    required this.coleccion,
    this.viewModel,
  });

  final Coleccion coleccion;

  /// Permite inyectar un viewmodel en las pruebas.
  final CollectionDetailViewModel? viewModel;

  @override
  State<CollectionDetailView> createState() => _CollectionDetailViewState();
}

class _CollectionDetailViewState extends State<CollectionDetailView> {
  late final CollectionDetailViewModel _viewModel = widget.viewModel ??
      CollectionDetailViewModel(coleccion: widget.coleccion);

  bool _cerrando = false;

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_cerrarSiFueEliminada);
    _viewModel.iniciar();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_cerrarSiFueEliminada);
    _viewModel.dispose();
    super.dispose();
  }

  void _cerrarSiFueEliminada() {
    if (_viewModel.eliminada && !_cerrando && mounted) {
      _cerrando = true;
      Navigator.maybePop(context);
    }
  }

  void _mostrarMensaje(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  void _mostrarError() {
    _mostrarMensaje(_viewModel.errorAccion ?? 'No se pudo completar la acción.');
  }

  Future<void> _editarColeccion() async {
    final coleccion = _viewModel.coleccion;
    final datos = await pedirDatosColeccion(
      context,
      titulo: 'Editar colección',
      nombre: coleccion.nombre,
      descripcion: coleccion.descripcion,
    );
    if (datos == null) return;
    final exito =
        await _viewModel.editarColeccion(datos.nombre, datos.descripcion);
    if (!exito) _mostrarError();
  }

  Future<void> _eliminarColeccion() async {
    final coleccion = _viewModel.coleccion;
    if (!await confirmarEliminarColeccion(context, coleccion) || !mounted) {
      return;
    }
    // Se vuelve a la lista sin esperar; esta pantalla ya no debe cerrarse sola.
    _cerrando = true;
    final viewModel = _viewModel;
    cerrarYEnviar(
      context,
      envio: viewModel.eliminarColeccion,
      error: () => viewModel.errorAccion,
      mensaje: 'Colección eliminada',
    );
  }

  void _verLineaDeTiempo(ElementoColeccion elemento) {
    Navigator.pushNamed(
      context,
      AppRoutes.timeline,
      arguments: elemento.lugar,
    );
  }

  Future<void> _abrirFoto(ElementoColeccion elemento) async {
    final Foto? foto = await _viewModel.abrirFoto(elemento);
    if (!mounted) return;
    if (foto == null) {
      _mostrarError();
      return;
    }
    Navigator.pushNamed(context, AppRoutes.photoInteractions, arguments: foto);
  }

  /// La pantalla ya cambió al llamar a [accion]; aquí solo se confirma y se
  /// avisa si falla.
  Future<void> _avisar(Future<bool> accion, String mensaje) async {
    _mostrarMensaje(mensaje);
    if (!await accion) _mostrarError();
  }

  Future<void> _quitar(ElementoColeccion elemento) => _avisar(
        _viewModel.quitar(elemento),
        'Se quitó "${elemento.titulo}" de la colección',
      );

  Future<void> _marcarVisitado(ElementoColeccion elemento) async {
    if (!_viewModel.puedeMarcarVisitado) return;
    await _avisar(
      _viewModel.marcarVisitado(elemento),
      '"${elemento.titulo}" pasó a Mis viajes ✈️',
    );
  }

  Future<void> _mover(ElementoColeccion elemento) async {
    final destino = await showModalBottomSheet<Coleccion>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Mover a...',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: ColoresFotoParada.azulOscuro,
                ),
              ),
            ),
            for (final coleccion in _viewModel.otrasColecciones)
              ListTile(
                leading: PortadaColeccion(coleccion: coleccion, tamano: 40),
                title: Text(coleccion.nombre),
                subtitle: Text(textoCantidad(coleccion.cantidad)),
                onTap: () => Navigator.pop(context, coleccion),
              ),
          ],
        ),
      ),
    );
    if (destino == null) return;
    await _avisar(
      _viewModel.moverA(elemento, destino),
      'Movido a "${destino.nombre}"',
    );
  }

  Future<void> _editarNota(ElementoColeccion elemento) async {
    final nota = await pedirNota(context, elemento.nota);
    if (nota == null) return;
    final exito = await _viewModel.guardarNota(elemento, nota);
    if (!exito) _mostrarError();
  }

  Future<void> _opciones(ElementoColeccion elemento) async {
    final opcion = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (elemento.esFoto)
              ListTile(
                leading: const Icon(Icons.photo_outlined),
                title: const Text('Ver foto'),
                onTap: () => Navigator.pop(context, 'foto'),
              ),
            ListTile(
              leading: const Icon(Icons.timeline),
              title: const Text('Ver línea de tiempo del lugar'),
              onTap: () => Navigator.pop(context, 'linea'),
            ),
            if (_viewModel.puedeMarcarVisitado)
              ListTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: ColoresFotoParada.verde,
                ),
                title: const Text('Ya lo visité (pasar a Mis viajes)'),
                onTap: () => Navigator.pop(context, 'visitado'),
              ),
            if (_viewModel.otrasColecciones.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.drive_file_move_outlined),
                title: const Text('Mover a otra colección'),
                onTap: () => Navigator.pop(context, 'mover'),
              ),
            ListTile(
              leading: const Icon(Icons.sticky_note_2_outlined),
              title: Text(elemento.nota.isEmpty ? 'Agregar nota' : 'Editar nota'),
              onTap: () => Navigator.pop(context, 'nota'),
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_remove_outlined,
                  color: Colors.red),
              title: const Text(
                'Quitar de la colección',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => Navigator.pop(context, 'quitar'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (opcion) {
      case 'foto':
        await _abrirFoto(elemento);
      case 'linea':
        _verLineaDeTiempo(elemento);
      case 'visitado':
        await _marcarVisitado(elemento);
      case 'mover':
        await _mover(elemento);
      case 'nota':
        await _editarNota(elemento);
      case 'quitar':
        await _quitar(elemento);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) {
            final coleccion = _viewModel.coleccion;
            return ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                EncabezadoPantalla(
                  etiqueta: coleccion.esPredeterminada
                      ? 'Colección'
                      : 'Mi colección',
                  titulo: coleccion.nombre,
                  acciones: [
                    if (!coleccion.esPredeterminada)
                      PopupMenuButton<String>(
                        tooltip: 'Opciones',
                        onSelected: (opcion) => opcion == 'editar'
                            ? _editarColeccion()
                            : _eliminarColeccion(),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'editar',
                            child: Text('Editar colección'),
                          ),
                          PopupMenuItem(
                            value: 'eliminar',
                            child: Text(
                              'Eliminar colección',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                        child: const Material(
                          color: Colors.white,
                          elevation: 1,
                          shadowColor: Colors.black12,
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(
                              Icons.more_horiz,
                              color: ColoresFotoParada.azulOscuro,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (coleccion.descripcion.isNotEmpty) ...[
                        Text(
                          coleccion.descripcion,
                          style: const TextStyle(color: ColoresFotoParada.gris),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Wrap(
                        spacing: 8,
                        children: [
                          EtiquetaDato(
                            icono: iconoColeccion(coleccion.tipo),
                            texto: textoCantidad(coleccion.cantidad),
                            color: colorColeccion(coleccion.tipo),
                          ),
                        ],
                      ),
                      if (_viewModel.puedeMarcarVisitado &&
                          _viewModel.lugares.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const _Consejo(
                          texto: 'Cuando visites un lugar, toca ✓ y pasará a '
                              '"Mis viajes".',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ..._construirContenido(),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _construirContenido() {
    if (_viewModel.isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_viewModel.errorMessage != null) {
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
    if (_viewModel.elementos.isEmpty) {
      return const [
        MensajeCentrado(
          icono: Icons.bookmark_add_outlined,
          texto: 'Aún no guardaste nada aquí.\nAbre una foto o un lugar y '
              'toca el ícono de guardar.',
        ),
      ];
    }

    final lugares = _viewModel.lugares;
    final fotos = _viewModel.fotos;
    return [
      if (lugares.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: EncabezadoSeccion(
            icono: Icons.place_outlined,
            titulo: 'Lugares (${lugares.length})',
          ),
        ),
        const SizedBox(height: 12),
        for (final lugar in lugares)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _TarjetaLugar(
              key: ValueKey(lugar.id),
              elemento: lugar,
              mostrarVisitado: _viewModel.puedeMarcarVisitado,
              onTap: () => _verLineaDeTiempo(lugar),
              onVisitado: () => _marcarVisitado(lugar),
              onOpciones: () => _opciones(lugar),
            ),
          ),
        const SizedBox(height: 12),
      ],
      if (fotos.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: EncabezadoSeccion(
            icono: Icons.photo_library_outlined,
            titulo: 'Fotos (${fotos.length})',
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: fotos.length,
          itemBuilder: (context, index) {
            final foto = fotos[index];
            return _MiniaturaFoto(
              key: ValueKey(foto.id),
              elemento: foto,
              onTap: () => _abrirFoto(foto),
              onLongPress: () => _opciones(foto),
            );
          },
        ),
      ],
    ];
  }
}

class _Consejo extends StatelessWidget {
  const _Consejo({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColoresFotoParada.azulClaro,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline, color: ColoresFotoParada.azul),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(color: ColoresFotoParada.azulOscuro),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaLugar extends StatelessWidget {
  const _TarjetaLugar({
    super.key,
    required this.elemento,
    required this.mostrarVisitado,
    required this.onTap,
    required this.onVisitado,
    required this.onOpciones,
  });

  final ElementoColeccion elemento;
  final bool mostrarVisitado;
  final VoidCallback onTap;
  final VoidCallback onVisitado;
  final VoidCallback onOpciones;

  @override
  Widget build(BuildContext context) {
    return TarjetaBlanca(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 56,
              height: 56,
              child: elemento.urlImagen.isEmpty
                  ? const ColoredBox(
                      color: ColoresFotoParada.azulClaro,
                      child: Icon(
                        Icons.place_outlined,
                        color: ColoresFotoParada.azul,
                      ),
                    )
                  : ImagenFoto(url: elemento.urlImagen),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  elemento.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ColoresFotoParada.azulOscuro,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  elemento.nota.isNotEmpty
                      ? '📝 ${elemento.nota}'
                      : 'Guardado el ${formatearFecha(elemento.fechaAgregado)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ColoresFotoParada.gris,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (mostrarVisitado)
            IconButton(
              tooltip: 'Ya lo visité',
              onPressed: onVisitado,
              icon: const Icon(
                Icons.check_circle_outline,
                color: ColoresFotoParada.verde,
              ),
            ),
          IconButton(
            tooltip: 'Opciones',
            onPressed: onOpciones,
            icon: const Icon(Icons.more_vert, color: ColoresFotoParada.gris),
          ),
        ],
      ),
    );
  }
}

class _MiniaturaFoto extends StatelessWidget {
  const _MiniaturaFoto({
    super.key,
    required this.elemento,
    required this.onTap,
    required this.onLongPress,
  });

  final ElementoColeccion elemento;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImagenFoto(url: elemento.urlImagen),
          if (elemento.nota.isNotEmpty)
            const Positioned(
              top: 4,
              right: 4,
              child: CircleAvatar(
                radius: 11,
                backgroundColor: Colors.black54,
                child: Icon(Icons.sticky_note_2, size: 13, color: Colors.white),
              ),
            ),
          Material(
            type: MaterialType.transparency,
            child: InkWell(onTap: onTap, onLongPress: onLongPress),
          ),
        ],
      ),
    );
  }
}
