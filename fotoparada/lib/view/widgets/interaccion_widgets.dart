import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/foto_model.dart';
import 'foto_widgets.dart';

/// Colores del diseño de Figma usados en las pantallas de interacción.
class ColoresFotoParada {
  ColoresFotoParada._();

  static const Color azul = Color(0xFF3FA9DC);
  static const Color azulClaro = Color(0xFFE3F3FB);
  static const Color azulOscuro = Color(0xFF14304A);
  static const Color gris = Color(0xFF8193A3);
  static const Color borde = Color(0xFFE1EEF5);
  static const Color verde = Color(0xFF2EAD6B);
  static const Color naranja = Color(0xFFF29B38);
}

String etiquetaCategoria(CategoriaFoto categoria) {
  final nombre = categoria.name;
  return '${nombre[0].toUpperCase()}${nombre.substring(1)}';
}

IconData iconoCategoria(CategoriaFoto? categoria) {
  switch (categoria) {
    case CategoriaFoto.naturaleza:
      return Icons.park_outlined;
    case CategoriaFoto.comida:
      return Icons.restaurant_outlined;
    case CategoriaFoto.arte:
      return Icons.palette_outlined;
    case CategoriaFoto.eventos:
      return Icons.celebration_outlined;
    case CategoriaFoto.lugares:
      return Icons.place_outlined;
    case CategoriaFoto.mascotas:
      return Icons.pets_outlined;
    case null:
      return Icons.photo_camera_outlined;
  }
}

/// "hace 5 min", "hace 2 h", "ayer" o la fecha si es más antigua.
String tiempoRelativo(DateTime fecha, [DateTime? ahora]) {
  final diferencia = (ahora ?? DateTime.now()).difference(fecha);
  if (diferencia.inMinutes < 1) return 'ahora';
  if (diferencia.inMinutes < 60) return 'hace ${diferencia.inMinutes} min';
  if (diferencia.inHours < 24) return 'hace ${diferencia.inHours} h';
  if (diferencia.inDays == 1) return 'ayer';
  if (diferencia.inDays < 7) return 'hace ${diferencia.inDays} días';
  return DateFormat('dd/MM/yyyy').format(fecha);
}

String formatearDistancia(double metros) {
  if (metros < 1000) return '${metros.round()} m';
  return '${(metros / 1000).toStringAsFixed(1)} km';
}

/// Cabecera de las pantallas: botón para volver, etiqueta en mayúsculas y
/// título grande, como en la pantalla de inicio.
class EncabezadoPantalla extends StatelessWidget {
  const EncabezadoPantalla({
    super.key,
    required this.etiqueta,
    required this.titulo,
    this.acciones = const [],
    this.mostrarVolver = true,
  });

  final String etiqueta;
  final String titulo;
  final List<Widget> acciones;

  /// false en las pestañas principales, donde no hay a dónde volver.
  final bool mostrarVolver;

  @override
  Widget build(BuildContext context) {
    final puedeVolver = mostrarVolver && Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (puedeVolver || acciones.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  if (puedeVolver)
                    BotonIconoClaro(
                      icono: Icons.arrow_back,
                      tooltip: 'Volver',
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  const Spacer(),
                  ...acciones,
                ],
              ),
            ),
          Text(
            etiqueta.toUpperCase(),
            style: const TextStyle(
              color: ColoresFotoParada.azul,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            titulo,
            style: const TextStyle(
              color: ColoresFotoParada.azulOscuro,
              fontWeight: FontWeight.bold,
              fontSize: 26,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón cuadrado de fondo blanco como el de "mi ubicación" del Figma.
class BotonIconoClaro extends StatelessWidget {
  const BotonIconoClaro({
    super.key,
    required this.icono,
    required this.onPressed,
    this.tooltip,
    this.color = ColoresFotoParada.azulOscuro,
  });

  final IconData icono;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      shadowColor: Colors.black12,
      child: IconButton(
        icon: Icon(icono, color: color),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

class TarjetaBlanca extends StatelessWidget {
  const TarjetaBlanca({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Título de sección con el ícono en un cuadrito celeste ("Descubre cerca de
/// ti" en el Figma).
class EncabezadoSeccion extends StatelessWidget {
  const EncabezadoSeccion({
    super.key,
    required this.icono,
    required this.titulo,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: ColoresFotoParada.azulClaro,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icono, size: 18, color: ColoresFotoParada.azul),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(
              color: ColoresFotoParada.azulOscuro,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        ?accion,
      ],
    );
  }
}

/// Chip con forma de píldora: relleno azul si está elegido y blanco si no,
/// como los filtros de categorías del Figma.
class ChipPildora extends StatelessWidget {
  const ChipPildora({
    super.key,
    required this.etiqueta,
    required this.seleccionado,
    required this.onSelected,
    this.icono,
  });

  final String etiqueta;
  final bool seleccionado;
  final VoidCallback onSelected;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(etiqueta),
      avatar: icono == null
          ? null
          : Icon(
              icono,
              size: 16,
              color: seleccionado ? Colors.white : ColoresFotoParada.gris,
            ),
      selected: seleccionado,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      selectedColor: ColoresFotoParada.azul,
      backgroundColor: Colors.white,
      shape: const StadiumBorder(
        side: BorderSide(color: ColoresFotoParada.borde),
      ),
      labelStyle: TextStyle(
        color: seleccionado ? Colors.white : ColoresFotoParada.azulOscuro,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Etiqueta pequeña para mostrar una condición o dato (categoría, distancia).
class EtiquetaDato extends StatelessWidget {
  const EtiquetaDato({
    super.key,
    required this.icono,
    required this.texto,
    this.color = ColoresFotoParada.azul,
  });

  final IconData icono;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AvatarInicial extends StatelessWidget {
  const AvatarInicial({super.key, required this.nombre, this.radio = 18});

  final String nombre;
  final double radio;

  @override
  Widget build(BuildContext context) {
    final limpio = nombre.trim();
    return CircleAvatar(
      radius: radio,
      backgroundColor: ColoresFotoParada.azulClaro,
      child: Text(
        limpio.isEmpty ? '?' : limpio[0].toUpperCase(),
        style: TextStyle(
          color: ColoresFotoParada.azul,
          fontWeight: FontWeight.bold,
          fontSize: radio * 0.9,
        ),
      ),
    );
  }
}

/// Foto con esquinas redondeadas y degradado oscuro abajo para leer el texto
/// encima, como las tarjetas "El Born" del Figma.
class FotoConDegradado extends StatelessWidget {
  const FotoConDegradado({
    super.key,
    required this.url,
    required this.titulo,
    this.subtitulo = '',
    this.radio = 20,
    this.onTap,
  });

  final String url;
  final String titulo;
  final String subtitulo;
  final double radio;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radio),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImagenFoto(url: url),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xB3000000)],
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                if (subtitulo.isNotEmpty)
                  Text(
                    subtitulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (onTap != null)
            Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onTap),
            ),
        ],
      ),
    );
  }
}

/// Mensaje centrado para estados vacíos o de error, con botón opcional.
class MensajeCentrado extends StatelessWidget {
  const MensajeCentrado({
    super.key,
    required this.icono,
    required this.texto,
    this.accion,
    this.esError = false,
  });

  final IconData icono;
  final String texto;
  final Widget? accion;
  final bool esError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icono,
            size: 56,
            color: esError ? Colors.red.shade300 : ColoresFotoParada.gris,
          ),
          const SizedBox(height: 12),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: esError ? Colors.red : ColoresFotoParada.gris,
            ),
          ),
          if (accion != null) ...[const SizedBox(height: 12), accion!],
        ],
      ),
    );
  }
}
