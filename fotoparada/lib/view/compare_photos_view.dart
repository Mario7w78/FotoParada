import 'package:flutter/material.dart';

import '../models/foto_model.dart';
import '../routes/app_routes.dart';
import '../viewmodel/compare_photos_viewmodel.dart';
import 'widgets/foto_widgets.dart';
import 'widgets/interaccion_widgets.dart';
import 'widgets/recuerdos_widgets.dart';

/// Integrante 4 - Comparar una foto antigua con una reciente del mismo lugar,
/// con un deslizador "antes / después" o lado a lado.
class ComparePhotosView extends StatefulWidget {
  const ComparePhotosView({super.key, required this.args, this.viewModel});

  final ComparePhotosArgs args;

  /// Permite inyectar un viewmodel en las pruebas.
  final ComparePhotosViewModel? viewModel;

  @override
  State<ComparePhotosView> createState() => _ComparePhotosViewState();
}

class _ComparePhotosViewState extends State<ComparePhotosView> {
  late final ComparePhotosViewModel _viewModel =
      widget.viewModel ?? ComparePhotosViewModel(args: widget.args);

  static const Color _colorAntes = ColoresFotoParada.naranja;
  static const Color _colorDespues = ColoresFotoParada.azul;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              EncabezadoPantalla(
                etiqueta: 'Comparar épocas',
                titulo: _viewModel.nombreLugar,
                acciones: [
                  BotonIconoClaro(
                    icono: Icons.swap_horiz,
                    tooltip: 'Intercambiar',
                    onPressed:
                        _viewModel.puedeComparar ? _viewModel.intercambiar : null,
                  ),
                ],
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
    if (_viewModel.fotos.length < 2 || !_viewModel.puedeComparar) {
      return [
        MensajeCentrado(
          icono: Icons.compare_outlined,
          texto: 'Se necesitan al menos 2 fotos de este lugar para comparar '
              'cómo ha cambiado.',
          accion: TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.upload),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Subir una foto'),
          ),
        ),
      ];
    }

    final antes = _viewModel.antes!;
    final despues = _viewModel.despues!;
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<ModoComparacion>(
              segments: const [
                ButtonSegment(
                  value: ModoComparacion.deslizador,
                  icon: Icon(Icons.compare),
                  label: Text('Deslizador'),
                ),
                ButtonSegment(
                  value: ModoComparacion.ladoALado,
                  icon: Icon(Icons.view_column_outlined),
                  label: Text('Lado a lado'),
                ),
              ],
              selected: {_viewModel.modo},
              onSelectionChanged: (seleccion) =>
                  _viewModel.cambiarModo(seleccion.first),
            ),
            const SizedBox(height: 16),
            if (_viewModel.modo == ModoComparacion.deslizador)
              _Deslizador(
                antes: antes,
                despues: despues,
                posicion: _viewModel.posicion,
                onCambio: _viewModel.moverDeslizador,
                colorAntes: _colorAntes,
                colorDespues: _colorDespues,
              )
            else
              _LadoALado(
                antes: antes,
                despues: despues,
                colorAntes: _colorAntes,
                colorDespues: _colorDespues,
              ),
            const SizedBox(height: 16),
            _TarjetaDiferencia(
              antes: antes,
              despues: despues,
              diferencia: _viewModel.diferencia,
              ordenInvertido: _viewModel.ordenInvertido,
            ),
            const SizedBox(height: 24),
            const EncabezadoSeccion(
              icono: Icons.photo_library_outlined,
              titulo: 'Elige las fotos',
            ),
            const SizedBox(height: 12),
            SegmentedButton<LadoComparacion>(
              segments: const [
                ButtonSegment(
                  value: LadoComparacion.antes,
                  label: Text('Cambiar "Antes"'),
                ),
                ButtonSegment(
                  value: LadoComparacion.despues,
                  label: Text('Cambiar "Después"'),
                ),
              ],
              selected: {_viewModel.ladoActivo},
              onSelectionChanged: (seleccion) =>
                  _viewModel.cambiarLadoActivo(seleccion.first),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      SizedBox(
        height: 118,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _viewModel.fotos.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final foto = _viewModel.fotos[index];
            final Color? color = foto.id == antes.id
                ? _colorAntes
                : foto.id == despues.id
                    ? _colorDespues
                    : null;
            return _MiniaturaSeleccionable(
              key: ValueKey(foto.id),
              foto: foto,
              color: color,
              onTap: () => _viewModel.elegir(foto),
            );
          },
        ),
      ),
    ];
  }
}

