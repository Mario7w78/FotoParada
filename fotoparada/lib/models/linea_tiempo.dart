import 'foto_model.dart';

/// Integrante 4 - Utilidades puras para la línea de tiempo y la comparación de
/// fotos. No dependen de Flutter ni de Firebase, así se prueban fácilmente.

/// Fotos de un mismo año dentro de la línea de tiempo.
class GrupoAnual {
  const GrupoAnual({required this.anio, required this.fotos});

  final int anio;
  final List<Foto> fotos;
}

/// Ordena [fotos] por fecha de toma y las agrupa por año. Con [ascendente]
/// la más antigua queda primero.
List<GrupoAnual> agruparPorAnio(List<Foto> fotos, {bool ascendente = true}) {
  final ordenadas = ordenarPorFechaToma(fotos, ascendente: ascendente);
  final grupos = <GrupoAnual>[];
  for (final foto in ordenadas) {
    final anio = foto.fechaToma.year;
    if (grupos.isEmpty || grupos.last.anio != anio) {
      grupos.add(GrupoAnual(anio: anio, fotos: [foto]));
    } else {
      grupos.last.fotos.add(foto);
    }
  }
  return grupos;
}

List<Foto> ordenarPorFechaToma(List<Foto> fotos, {bool ascendente = true}) {
  final copia = [...fotos];
  copia.sort((a, b) {
    final porFecha = a.fechaToma.compareTo(b.fechaToma);
    // Desempate estable por id para que el orden no "salte" entre recargas.
    final resultado = porFecha != 0 ? porFecha : a.id.compareTo(b.id);
    return ascendente ? resultado : -resultado;
  });
  return copia;
}

/// Tiempo entre dos fechas en palabras: "2 años y 3 meses", "5 meses",
/// "12 días" o "el mismo día". El orden de los argumentos no importa.
String describirDiferencia(DateTime a, DateTime b) {
  var desde = a.isBefore(b) ? a : b;
  final hasta = a.isBefore(b) ? b : a;

  var meses = (hasta.year - desde.year) * 12 + hasta.month - desde.month;
  if (hasta.day < desde.day) meses--;

  if (meses <= 0) {
    desde = DateTime(desde.year, desde.month, desde.day);
    final dias = DateTime(hasta.year, hasta.month, hasta.day)
        .difference(desde)
        .inDays;
    if (dias <= 0) return 'el mismo día';
    return dias == 1 ? '1 día' : '$dias días';
  }

  final anios = meses ~/ 12;
  final resto = meses % 12;
  final textoAnios = anios == 1 ? '1 año' : '$anios años';
  final textoMeses = resto == 1 ? '1 mes' : '$resto meses';
  if (anios == 0) return textoMeses;
  if (resto == 0) return textoAnios;
  return '$textoAnios y $textoMeses';
}

/// Datos de cabecera de la línea de tiempo de un lugar.
class ResumenLineaTiempo {
  const ResumenLineaTiempo({
    required this.cantidad,
    required this.primera,
    required this.ultima,
  });

  final int cantidad;
  final DateTime primera;
  final DateTime ultima;

  /// Null si no hay fotos.
  static ResumenLineaTiempo? desde(List<Foto> fotos) {
    if (fotos.isEmpty) return null;
    final ordenadas = ordenarPorFechaToma(fotos);
    return ResumenLineaTiempo(
      cantidad: fotos.length,
      primera: ordenadas.first.fechaToma,
      ultima: ordenadas.last.fechaToma,
    );
  }

  String get periodo => describirDiferencia(primera, ultima);
}

/// Par de fotos sugerido para comparar: la más antigua y la más reciente.
/// Null si hay menos de dos fotos.
({Foto antigua, Foto reciente})? parInicialParaComparar(List<Foto> fotos) {
  if (fotos.length < 2) return null;
  final ordenadas = ordenarPorFechaToma(fotos);
  return (antigua: ordenadas.first, reciente: ordenadas.last);
}
