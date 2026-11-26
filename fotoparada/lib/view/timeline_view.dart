import 'package:flutter/material.dart';

import '../models/coleccion_model.dart';
import '../models/foto_model.dart';
import '../models/linea_tiempo.dart';
import '../routes/app_routes.dart';
import '../viewmodel/compare_photos_viewmodel.dart';
import '../viewmodel/timeline_viewmodel.dart';
import 'widgets/foto_widgets.dart';
import 'widgets/interaccion_widgets.dart';
import 'widgets/recuerdos_widgets.dart';

/// Integrante 4 - Línea de tiempo fotográfica de un lugar: cómo se ha visto a
/// lo largo de los años.
class TimelineView extends StatefulWidget {
  const TimelineView({super.key, required this.nombreLugar, this.viewModel});

  final String nombreLugar;

  /// Permite inyectar un viewmodel en las pruebas.
  final TimelineViewModel? viewModel;

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  late final TimelineViewModel _viewModel =
      widget.viewModel ?? TimelineViewModel(nombreLugar: widget.nombreLugar);

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

  void _guardarLugar() {
    final lugar = _viewModel.lugar;
    if (lugar == null) return;
    mostrarGuardarEnColeccion(context, ElementoColeccion.desdeLugar(lugar));
  }

  void _comparar({Foto? antes}) {
    final fotos = _viewModel.fotos;
    Foto? despues;
    if (antes != null) {
      final otras = fotos.where((f) => f.id != antes.id).toList();
      if (otras.isNotEmpty) despues = ordenarPorFechaToma(otras).last;
    }
    Navigator.pushNamed(
      context,
      AppRoutes.comparePhotos,
      arguments: ComparePhotosArgs(
        nombreLugar: widget.nombreLugar,
        fotoAntesId: antes?.id,
        fotoDespuesId: despues?.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) => CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: EncabezadoPantalla(
                  etiqueta: 'Línea de tiempo',
                  titulo: widget.nombreLugar,
                  acciones: [
                    BotonIconoClaro(
                      icono: _viewModel.ascendente
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      tooltip: _viewModel.ascendente
                          ? 'Ver más recientes primero'
                          : 'Ver más antiguas primero',
                      onPressed: _viewModel.alternarOrden,
                    ),
                    const SizedBox(width: 8),
                    BotonIconoClaro(
                      icono: Icons.bookmark_add_outlined,
                      tooltip: 'Guardar lugar',
                      color: ColoresFotoParada.azul,
                      onPressed: _viewModel.lugar == null ? null : _guardarLugar,
                    ),
                  ],
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
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_viewModel.errorMessage != null) {
      return [
        SliverToBoxAdapter(
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
      ];
    }

    final resumen = _viewModel.resumen;
    final grupos = _viewModel.grupos;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (resumen != null) _TarjetaResumen(resumen: resumen),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChipPildora(
                    etiqueta: 'Todas',
                    icono: Icons.public,
                    seleccionado:
                        _viewModel.filtro == FiltroLineaTiempo.todas,
                    onSelected: () =>
                        _viewModel.cambiarFiltro(FiltroLineaTiempo.todas),
                  ),
                  ChipPildora(
                    etiqueta: 'Mis recuerdos',
                    icono: Icons.person_outline,
                    seleccionado: _viewModel.filtro == FiltroLineaTiempo.mias,
                    onSelected: () =>
                        _viewModel.cambiarFiltro(FiltroLineaTiempo.mias),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _viewModel.puedeComparar ? () => _comparar() : null,
                style: FilledButton.styleFrom(
                  backgroundColor: ColoresFotoParada.azul,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.compare),
                label: Text(
                  _viewModel.puedeComparar
                      ? 'Comparar antes y después'
                      : 'Se necesitan 2 fotos para comparar',
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      if (_viewModel.fotos.isEmpty)
        SliverToBoxAdapter(
          child: MensajeCentrado(
            icono: Icons.history_toggle_off,
            texto: _viewModel.filtro == FiltroLineaTiempo.mias
                ? 'Aún no tienes fotos en este lugar.'
                : 'Todavía no hay fotos de este lugar.',
            accion: TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.upload),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Subir una foto'),
            ),
          ),
        )
      else
        for (final grupo in grupos) ...[
          SliverToBoxAdapter(child: _EncabezadoAnio(grupo: grupo)),
          SliverList.builder(
            itemCount: grupo.fotos.length,
            itemBuilder: (context, index) {
              final foto = grupo.fotos[index];
              final esUltimaDelGrupo = index == grupo.fotos.length - 1;
              return _EntradaLineaTiempo(
                key: ValueKey(foto.id),
                foto: foto,
                esMia: _viewModel.esMia(foto),
                dibujarLinea: !(esUltimaDelGrupo && identical(grupo, grupos.last)),
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.photoInteractions,
                  arguments: foto,
                ),
                onComparar:
                    _viewModel.puedeComparar ? () => _comparar(antes: foto) : null,
                onGuardar: () => mostrarGuardarEnColeccion(
                  context,
                  ElementoColeccion.desdeFoto(foto),
                ),
              );
            },
          ),
        ],
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ];
  }
}