/// Las dos fotos encimadas: a la izquierda de la línea se ve "antes" y a la
/// derecha "después". Se arrastra para revelar una u otra.
class _Deslizador extends StatelessWidget {
  const _Deslizador({
    required this.antes,
    required this.despues,
    required this.posicion,
    required this.onCambio,
    required this.colorAntes,
    required this.colorDespues,
  });

  final Foto antes;
  final Foto despues;
  final double posicion;
  final ValueChanged<double> onCambio;
  final Color colorAntes;
  final Color colorDespues;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final ancho = constraints.maxWidth;
            void actualizar(Offset local) => onCambio(local.dx / ancho);
            return GestureDetector(
              onHorizontalDragUpdate: (d) => actualizar(d.localPosition),
              onTapDown: (d) => actualizar(d.localPosition),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ImagenFoto(url: despues.urlImagen),
                  ClipRect(
                    clipper: _RecorteIzquierdo(posicion),
                    child: ImagenFoto(url: antes.urlImagen),
                  ),
                  Positioned(
                    left: ancho * posicion - 1.5,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 3, color: Colors.white),
                  ),
                  Positioned(
                    left: ancho * posicion - 20,
                    top: 0,
                    bottom: 0,
                    child: const Center(
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.code,
                          color: ColoresFotoParada.azulOscuro,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _EtiquetaEpoca(
                      texto: 'ANTES · ${antes.fechaToma.year}',
                      color: colorAntes,
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: _EtiquetaEpoca(
                      texto: 'DESPUÉS · ${despues.fechaToma.year}',
                      color: colorDespues,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RecorteIzquierdo extends CustomClipper<Rect> {
  _RecorteIzquierdo(this.fraccion);

  final double fraccion;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraccion, size.height);

  @override
  bool shouldReclip(_RecorteIzquierdo oldClipper) =>
      oldClipper.fraccion != fraccion;
}

class _LadoALado extends StatelessWidget {
  const _LadoALado({
    required this.antes,
    required this.despues,
    required this.colorAntes,
    required this.colorDespues,
  });

  final Foto antes;
  final Foto despues;
  final Color colorAntes;
  final Color colorDespues;

  Widget _lado(Foto foto, String etiqueta, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ImagenFoto(url: foto.urlImagen),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: _EtiquetaEpoca(texto: etiqueta, color: color),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatearFecha(foto.fechaToma),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ColoresFotoParada.azulOscuro,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _lado(antes, 'ANTES', colorAntes),
        const SizedBox(width: 10),
        _lado(despues, 'DESPUÉS', colorDespues),
      ],
    );
  }
}

class _EtiquetaEpoca extends StatelessWidget {
  const _EtiquetaEpoca({required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _TarjetaDiferencia extends StatelessWidget {
  const _TarjetaDiferencia({
    required this.antes,
    required this.despues,
    required this.diferencia,
    required this.ordenInvertido,
  });

  final Foto antes;
  final Foto despues;
  final String diferencia;
  final bool ordenInvertido;

  @override
  Widget build(BuildContext context) {
    return TarjetaBlanca(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hourglass_bottom, color: ColoresFotoParada.azul),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  diferencia == 'el mismo día'
                      ? 'Ambas fotos son del mismo día'
                      : '$diferencia entre ambas fotos',
                  style: const TextStyle(
                    color: ColoresFotoParada.azulOscuro,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Antes: ${formatearFecha(antes.fechaToma)}\n'
            'Después: ${formatearFecha(despues.fechaToma)}',
            style: const TextStyle(color: ColoresFotoParada.gris),
          ),
          if (ordenInvertido) ...[
            const SizedBox(height: 8),
            const Text(
              'La foto "Antes" es más reciente que la de "Después". Toca ⇄ '
              'para intercambiarlas.',
              style: TextStyle(color: ColoresFotoParada.naranja),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniaturaSeleccionable extends StatelessWidget {
  const _MiniaturaSeleccionable({
    super.key,
    required this.foto,
    required this.color,
    required this.onTap,
  });

  final Foto foto;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 84,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 84,
              height: 84,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: color ?? Colors.transparent,
                  width: 3,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ImagenFoto(
                  url: foto.urlMiniatura.isNotEmpty
                      ? foto.urlMiniatura
                      : foto.urlImagen,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatearMesAnio(foto.fechaToma),
              style: TextStyle(
                fontSize: 12,
                fontWeight: color != null ? FontWeight.bold : FontWeight.normal,
                color: color ?? ColoresFotoParada.gris,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
