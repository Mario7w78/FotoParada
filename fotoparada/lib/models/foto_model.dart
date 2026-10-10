class Foto {
  final int id;
  final String urlImagen;
  final String titulo;
  final double latitud;
  final double longitud;

  Foto({
    required this.id,
    required this.urlImagen,
    required this.titulo,
    required this.latitud,
    required this.longitud,
  });

  factory Foto.fromJson(Map<String, dynamic> json) {
    return Foto(
      id: json['id'],
      urlImagen: json['url_imagen'],
      titulo: json['titulo'],
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
    );
  }
}
