import 'package:cloud_firestore/cloud_firestore.dart';

enum CategoriaFoto { naturaleza, comida, arte, eventos, lugares, mascotas }

enum PrivacidadFoto { publica, amigos, privada }

class Foto {
  final String id;
  final String uid;
  final String urlImagen;
  final String rutaStorage;
  final String titulo;
  final String descripcion;
  final CategoriaFoto categoria;
  final double latitud;
  final double longitud;
  final String nombreLugar;
  final DateTime fechaToma;
  final DateTime fechaSubida;
  final PrivacidadFoto privacidad;
  final int likes;

  Foto({
    required this.id,
    required this.uid,
    required this.urlImagen,
    required this.rutaStorage,
    required this.titulo,
    required this.descripcion,
    required this.categoria,
    required this.latitud,
    required this.longitud,
    required this.nombreLugar,
    required this.fechaToma,
    required this.fechaSubida,
    required this.privacidad,
    this.likes = 0,
  });

  /// Foto que proviene de una API externa y no de Firestore, por lo que solo
  /// trae imagen, título y coordenadas. El resto de campos son de relleno.
  factory Foto.externa({
    required String id,
    required String urlImagen,
    required String titulo,
    required double latitud,
    required double longitud,
  }) {
    final ahora = DateTime.now();
    return Foto(
      id: id,
      uid: '',
      urlImagen: urlImagen,
      rutaStorage: '',
      titulo: titulo,
      descripcion: '',
      categoria: CategoriaFoto.lugares,
      latitud: latitud,
      longitud: longitud,
      nombreLugar: '',
      fechaToma: ahora,
      fechaSubida: ahora,
      privacidad: PrivacidadFoto.publica,
    );
  }

  factory Foto.fromJson(Map<String, dynamic> json) {
    return Foto.externa(
      id: json['id'].toString(),
      urlImagen: json['url_imagen'],
      titulo: json['titulo'],
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
    );
  }

  factory Foto.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Foto.fromMap(doc.id, doc.data() ?? const {});
  }

  factory Foto.fromMap(String id, Map<String, dynamic> data) {
    return Foto(
      id: id,
      uid: data['uid'] as String? ?? '',
      urlImagen: data['urlImagen'] as String? ?? '',
      rutaStorage: data['rutaStorage'] as String? ?? '',
      titulo: data['titulo'] as String? ?? '',
      descripcion: data['descripcion'] as String? ?? '',
      categoria: CategoriaFoto.values.asNameMap()[data['categoria']] ??
          CategoriaFoto.lugares,
      latitud: (data['latitud'] as num?)?.toDouble() ?? 0.0,
      longitud: (data['longitud'] as num?)?.toDouble() ?? 0.0,
      nombreLugar: data['nombreLugar'] as String? ?? '',
      fechaToma: (data['fechaToma'] as Timestamp?)?.toDate() ?? DateTime.now(),
      // Es nulo mientras el servidor no confirma el serverTimestamp de una
      // subida recién hecha.
      fechaSubida:
          (data['fechaSubida'] as Timestamp?)?.toDate() ?? DateTime.now(),
      // Un valor desconocido nunca debe volver pública una foto.
      privacidad: PrivacidadFoto.values.asNameMap()[data['privacidad']] ??
          PrivacidadFoto.privada,
      likes: (data['likes'] as num?)?.toInt() ?? 0,
    );
  }

  /// El id no se incluye porque es el id del documento en Firestore.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'urlImagen': urlImagen,
      'rutaStorage': rutaStorage,
      'titulo': titulo,
      'descripcion': descripcion,
      'categoria': categoria.name,
      'latitud': latitud,
      'longitud': longitud,
      'nombreLugar': nombreLugar,
      'fechaToma': Timestamp.fromDate(fechaToma),
      'fechaSubida': Timestamp.fromDate(fechaSubida),
      'privacidad': privacidad.name,
      'likes': likes,
    };
  }

  Foto copyWith({
    String? id,
    String? uid,
    String? urlImagen,
    String? rutaStorage,
    String? titulo,
    String? descripcion,
    CategoriaFoto? categoria,
    double? latitud,
    double? longitud,
    String? nombreLugar,
    DateTime? fechaToma,
    DateTime? fechaSubida,
    PrivacidadFoto? privacidad,
    int? likes,
  }) {
    return Foto(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      urlImagen: urlImagen ?? this.urlImagen,
      rutaStorage: rutaStorage ?? this.rutaStorage,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      categoria: categoria ?? this.categoria,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      nombreLugar: nombreLugar ?? this.nombreLugar,
      fechaToma: fechaToma ?? this.fechaToma,
      fechaSubida: fechaSubida ?? this.fechaSubida,
      privacidad: privacidad ?? this.privacidad,
      likes: likes ?? this.likes,
    );
  }
}
