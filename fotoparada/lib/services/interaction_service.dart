import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/comentario_model.dart';
import '../models/reaccion_model.dart';
import 'interaccion_exception.dart';

/// Comentarios y reacciones de las fotos. Ambos viven en subcolecciones del
/// documento de la foto: `fotos/{fotoId}/comentarios` y
/// `fotos/{fotoId}/reacciones/{uid}`.
class InteractionService {
  InteractionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _foto(String fotoId) =>
      _firestore.collection('fotos').doc(fotoId);

  CollectionReference<Map<String, dynamic>> _comentarios(String fotoId) =>
      _foto(fotoId).collection('comentarios');

  CollectionReference<Map<String, dynamic>> _reacciones(String fotoId) =>
      _foto(fotoId).collection('reacciones');

  Stream<List<Comentario>> obtenerComentarios(String fotoId) {
    return convertirErrores(
      _comentarios(fotoId)
          .orderBy('fecha')
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map(Comentario.fromFirestore).toList()),
    );
  }

  Future<void> agregarComentario({
    required String fotoId,
    required String uid,
    required String nombreUsuario,
    required String texto,
  }) async {
    final limpio = texto.trim();
    if (limpio.isEmpty) {
      throw const InteraccionException('Escribe un comentario.');
    }
    if (limpio.length > Comentario.largoMaximo) {
      throw const InteraccionException(
        'El comentario no puede tener más de ${Comentario.largoMaximo} '
        'caracteres.',
      );
    }

    try {
      await _comentarios(fotoId).add({
        'uid': uid,
        'nombreUsuario': nombreUsuario,
        'texto': limpio,
        // La hora del servidor evita que el reloj del teléfono altere el orden.
        'fecha': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw InteraccionException.desdeFirebase(e);
    }
  }

  Future<void> eliminarComentario(String fotoId, String comentarioId) async {
    try {
      await _comentarios(fotoId).doc(comentarioId).delete();
    } on FirebaseException catch (e) {
      throw InteraccionException.desdeFirebase(e);
    }
  }

  Stream<List<Reaccion>> obtenerReacciones(String fotoId) {
    return convertirErrores(
      _reacciones(fotoId).snapshots().map(
            (snapshot) => snapshot.docs.map(Reaccion.fromFirestore).toList(),
          ),
    );
  }

  /// Si el usuario no había reaccionado, agrega [tipo]. Si ya tenía esa misma
  /// reacción, la quita. Si tenía otra, la cambia.
  ///
  /// El campo `likes` de la foto cuenta cuántos usuarios reaccionaron (lo usa
  /// la sección de fotos populares) y se actualiza en la misma transacción
  /// para que nunca quede desfasado.
  Future<void> reaccionar({
    required String fotoId,
    required String uid,
    required TipoReaccion tipo,
  }) async {
    final foto = _foto(fotoId);
    final reaccion = _reacciones(fotoId).doc(uid);

    try {
      await _firestore.runTransaction((transaccion) async {
        final actual = await transaccion.get(reaccion);

        if (!actual.exists) {
          transaccion.set(reaccion, {
            'tipo': tipo.name,
            'fecha': FieldValue.serverTimestamp(),
          });
          transaccion.update(foto, {'likes': FieldValue.increment(1)});
        } else if (actual.data()?['tipo'] == tipo.name) {
          transaccion.delete(reaccion);
          transaccion.update(foto, {'likes': FieldValue.increment(-1)});
        } else {
          transaccion.update(reaccion, {
            'tipo': tipo.name,
            'fecha': FieldValue.serverTimestamp(),
          });
        }
      });
    } on FirebaseException catch (e) {
      throw InteraccionException.desdeFirebase(e);
    }
  }
}