class _TarjetaResumen extends StatelessWidget {
  const _TarjetaResumen({required this.resumen});

  final ResumenLineaTiempo resumen;

  @override
  Widget build(BuildContext context) {
    final mismoAnio = resumen.primera.year == resumen.ultima.year;
    return TarjetaBlanca(
      child: Row(
        children: [
          _Dato(
            valor: '${resumen.cantidad}',
            etiqueta: resumen.cantidad == 1 ? 'foto' : 'fotos',
          ),
          const _Separador(),
          _Dato(
            valor: mismoAnio
                ? '${resumen.primera.year}'
                : '${resumen.primera.year}–${resumen.ultima.year}',
            etiqueta: 'periodo',
          ),
          const _Separador(),
          Expanded(
            child: _Dato(valor: resumen.periodo, etiqueta: 'de recuerdos'),
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.valor, required this.etiqueta});

  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          valor,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: ColoresFotoParada.azulOscuro,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        Text(
          etiqueta,
          style: const TextStyle(color: ColoresFotoParada.gris, fontSize: 12),
        ),
      ],
    );
  }
}

class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: ColoresFotoParada.borde,
    );
  }
}

class _EncabezadoAnio extends StatelessWidget {
  const _EncabezadoAnio({required this.grupo});

  final GrupoAnual grupo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: ColoresFotoParada.azulOscuro,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${grupo.anio}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            grupo.fotos.length == 1 ? '1 foto' : '${grupo.fotos.length} fotos',
            style: const TextStyle(color: ColoresFotoParada.gris),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: ColoresFotoParada.borde)),
        ],
      ),
    );
  }
}

/// Un punto de la línea: riel con un círculo a la izquierda y la tarjeta de la
/// foto a la derecha.
class _EntradaLineaTiempo extends StatelessWidget {
  const _EntradaLineaTiempo({
    super.key,
    required this.foto,
    required this.esMia,
    required this.dibujarLinea,
    required this.onTap,
    required this.onComparar,
    required this.onGuardar,
  });

  final Foto foto;
  final bool esMia;
  final bool dibujarLinea;
  final VoidCallback onTap;
  final VoidCallback? onComparar;
  final VoidCallback onGuardar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 52,
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  Text(
                    formatearDiaMes(foto.fechaToma),
                    style: const TextStyle(
                      color: ColoresFotoParada.azulOscuro,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: esMia
                          ? ColoresFotoParada.naranja
                          : ColoresFotoParada.azul,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [
                        BoxShadow(color: Color(0x22000000), blurRadius: 4),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      color: dibujarLinea
                          ? ColoresFotoParada.borde
                          : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TarjetaBlanca(
                  padding: const EdgeInsets.all(8),
                  onTap: onTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 10,
                        child: FotoConDegradado(
                          url: foto.urlImagen.isNotEmpty
                              ? foto.urlImagen
                              : foto.urlMiniatura,
                          titulo: foto.titulo.isEmpty ? 'Sin título' : foto.titulo,
                          subtitulo: formatearFecha(foto.fechaToma),
                          radio: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const SizedBox(width: 4),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: esMia
                                  ? EtiquetaDato(
                                      icono: iconoPrivacidad(foto.privacidad),
                                      texto:
                                          'Tuya · ${etiquetaPrivacidad(foto.privacidad)}',
                                      color: ColoresFotoParada.naranja,
                                    )
                                  : EtiquetaDato(
                                      icono: iconoCategoria(foto.categoria),
                                      texto: etiquetaCategoria(foto.categoria),
                                    ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Comparar con la más reciente',
                            visualDensity: VisualDensity.compact,
                            onPressed: onComparar,
                            icon: const Icon(
                              Icons.compare,
                              color: ColoresFotoParada.gris,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Guardar en colección',
                            visualDensity: VisualDensity.compact,
                            onPressed: onGuardar,
                            icon: const Icon(
                              Icons.bookmark_add_outlined,
                              color: ColoresFotoParada.gris,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
