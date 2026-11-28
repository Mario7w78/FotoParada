import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../models/checkin_model.dart';
import '../models/foto_model.dart';
import '../models/reto_model.dart';
import '../routes/app_routes.dart';
import '../viewmodel/challenge_detail_viewmodel.dart';
import '../viewmodel/share_location_viewmodel.dart';
import 'challenges_view.dart';
import 'widgets/envio_segundo_plano.dart';
import 'widgets/foto_widgets.dart';
import 'widgets/interaccion_widgets.dart';
import 'widgets/mapa_punto.dart';

class ChallengeDetailView extends StatefulWidget {
  const ChallengeDetailView({super.key, required this.reto, this.viewModel});

  final Reto reto;

  /// Permite inyectar un viewmodel en las pruebas.
  final ChallengeDetailViewModel? viewModel;

  @override
  State<ChallengeDetailView> createState() => _ChallengeDetailViewState();
}

class _ChallengeDetailViewState extends State<ChallengeDetailView> {
  late final ChallengeDetailViewModel _viewModel =
      widget.viewModel ?? ChallengeDetailViewModel(reto: widget.reto);

  Reto get _reto => widget.reto;

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

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _elegirFoto() async {
    final foto = await showModalBottomSheet<Foto>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => _SelectorFotos(viewModel: _viewModel),
    );
    if (foto == null || !mounted) return;

