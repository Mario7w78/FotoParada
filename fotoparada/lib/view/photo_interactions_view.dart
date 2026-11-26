import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/checkin_model.dart';
import '../models/coleccion_model.dart';
import '../models/comentario_model.dart';
import '../models/foto_model.dart';
import '../models/reaccion_model.dart';
import '../routes/app_routes.dart';
import '../viewmodel/photo_interactions_viewmodel.dart';
import '../viewmodel/share_location_viewmodel.dart';
import 'widgets/interaccion_widgets.dart';
import 'widgets/recuerdos_widgets.dart';

/// Detalle de una foto con sus reacciones y comentarios.
class PhotoInteractionsView extends StatefulWidget {
  const PhotoInteractionsView({super.key, required this.foto, this.viewModel});

  final Foto foto;

  /// Permite inyectar un viewmodel en las pruebas.
  final PhotoInteractionsViewModel? viewModel;

  @override
  State<PhotoInteractionsView> createState() => _PhotoInteractionsViewState();
}

class _PhotoInteractionsViewState extends State<PhotoInteractionsView> {
  late final PhotoInteractionsViewModel _viewModel =
      widget.viewModel ?? PhotoInteractionsViewModel(foto: widget.foto);
  final _comentarioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel.iniciar();
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _mostrarError() {
    final error = _viewModel.errorAccion;
    if (error == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _reaccionar(TipoReaccion tipo) async {
    final exito = await _viewModel.reaccionar(tipo);
    if (!exito) _mostrarError();
  }

  Future<void> _enviarComentario() async {
    final exito = await _viewModel.enviarComentario(_comentarioController.text);
    if (!mounted) return;
    if (exito) {
      _comentarioController.clear();
      FocusScope.of(context).unfocus();
    } else {
      _mostrarError();
    }
  }

  Future<void> _eliminarComentario(Comentario comentario) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar comentario?'),
        content: Text('"${comentario.texto}"'),
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
    if (confirmado != true) return;

    final exito = await _viewModel.eliminarComentario(comentario);
    if (!exito) _mostrarError();
  }

  @override
  Widget build(BuildContext context) {
    final foto = widget.foto;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) => Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    EncabezadoPantalla(
                      etiqueta: foto.nombreLugar.isEmpty
                          ? 'Foto'
                          : foto.nombreLugar,
                      titulo: foto.titulo,
                      acciones: [
                        // Integrante 4: guardar la foto en una colección.
                        BotonIconoClaro(
                          icono: Icons.bookmark_add_outlined,
                          tooltip: 'Guardar en colección',
                          onPressed: () => mostrarGuardarEnColeccion(
                            context,
                            ElementoColeccion.desdeFoto(foto),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Integrante 4: línea de tiempo del lugar (por
                        // nombre o por cercanía si la foto no tiene nombre).
                        BotonIconoClaro(
                          icono: Icons.timeline,
                          tooltip: 'Línea de tiempo del lugar',
                          onPressed: () => Navigator.pushNamed(
                            context,
                            AppRoutes.timeline,
                            arguments: Lugar.desdeFoto(foto),
                          ),
                        ),
                        const SizedBox(width: 8),
                        BotonIconoClaro(
                          icono: Icons.share_outlined,
                          tooltip: 'Compartir',
                          onPressed: () => Navigator.pushNamed(
                            context,
                            AppRoutes.shareLocation,
                            arguments: ShareLocationArgs.desdeFoto(foto),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),
                          AspectRatio(
                            aspectRatio: 4 / 3,
                            child: FotoConDegradado(
                              url: foto.urlImagen,
                              titulo: foto.nombreLugar.isEmpty
                                  ? foto.titulo
                                  : foto.nombreLugar,
                              subtitulo:
                                  '${etiquetaCategoria(foto.categoria)} · '
                                  '${DateFormat('dd/MM/yyyy').format(foto.fechaToma)}',
                            ),
                          ),
                          if (foto.descripcion.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              foto.descripcion,
                              style: const TextStyle(
                                color: ColoresFotoParada.azulOscuro,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _construirAcciones(foto),
                          const SizedBox(height: 16),
                          _construirReacciones(),
                          const SizedBox(height: 24),
                          EncabezadoSeccion(
                            icono: Icons.chat_bubble_outline,
                            titulo:
                                'Comentarios (${_viewModel.comentarios.length})',
                          ),
                          const SizedBox(height: 12),
                          _construirComentarios(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _construirCampoComentario(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirAcciones(Foto foto) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.checkIn,
              arguments: LugarCheckIn(
                nombre: foto.nombreLugar.isEmpty
                    ? foto.titulo
                    : foto.nombreLugar,
                latitud: foto.latitud,
                longitud: foto.longitud,
              ),
            ),
            icon: const Icon(Icons.where_to_vote_outlined),
            label: const Text('Check-in aquí'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.shareLocation,
              arguments: ShareLocationArgs.desdeFoto(foto),
            ),
            icon: const Icon(Icons.link),
            label: const Text('Compartir'),
          ),
        ),
      ],
    );
  }

  Widget _construirReacciones() {
    final miReaccion = _viewModel.miReaccion;
    return TarjetaBlanca(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final tipo in TipoReaccion.values)
                _BotonReaccion(
                  tipo: tipo,
                  cantidad: _viewModel.conteo(tipo),
                  seleccionado: miReaccion == tipo,
                  onTap: _viewModel.isReaccionando
                      ? null
                      : () => _reaccionar(tipo),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            miReaccion == null
                ? '${_viewModel.totalReacciones} reacciones · Toca para reaccionar'
                : 'Reaccionaste con "${miReaccion.etiqueta}" · Toca de nuevo para quitarla',
            style: const TextStyle(color: ColoresFotoParada.gris, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _construirComentarios() {
    if (_viewModel.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_viewModel.errorMessage != null) {
      return MensajeCentrado(
        icono: Icons.error_outline,
        texto: _viewModel.errorMessage!,
        esError: true,
        accion: TextButton(
          onPressed: _viewModel.iniciar,
          child: const Text('Reintentar'),
        ),
      );
    }

    if (_viewModel.comentarios.isEmpty) {
      return const MensajeCentrado(
        icono: Icons.forum_outlined,
        texto: 'Aún no hay comentarios. ¡Sé el primero!',
      );
    }

    return Column(
      children: [
        for (final comentario in _viewModel.comentarios)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TarjetaComentario(
              comentario: comentario,
              esDelDueno: comentario.uid == widget.foto.uid,
              eliminando: _viewModel.estaEliminando(comentario),
              onEliminar: _viewModel.puedeEliminar(comentario)
                  ? () => _eliminarComentario(comentario)
                  : null,
            ),
          ),
      ],
    );
  }

  Widget _construirCampoComentario() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _comentarioController,
              maxLength: Comentario.largoMaximo,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Escribe un comentario...',
                counterText: '',
                filled: true,
                fillColor: ColoresFotoParada.azulClaro.withValues(alpha: 0.6),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _enviarComentario(),
            ),
          ),
          const SizedBox(width: 4),
          _viewModel.isEnviando
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton.filled(
                  onPressed: _enviarComentario,
                  tooltip: 'Enviar',
                  style: IconButton.styleFrom(
                    backgroundColor: ColoresFotoParada.azul,
                  ),
                  icon: const Icon(Icons.send, color: Colors.white),
                ),
        ],
      ),
    );
  }
}

class _BotonReaccion extends StatelessWidget {
  const _BotonReaccion({
    required this.tipo,
    required this.cantidad,
    required this.seleccionado,
    required this.onTap,
  });

