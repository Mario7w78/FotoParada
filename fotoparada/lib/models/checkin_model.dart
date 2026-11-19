import 'package:cloud_firestore/cloud_firestore.dart';

/// Lugar en el que se quiere hacer check-in. Se pasa como argumento a
/// CheckInView.
class LugarCheckIn {
  final String nombre;
  final double latitud;
  final double longitud;

  const LugarCheckIn({
    required this.nombre,
    required this.latitud,
    required this.longitud,
  });
}

/// Check-in validado con el GPS. Se guarda en la colección `checkins`.
class CheckIn {
  final String id;
  final String uid;
  final String nombreLugar;
  final double latitud;
  final double longitud;

  /// Distancia entre el usuario y el lugar al momento del check-in.
  final double distanciaMetros;
  final DateTime fecha;

  CheckIn({
    required this.id,
    required this.uid,
    required this.nombreLugar,
    required this.latitud,
    required this.longitud,
    required this.distanciaMetros,
    required this.fecha,
  });

  factory CheckIn.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return CheckIn.fromMap(doc.id, doc.data() ?? const {});
  }

  factory CheckIn.fromMap(String id, Map<String, dynamic> data) {
    return CheckIn(
      id: id,
      uid: data['uid'] as String? ?? '',
      nombreLugar: data['nombreLugar'] as String? ?? '',
      latitud: (data['latitud'] as num?)?.toDouble() ?? 0.0,
      longitud: (data['longitud'] as num?)?.toDouble() ?? 0.0,
      distanciaMetros: (data['distanciaMetros'] as num?)?.toDouble() ?? 0.0,
      fecha: (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nombreLugar': nombreLugar,
      'latitud': latitud,
      'longitud': longitud,
      'distanciaMetros': distanciaMetros,
      'fecha': Timestamp.fromDate(fecha),
    };
  }
}
