import 'package:flutter/material.dart';

import '../../models/coleccion_model.dart';
import '../../viewmodel/save_to_collection_viewmodel.dart';
import 'foto_widgets.dart';
import 'interaccion_widgets.dart';

/// Integrante 4 - Widgets compartidos de recuerdos y colecciones.

IconData iconoColeccion(TipoColeccion tipo) {
  switch (tipo) {
    case TipoColeccion.quieroVisitar:
      return Icons.flag_outlined;
    case TipoColeccion.misViajes:
      return Icons.luggage_outlined;
    case TipoColeccion.personalizada:
      return Icons.collections_bookmark_outlined;
  }
}

Color colorColeccion(TipoColeccion tipo) {
  switch (tipo) {
    case TipoColeccion.quieroVisitar:
      return ColoresFotoParada.naranja;
    case TipoColeccion.misViajes:
      return ColoresFotoParada.verde;
    case TipoColeccion.personalizada:
      return ColoresFotoParada.azul;
  }
}

String textoCantidad(int cantidad) =>
    cantidad == 1 ? '1 elemento' : '$cantidad elementos';

const List<String> _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', //
  'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// "5 de marzo de 2024". Sin depender de que intl cargue el locale.
String formatearFecha(DateTime fecha) =>
    '${fecha.day} de ${_meses[fecha.month - 1]} de ${fecha.year}';

/// "mar 2024".
String formatearMesAnio(DateTime fecha) =>
    '${_meses[fecha.month - 1].substring(0, 3)} ${fecha.year}';

/// "5 mar".
String formatearDiaMes(DateTime fecha) =>
    '${fecha.day} ${_meses[fecha.month - 1].substring(0, 3)}';

/// Portada cuadrada de una colección: su última imagen o, si no tiene, el
/// ícono de su tipo sobre fondo de color.
class PortadaColeccion extends StatelessWidget {
  const PortadaColeccion({
    super.key,
    required this.coleccion,
    this.tamano = 56,
  });

  final Coleccion coleccion;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final color = colorColeccion(coleccion.tipo);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: tamano,
        height: tamano,
        child: coleccion.portadaUrl.isNotEmpty
            ? ImagenFoto(url: coleccion.portadaUrl)
            : ColoredBox(
                color: color.withValues(alpha: 0.12),
                child: Icon(
                  iconoColeccion(coleccion.tipo),
                  color: color,
                  size: tamano * 0.45,
                ),
              ),
      ),
    );
  }
}

/// Pide nombre y descripción. Devuelve null si se cancela.
Future<({String nombre, String descripcion})?> pedirDatosColeccion(
  BuildContext context, {
  String titulo = 'Nueva colección',
  String nombre = '',
  String descripcion = '',
  bool conDescripcion = true,
}) {
  return showDialog<({String nombre, String descripcion})>(
    context: context,
    builder: (context) => _DialogoColeccion(
      titulo: titulo,
      nombreInicial: nombre,
      descripcionInicial: descripcion,
      conDescripcion: conDescripcion,
    ),
  );
}

class _DialogoColeccion extends StatefulWidget {
  const _DialogoColeccion({
    required this.titulo,
    required this.nombreInicial,
    required this.descripcionInicial,
    required this.conDescripcion,
  });

  final String titulo;
  final String nombreInicial;
  final String descripcionInicial;
  final bool conDescripcion;

  @override
  State<_DialogoColeccion> createState() => _DialogoColeccionState();
}

class _DialogoColeccionState extends State<_DialogoColeccion> {
  late final _nombre = TextEditingController(text: widget.nombreInicial);
  late final _descripcion =
      TextEditingController(text: widget.descripcionInicial);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  void _aceptar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      (nombre: _nombre.text.trim(), descripcion: _descripcion.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nombre,
              autofocus: true,
              maxLength: Coleccion.largoMaximoNombre,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej. Cafés favoritos',
              ),
              validator: (valor) => (valor ?? '').trim().isEmpty
                  ? 'Escribe un nombre.'
                  : null,
              onFieldSubmitted: (_) => _aceptar(),
            ),
            if (widget.conDescripcion)
              TextFormField(
                controller: _descripcion,
                maxLength: Coleccion.largoMaximoDescripcion,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _aceptar, child: const Text('Guardar')),
      ],
    );
  }
}