  final TipoReaccion tipo;
  final int cantidad;
  final bool seleccionado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tipo.etiqueta,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: seleccionado
                ? ColoresFotoParada.azulClaro
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: seleccionado
                  ? ColoresFotoParada.azul
                  : ColoresFotoParada.borde,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tipo.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 4),
              Text(
                '$cantidad',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: seleccionado
                      ? ColoresFotoParada.azul
                      : ColoresFotoParada.azulOscuro,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaComentario extends StatelessWidget {
  const _TarjetaComentario({
    required this.comentario,
    required this.esDelDueno,
    required this.eliminando,
    required this.onEliminar,
  });

  final Comentario comentario;
  final bool esDelDueno;
  final bool eliminando;
  final VoidCallback? onEliminar;

  @override
  Widget build(BuildContext context) {
    return TarjetaBlanca(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarInicial(nombre: comentario.nombreUsuario),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      comentario.nombreUsuario,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ColoresFotoParada.azulOscuro,
                      ),
                    ),
                    if (esDelDueno)
                      const EtiquetaDato(
                        icono: Icons.photo_camera,
                        texto: 'Autor',
                      ),
                    Text(
                      tiempoRelativo(comentario.fecha),
                      style: const TextStyle(
                        color: ColoresFotoParada.gris,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comentario.texto),
              ],
            ),
          ),
          if (onEliminar != null)
            eliminando
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    onPressed: onEliminar,
                    tooltip: 'Eliminar comentario',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: ColoresFotoParada.gris,
                    ),
                  ),
        ],
      ),
    );
  }
}
