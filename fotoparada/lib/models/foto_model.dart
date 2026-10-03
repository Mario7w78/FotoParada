class Foto {
  final int id;
  final String urlImagen;
  final String titulo;
  final double latitud;
  final double longitud;

  // Constructor
  Foto({
    required this.id,
    required this.urlImagen,
    required this.titulo,
    required this.latitud,
    required this.longitud,
  });

  // Factory constructor para crear una instancia de Foto desde un mapa JSON
  factory Foto.fromJson(Map<String, dynamic> json) {
    return Foto(
      id: json['id'],
      urlImagen: json['url_imagen'],
      titulo: json['titulo'],
      // Aseguramos que sea double, incluso si el backend envía un entero (ej: 0 en vez de 0.0)
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
    );
  }
}
