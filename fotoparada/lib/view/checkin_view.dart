import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../models/checkin_model.dart';
import '../routes/app_routes.dart';
import '../viewmodel/checkin_viewmodel.dart';
import 'widgets/interaccion_widgets.dart';
import 'widgets/mapa_punto.dart';

/// Valida con el GPS que el usuario está en [lugar] y, una vez validado, le
/// permite subir una foto desde ahí. Sin [lugar] muestra solo el historial.
class CheckInView extends StatefulWidget {
  const CheckInView({super.key, this.lugar, this.viewModel});

  final LugarCheckIn? lugar;

  /// Permite inyectar un viewmodel en las pruebas.
  final CheckInViewModel? viewModel;

  @override
  State<CheckInView> createState() => _CheckInViewState();
}

class _CheckInViewState extends State<CheckInView> {
  late final CheckInViewModel _viewModel =
      widget.viewModel ?? CheckInViewModel(lugar: widget.lugar);

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

  Future<void> _hacerCheckIn() async {
    final exito = await _viewModel.hacerCheckIn();
    if (!mounted) return;
    if (exito) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Check-in validado!')),
      );
    } else if (_viewModel.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_viewModel.errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lugar = widget.lugar;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) => ListView(
            children: [
              EncabezadoPantalla(
                etiqueta: 'Check-in fotográfico',
                titulo: lugar == null ? 'Mis check-ins' : lugar.nombre,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (lugar != null) ...[
                      MapaPunto(
                        punto: LatLng(lugar.latitud, lugar.longitud),
                        radioMetros: _viewModel.radioMetros,
                        zoom: 15.5,
                      ),
                      const SizedBox(height: 16),
                      _construirEstado(),
                      const SizedBox(height: 24),
                    ],
                    _construirHistorial(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirEstado() {
    final distancia = _viewModel.distanciaMetros;
    final radio = formatearDistancia(_viewModel.radioMetros);

    final IconData icono;
    final Color color;
    final String titulo;
    final String detalle;

    switch (_viewModel.estado) {
      case EstadoCheckIn.pendiente:
        icono = Icons.my_location;
        color = ColoresFotoParada.azul;
        titulo = 'Valida que estás aquí';
        detalle =
            'Acércate a menos de $radio del punto y toca "Hacer check-in". '
            'Así desbloqueas subir una foto desde este lugar.';
      case EstadoCheckIn.verificando:
        icono = Icons.gps_fixed;
        color = ColoresFotoParada.azul;
        titulo = 'Verificando tu ubicación...';
        detalle = 'Esto puede tardar unos segundos.';
      case EstadoCheckIn.fueraDeRango:
        icono = Icons.wrong_location_outlined;
        color = ColoresFotoParada.naranja;
        titulo = 'Aún no estás en el lugar';
        detalle = 'Estás a ${formatearDistancia(distancia ?? 0)}. '
            'Acércate a menos de $radio e intenta de nuevo.';
      case EstadoCheckIn.validado:
        icono = Icons.verified;
        color = ColoresFotoParada.verde;
        titulo = '¡Check-in validado!';
        detalle = distancia == null
            ? 'Ya hiciste check-in aquí hoy. Ya puedes subir tu foto.'
            : 'Estás a ${formatearDistancia(distancia)}. '
                'Ya puedes subir tu foto desde este lugar.';
    }

    final verificando = _viewModel.estado == EstadoCheckIn.verificando;
    final validado = _viewModel.estado == EstadoCheckIn.validado;

    return TarjetaBlanca(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: verificando
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      )
                    : Icon(icono, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(detalle, style: const TextStyle(color: ColoresFotoParada.gris)),
          const SizedBox(height: 16),
          if (validado)
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.upload),
              style: FilledButton.styleFrom(
                backgroundColor: ColoresFotoParada.verde,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Subir foto aquí'),
            )
          else
            FilledButton.icon(
              onPressed: verificando ? null : _hacerCheckIn,
              style: FilledButton.styleFrom(
                backgroundColor: ColoresFotoParada.azul,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.where_to_vote),
              label: Text(
                _viewModel.estado == EstadoCheckIn.fueraDeRango
                    ? 'Volver a intentar'
                    : 'Hacer check-in',
              ),
            ),
        ],
      ),
    );
  }

  Widget _construirHistorial() {
    final historial = _viewModel.historial;
    final lugaresUnicos = historial.map((c) => c.nombreLugar).toSet().length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EncabezadoSeccion(
          icono: Icons.history,
          titulo: 'Historial',
          accion: historial.isEmpty
              ? null
              : Text(
                  '$lugaresUnicos ${lugaresUnicos == 1 ? 'lugar' : 'lugares'}',
                  style: const TextStyle(
                    color: ColoresFotoParada.azul,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        const SizedBox(height: 12),
        if (_viewModel.isLoadingHistorial)
          const Center(child: CircularProgressIndicator())
        else if (_viewModel.errorHistorial != null)
          MensajeCentrado(
            icono: Icons.error_outline,
            texto: _viewModel.errorHistorial!,
            esError: true,
            accion: TextButton(
              onPressed: _viewModel.iniciar,
              child: const Text('Reintentar'),
            ),
          )
        else if (historial.isEmpty)
          const MensajeCentrado(
            icono: Icons.where_to_vote_outlined,
            texto: 'Todavía no has hecho check-in en ningún lugar.',
          )
        else
          for (final checkIn in historial)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TarjetaCheckIn(checkIn: checkIn),
            ),
      ],
    );
  }
}

class _TarjetaCheckIn extends StatelessWidget {
  const _TarjetaCheckIn({required this.checkIn});

  final CheckIn checkIn;

  @override
  Widget build(BuildContext context) {
    return TarjetaBlanca(
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.checkIn,
        arguments: LugarCheckIn(
          nombre: checkIn.nombreLugar,
          latitud: checkIn.latitud,
          longitud: checkIn.longitud,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ColoresFotoParada.verde.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.verified, color: ColoresFotoParada.verde),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  checkIn.nombreLugar.isEmpty
                      ? 'Lugar sin nombre'
                      : checkIn.nombreLugar,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ColoresFotoParada.azulOscuro,
                  ),
                ),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(checkIn.fecha),
                  style: const TextStyle(
                    color: ColoresFotoParada.gris,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: ColoresFotoParada.gris),
        ],
      ),
    );
  }
}
