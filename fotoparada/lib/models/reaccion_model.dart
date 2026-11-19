import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoReaccion {
  meGusta('❤️', 'Me gusta'),
  meEncanta('😍', 'Me encanta'),
  asombro('😮', 'Asombroso'),
  aplauso('👏', 'Bien hecho');

  const TipoReaccion(this.emoji, this.etiqueta);

  final String emoji;
  final String etiqueta;
}

/// Reacción de un usuario a una foto. Se guarda en
/// `fotos/{fotoId}/reacciones/{uid}`: el id del documento es el uid, así cada
/// usuario tiene como máximo una reacción por foto.
class Reaccion {
  final String uid;
  final TipoReaccion tipo;
  final DateTime fecha;

  Reaccion({required this.uid, required this.tipo, required this.fecha});

  factory Reaccion.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Reaccion.fromMap(doc.id, doc.data() ?? const {});
  }

  factory Reaccion.fromMap(String uid, Map<String, dynamic> data) {
    return Reaccion(
      uid: uid,
      tipo: TipoReaccion.values.asNameMap()[data['tipo']] ??
          TipoReaccion.meGusta,
      fecha: (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tipo': tipo.name,
      'fecha': Timestamp.fromDate(fecha),
    };
  }
}
