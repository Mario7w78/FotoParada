import 'package:flutter/material.dart';

import '../models/reto_model.dart';
import '../routes/app_routes.dart';
import '../viewmodel/challenges_viewmodel.dart';
import 'widgets/interaccion_widgets.dart';

class ChallengesView extends StatefulWidget {
  const ChallengesView({super.key, this.viewModel});

  /// Permite inyectar un viewmodel en las pruebas.
  final ChallengesViewModel? viewModel;

  @override
  State<ChallengesView> createState() => _ChallengesViewState();
}

class _ChallengesViewState extends State<ChallengesView> {
  late final ChallengesViewModel _viewModel =
      widget.viewModel ?? ChallengesViewModel();

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

  String _etiquetaFiltro(FiltroRetos filtro) {
    switch (filtro) {
      case FiltroRetos.activos:
        return 'Activos';
      case FiltroRetos.mios:
        return 'Creados por mí';
      case FiltroRetos.finalizados:
        return 'Finalizados';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.createChallenge),
        backgroundColor: ColoresFotoParada.azul,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Crear reto'),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) => CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: EncabezadoPantalla(
                  etiqueta: 'Retos fotográficos',
                  titulo: '¿Aceptas el reto de hoy?',
                ),
              ),
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      for (final filtro in FiltroRetos.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChipPildora(
                            etiqueta: _etiquetaFiltro(filtro),
                            seleccionado: _viewModel.filtro == filtro,
                            onSelected: () => _viewModel.cambiarFiltro(filtro),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              ..._construirContenido(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _construirContenido() {
    if (_viewModel.isLoading) {
      return const [
        SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
      ];
    }

    if (_viewModel.errorMessage != null) {
      return [
        SliverFillRemaining(
          child: Center(
            child: MensajeCentrado(
              icono: Icons.error_outline,
              texto: _viewModel.errorMessage!,
              esError: true,
              accion: TextButton(
                onPressed: _viewModel.iniciar,
                child: const Text('Reintentar'),
              ),
            ),
          ),
        ),
      ];
    }

    final retos = _viewModel.retos;
    if (retos.isEmpty) {
      return [
        SliverFillRemaining(
          child: Center(
            child: MensajeCentrado(
              icono: Icons.emoji_events_outlined,
              texto: _viewModel.filtro == FiltroRetos.activos
                  ? 'No hay retos activos. ¡Crea el primero!'
                  : 'No hay retos aquí.',
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        // Deja espacio para que el botón flotante no tape la última tarjeta.
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
        sliver: SliverList.separated(
          itemCount: retos.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) => TarjetaReto(
            reto: retos[index],
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.challengeDetail,
              arguments: retos[index],
            ),
          ),
        ),
      ),
    ];
  }
}

/// Tiempo restante o "Finalizado".
String tiempoRestante(Reto reto, [DateTime? ahora]) {
  final momento = ahora ?? DateTime.now();
  if (reto.fechaFin.isBefore(momento)) return 'Finalizado';
  final restante = reto.fechaFin.difference(momento);
  if (restante.inDays >= 1) {
    return 'Quedan ${restante.inDays} ${restante.inDays == 1 ? 'día' : 'días'}';
  }
  if (restante.inHours >= 1) return 'Quedan ${restante.inHours} h';
  return 'Quedan ${restante.inMinutes} min';
}

/// Etiquetas con las condiciones del reto.
List<Widget> etiquetasCondiciones(Reto reto) {
  return [
    EtiquetaDato(
      icono: iconoCategoria(reto.categoria),
      texto: reto.categoria == null
          ? 'Cualquier categoría'
          : etiquetaCategoria(reto.categoria!),
    ),
    if (reto.tieneUbicacion)
      EtiquetaDato(
        icono: Icons.place_outlined,
        texto: '${formatearDistancia(reto.radioMetros)} de '
            '${reto.nombreLugar.isEmpty ? 'un punto' : reto.nombreLugar}',
        color: ColoresFotoParada.naranja,
      ),
    EtiquetaDato(
      icono: Icons.photo_library_outlined,
      texto: reto.fotosObjetivo == 1 ? '1 foto' : '${reto.fotosObjetivo} fotos',
      color: ColoresFotoParada.verde,
    ),
  ];
}

class TarjetaReto extends StatelessWidget {
  const TarjetaReto({super.key, required this.reto, this.onTap});

  final Reto reto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final activo = reto.estaActivo();
    return TarjetaBlanca(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ColoresFotoParada.azulClaro,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  iconoCategoria(reto.categoria),
                  color: ColoresFotoParada.azul,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  reto.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: ColoresFotoParada.azulOscuro,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: ColoresFotoParada.gris),
            ],
          ),
          if (reto.descripcion.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              reto.descripcion,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ColoresFotoParada.gris),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: etiquetasCondiciones(reto)),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 16,
                color: activo ? ColoresFotoParada.azul : ColoresFotoParada.gris,
              ),
              const SizedBox(width: 4),
              Text(
                tiempoRestante(reto),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color:
                      activo ? ColoresFotoParada.azul : ColoresFotoParada.gris,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  'por ${reto.creadorNombre}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ColoresFotoParada.gris,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