/// Pide una nota corta para un elemento guardado. Null si se cancela.
Future<String?> pedirNota(BuildContext context, String notaActual) {
  return showDialog<String>(
    context: context,
    builder: (context) => _DialogoNota(notaInicial: notaActual),
  );
}

/// El diálogo es dueño del controlador: así se libera cuando sale de pantalla,
/// no mientras todavía se está cerrando.
class _DialogoNota extends StatefulWidget {
  const _DialogoNota({required this.notaInicial});

  final String notaInicial;

  @override
  State<_DialogoNota> createState() => _DialogoNotaState();
}

class _DialogoNotaState extends State<_DialogoNota> {
  late final _controller = TextEditingController(text: widget.notaInicial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nota personal'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: ElementoColeccion.largoMaximoNota,
        maxLines: 3,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Ej. Ir al atardecer, probar el ceviche...',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Abre la hoja para guardar [elemento] (una foto o un lugar) en una o más
/// colecciones. Se usa desde el detalle de una foto, el de un lugar y la línea
/// de tiempo.
Future<void> mostrarGuardarEnColeccion(
  BuildContext context,
  ElementoColeccion elemento, {
  SaveToCollectionViewModel? viewModel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) =>
        _HojaGuardar(elemento: elemento, viewModel: viewModel),
  );
}

class _HojaGuardar extends StatefulWidget {
  const _HojaGuardar({required this.elemento, this.viewModel});

  final ElementoColeccion elemento;
  final SaveToCollectionViewModel? viewModel;

  @override
  State<_HojaGuardar> createState() => _HojaGuardarState();
}

class _HojaGuardarState extends State<_HojaGuardar> {
  late final SaveToCollectionViewModel _viewModel =
      widget.viewModel ?? SaveToCollectionViewModel(elemento: widget.elemento);

  @override
  void initState() {
    super.initState();
    _viewModel.cargar();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _nuevaColeccion() async {
    final datos = await pedirDatosColeccion(context, conDescripcion: false);
    if (datos == null || !mounted) return;
    await _viewModel.crearYGuardar(datos.nombre);
  }

  @override
  Widget build(BuildContext context) {
    final elemento = widget.elemento;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 48,
                        height: 48,
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
                            elemento.esFoto ? 'Guardar foto' : 'Guardar lugar',
                            style: const TextStyle(
                              color: ColoresFotoParada.azul,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            elemento.titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ColoresFotoParada.azulOscuro,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(child: _construirLista()),
              if (_viewModel.errorAccion != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Text(
                    _viewModel.errorAccion!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: ColoresFotoParada.azul,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Listo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirLista() {
    if (_viewModel.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_viewModel.errorMessage != null) {
      return MensajeCentrado(
        icono: Icons.error_outline,
        texto: _viewModel.errorMessage!,
        esError: true,
        accion: TextButton(
          onPressed: _viewModel.cargar,
          child: const Text('Reintentar'),
        ),
      );
    }
    return ListView(
      shrinkWrap: true,
      children: [
        for (final coleccion in _viewModel.colecciones)
          CheckboxListTile(
            key: ValueKey(coleccion.id),
            value: _viewModel.estaGuardadoEn(coleccion),
            onChanged: _viewModel.estaOcupada(coleccion)
                ? null
                : (_) => _viewModel.alternar(coleccion),
            secondary: PortadaColeccion(coleccion: coleccion, tamano: 44),
            title: Text(
              coleccion.nombre,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(textoCantidad(coleccion.cantidad)),
            activeColor: ColoresFotoParada.azul,
          ),
        ListTile(
          leading: const CircleAvatar(
            backgroundColor: ColoresFotoParada.azulClaro,
            child: Icon(Icons.add, color: ColoresFotoParada.azul),
          ),
          title: const Text(
            'Nueva colección',
            style: TextStyle(
              color: ColoresFotoParada.azul,
              fontWeight: FontWeight.w600,
            ),
          ),
          onTap: _nuevaColeccion,
        ),
      ],
    );
  }
}