    // El progreso ya cuenta la foto mientras se envía.
    final envio = _viewModel.enviarFoto(foto);
    _mostrarMensaje(
      _viewModel.completado ? '¡Reto completado! 🎉' : '¡Foto enviada!',
    );
    final exito = await envio;
    if (!mounted || exito) return;
    _mostrarMensaje(_viewModel.errorAccion ?? 'No se pudo enviar la foto.');
  }

  Future<void> _eliminarReto() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar este reto?'),
        content: const Text('Los participantes ya no podrán verlo.'),
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

    if (!mounted) return;
    final viewModel = _viewModel;
    cerrarYEnviar(
      context,
      envio: viewModel.eliminarReto,
      error: () => viewModel.errorAccion,
      mensaje: 'Reto eliminado',
    );
  }

  Future<void> _quitarFoto(Foto foto) async {
    final retiro = _viewModel.quitarFoto(foto);
    _mostrarMensaje('Foto retirada del reto');
    final exito = await retiro;
    if (!mounted || exito) return;
    _mostrarMensaje(_viewModel.errorAccion ?? 'No se pudo quitar la foto.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) => ListView(
            children: [
              EncabezadoPantalla(
                etiqueta: tiempoRestante(_reto),
                titulo: _reto.titulo,
                acciones: [
                  if (_viewModel.esCreador)
                    BotonIconoClaro(
                      icono: Icons.delete_outline,
                      tooltip: 'Eliminar reto',
                      color: Colors.red,
                      onPressed: _eliminarReto,
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _construirInfo(),
                    const SizedBox(height: 16),
                    _construirProgreso(),
                    if (_reto.tieneUbicacion) ...[
                      const SizedBox(height: 24),
                      _construirLugar(),
                    ],
                    const SizedBox(height: 24),
                    ..._construirParticipantes(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirInfo() {
    return TarjetaBlanca(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_reto.descripcion.isNotEmpty) ...[
            Text(
              _reto.descripcion,
              style: const TextStyle(color: ColoresFotoParada.azulOscuro),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(spacing: 6, runSpacing: 6, children: etiquetasCondiciones(_reto)),
          const SizedBox(height: 12),
          Text(
            'Del ${DateFormat('dd/MM/yyyy').format(_reto.fechaInicio)} '
            'al ${DateFormat('dd/MM/yyyy').format(_reto.fechaFin)} · '
            'creado por ${_reto.creadorNombre}',
            style: const TextStyle(color: ColoresFotoParada.gris, fontSize: 12),
          ),
          const SizedBox(height: 4),
          const Text(
            'Solo cuentan fotos públicas tomadas mientras el reto está activo.',
            style: TextStyle(color: ColoresFotoParada.gris, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _construirProgreso() {
    final completado = _viewModel.completado;
    final activo = _reto.estaActivo();
    final color =
        completado ? ColoresFotoParada.verde : ColoresFotoParada.azul;

    return TarjetaBlanca(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                completado ? Icons.emoji_events : Icons.flag_outlined,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  completado ? '¡Reto completado!' : 'Tu progreso',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color,
                  ),
                ),
              ),
              Text(
                '${_viewModel.misFotosEnviadas} / ${_reto.fotosObjetivo}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _viewModel.progreso,
              minHeight: 10,
              color: color,
              backgroundColor: ColoresFotoParada.azulClaro,
            ),
          ),
          const SizedBox(height: 16),
          if (activo)
            FilledButton.icon(
              onPressed: _elegirFoto,
              style: FilledButton.styleFrom(
                backgroundColor: ColoresFotoParada.azul,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Enviar una de mis fotos'),
            )
          else
            const Text(
              'Este reto ya terminó.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ColoresFotoParada.gris),
            ),
        ],
      ),
    );
  }

  Widget _construirLugar() {
    final lugar = _reto.nombreLugar.isEmpty ? 'Lugar del reto' : _reto.nombreLugar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EncabezadoSeccion(icono: Icons.place_outlined, titulo: 'Lugar'),
        const SizedBox(height: 8),
        MapaPunto(
          punto: LatLng(_reto.latitud!, _reto.longitud!),
          radioMetros: _reto.radioMetros,
          zoom: 14,
          altura: 160,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.checkIn,
                  arguments: LugarCheckIn(
                    nombre: lugar,
                    latitud: _reto.latitud!,
                    longitud: _reto.longitud!,
                  ),
                ),
                icon: const Icon(Icons.where_to_vote_outlined),
                label: const Text('Check-in'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.shareLocation,
                  arguments: ShareLocationArgs(
                    nombreLugar: lugar,
                    latitud: _reto.latitud!,
                    longitud: _reto.longitud!,
                  ),
                ),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Compartir'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _construirParticipantes() {
    if (_viewModel.isLoading) {
      return const [Center(child: CircularProgressIndicator())];
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

    final participantes = _viewModel.participantes;
    final fotos = _viewModel.fotosEnviadas;

    return [
      EncabezadoSeccion(
        icono: Icons.leaderboard_outlined,
        titulo: 'Participantes',
        accion: Text(
          '${_viewModel.completaron} completaron',
          style: const TextStyle(
            color: ColoresFotoParada.verde,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
      const SizedBox(height: 8),
      if (participantes.isEmpty)
        const MensajeCentrado(
          icono: Icons.group_outlined,
          texto: 'Nadie ha participado todavía.',
        )
      else
        TarjetaBlanca(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < participantes.length; i++)
                ListTile(
                  leading: AvatarInicial(
                    nombre: participantes[i].nombreUsuario,
                  ),
                  title: Text(
                    '${i + 1}. ${participantes[i].nombreUsuario}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${participantes[i].fotoIds.length} de '
                    '${_reto.fotosObjetivo} fotos',
                  ),
                  trailing: participantes[i].completo(_reto)
                      ? const Icon(
                          Icons.emoji_events,
                          color: ColoresFotoParada.naranja,
                        )
                      : null,
                ),
            ],
          ),
        ),
      if (fotos.isNotEmpty) ...[
        const SizedBox(height: 24),
        const EncabezadoSeccion(
          icono: Icons.photo_library_outlined,
          titulo: 'Fotos del reto',
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: fotos.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            final foto = fotos[index];
            final esMia = foto.uid == _viewModel.uid;
            return GestureDetector(
              onLongPress: esMia && _reto.estaActivo()
                  ? () => _quitarFoto(foto)
                  : null,
              child: FotoConDegradado(
                url: foto.urlMiniatura.isNotEmpty
                    ? foto.urlMiniatura
                    : foto.urlImagen,
                titulo: foto.titulo,
                subtitulo: esMia ? 'Tu foto' : foto.nombreLugar,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.photoInteractions,
                  arguments: foto,
                ),
              ),
            );
          },
        ),
      ],
    ];
  }
}

/// Hoja inferior con las fotos propias. Las que no cumplen las condiciones
/// aparecen deshabilitadas con el motivo.
class _SelectorFotos extends StatefulWidget {
  const _SelectorFotos({required this.viewModel});

  final ChallengeDetailViewModel viewModel;

  @override
  State<_SelectorFotos> createState() => _SelectorFotosState();
}

class _SelectorFotosState extends State<_SelectorFotos> {
  late final Future<List<({Foto foto, String? motivo})>> _fotos =
      widget.viewModel.misFotosParaEnviar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Elige una foto',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: ColoresFotoParada.azulOscuro,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder(
              future: _fotos,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const MensajeCentrado(
                    icono: Icons.error_outline,
                    texto: 'No se pudieron cargar tus fotos.',
                    esError: true,
                  );
                }
                final fotos = snapshot.data ?? const [];
                if (fotos.isEmpty) {
                  return const MensajeCentrado(
                    icono: Icons.photo_outlined,
                    texto: 'No tienes fotos para enviar. Sube una nueva.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: fotos.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final (:foto, :motivo) = fotos[index];
                    final cumple = motivo == null;
                    return Opacity(
                      opacity: cumple ? 1 : 0.5,
                      child: ListTile(
                        enabled: cumple,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: ImagenFoto(
                              url: foto.urlMiniatura.isNotEmpty
                                  ? foto.urlMiniatura
                                  : foto.urlImagen,
                            ),
                          ),
                        ),
                        title: Text(foto.titulo),
                        subtitle: Text(
                          motivo ??
                              '${etiquetaCategoria(foto.categoria)} · '
                                  '${DateFormat('dd/MM/yyyy').format(foto.fechaToma)}',
                          style: TextStyle(
                            color: cumple ? null : Colors.red.shade400,
                          ),
                        ),
                        trailing: cumple
                            ? const Icon(
                                Icons.check_circle_outline,
                                color: ColoresFotoParada.verde,
                              )
                            : const Icon(Icons.block),
                        onTap: () => Navigator.pop(context, foto),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: OutlinedButton.icon(
              onPressed: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.pushNamed(AppRoutes.upload);
              },
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Subir una foto nueva'),
            ),
          ),
        ],
      ),
    );
  }
}
