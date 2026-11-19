import 'package:cloud_firestore/cloud_firestore.dart';

/// Comentario de una foto. Se guarda en la subcolección
/// `fotos/{fotoId}/comentarios`.
class Comentario {
  final String id;
  final String uid;
  final String nombreUsuario;
  final String texto;
  final DateTime fecha;

  Comentario({
    required this.id,
    required this.uid,
    required this.nombreUsuario,
    required this.texto,
    required this.fecha,
  });

  static const int largoMaximo = 300;

  factory Comentario.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Comentario.fromMap(doc.id, doc.data() ?? const {});
  }

  factory Comentario.fromMap(String id, Map<String, dynamic> data) {
    return Comentario(
      id: id,
      uid: data['uid'] as String? ?? '',
      nombreUsuario: data['nombreUsuario'] as String? ?? '',
      texto: data['texto'] as String? ?? '',
      // Es nulo mientras el servidor no confirma el serverTimestamp.
      fecha: (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nombreUsuario': nombreUsuario,
      'texto': texto,
      'fecha': Timestamp.fromDate(fecha),
    };
  }
}
