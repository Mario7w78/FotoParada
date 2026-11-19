import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import 'foto_model.dart';

/// Reto fotográfico. Se guarda en la colección `retos`. Las condiciones son
/// opcionales: un reto sin categoría acepta cualquiera y uno sin ubicación
/// acepta fotos de cualquier lugar.
class Reto {
  final String id;
  final String creadorUid;
  final String creadorNombre;
  final String titulo;
  final String descripcion;
  final CategoriaFoto? categoria;
  final double? latitud;
  final double? longitud;
  final String nombreLugar;
  final double radioMetros;

  /// Cantidad de fotos que hay que enviar para completar el reto.
  final int fotosObjetivo;
  final DateTime fechaInicio;
  final DateTime fechaFin;

  Reto({
    required this.id,
    required this.creadorUid,
    required this.creadorNombre,
    required this.titulo,
    required this.descripcion,
    this.categoria,
    this.latitud,
    this.longitud,
    this.nombreLugar = '',
    this.radioMetros = radioPorDefecto,
    this.fotosObjetivo = 1,
    required this.fechaInicio,
    required this.fechaFin,
  });

  static const double radioPorDefecto = 200;

  bool get tieneUbicacion => latitud != null && longitud != null;

  bool estaActivo([DateTime? ahora]) {
    final momento = ahora ?? DateTime.now();
    return !momento.isBefore(fechaInicio) && !momento.isAfter(fechaFin);
  }

  /// Devuelve por qué [foto] no sirve para este reto, o null si cumple todas
  /// las condiciones.
  String? motivoNoCumple(Foto foto) {
    if (foto.privacidad != PrivacidadFoto.publica) {
      return 'La foto debe ser pública para que los demás la vean.';
    }
    if (categoria != null && foto.categoria != categoria) {
      return 'Debe ser de la categoría ${categoria!.name}.';
    }
    if (foto.fechaToma.isBefore(fechaInicio) ||
        foto.fechaToma.isAfter(fechaFin)) {
      return 'Debe haberse tomado mientras el reto estaba activo.';
    }
    if (tieneUbicacion) {
      final distancia = const Distance().as(
        LengthUnit.Meter,
        LatLng(latitud!, longitud!),
        LatLng(foto.latitud, foto.longitud),
      );
      if (distancia > radioMetros) {
        return 'Debe tomarse a menos de ${radioMetros.round()} m del lugar.';
      }
    }
    return null;
  }

  factory Reto.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Reto.fromMap(doc.id, doc.data() ?? const {});
  }

  factory Reto.fromMap(String id, Map<String, dynamic> data) {
    final ahora = DateTime.now();
    return Reto(
      id: id,
      creadorUid: data['creadorUid'] as String? ?? '',
      creadorNombre: data['creadorNombre'] as String? ?? '',
      titulo: data['titulo'] as String? ?? '',
      descripcion: data['descripcion'] as String? ?? '',
      categoria: CategoriaFoto.values.asNameMap()[data['categoria']],
      latitud: (data['latitud'] as num?)?.toDouble(),
      longitud: (data['longitud'] as num?)?.toDouble(),
      nombreLugar: data['nombreLugar'] as String? ?? '',
      radioMetros:
          (data['radioMetros'] as num?)?.toDouble() ?? radioPorDefecto,
      fotosObjetivo: (data['fotosObjetivo'] as num?)?.toInt() ?? 1,
      fechaInicio: (data['fechaInicio'] as Timestamp?)?.toDate() ?? ahora,
      fechaFin: (data['fechaFin'] as Timestamp?)?.toDate() ?? ahora,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'creadorUid': creadorUid,
      'creadorNombre': creadorNombre,
      'titulo': titulo,
      'descripcion': descripcion,
      'categoria': categoria?.name,
      'latitud': latitud,
      'longitud': longitud,
      'nombreLugar': nombreLugar,
      'radioMetros': radioMetros,
      'fotosObjetivo': fotosObjetivo,
      'fechaInicio': Timestamp.fromDate(fechaInicio),
      'fechaFin': Timestamp.fromDate(fechaFin),
    };
  }
}

/// Avance de un usuario en un reto. Se guarda en
/// `retos/{retoId}/participantes/{uid}`.
class ParticipacionReto {
  final String uid;
  final String nombreUsuario;
  final List<String> fotoIds;
  final DateTime fechaActualizacion;

  ParticipacionReto({
    required this.uid,
    required this.nombreUsuario,
    required this.fotoIds,
    required this.fechaActualizacion,
  });

  bool completo(Reto reto) => fotoIds.length >= reto.fotosObjetivo;

  factory ParticipacionReto.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ParticipacionReto.fromMap(doc.id, doc.data() ?? const {});
  }

  factory ParticipacionReto.fromMap(String uid, Map<String, dynamic> data) {
    return ParticipacionReto(
      uid: uid,
      nombreUsuario: data['nombreUsuario'] as String? ?? '',
      fotoIds: List<String>.from(data['fotoIds'] as List? ?? const []),
      fechaActualizacion:
          (data['fechaActualizacion'] as Timestamp?)?.toDate() ??
              DateTime.now(),
    );
  }
}
