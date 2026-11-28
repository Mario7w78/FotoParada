import 'package:cloud_firestore/cloud_firestore.dart';

/// Acceso a la colección `fotos` de Firestore. Devuelve los datos tal como
/// llegan: convertirlos a modelos y traducir errores es tarea de
/// FotoRepository.
class FotoFirestoreService {
  FotoFirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _fotos =>
      _firestore.collection('fotos');

  /// Id para un documento que todavía no existe.
  String nuevoId() => _fotos.doc().id;

  Future<void> crear(String id, Map<String, dynamic> datos) {
    return _fotos.doc(id).set({
      ...datos,
      // La hora del servidor evita que el reloj del teléfono altere el orden.
      'fechaSubida': FieldValue.serverTimestamp(),
    });
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> obtener(String id) =>
      _fotos.doc(id).get();

  Future<void> actualizar(String id, Map<String, dynamic> campos) =>
      _fotos.doc(id).update(campos);

  Future<void> eliminar(String id) => _fotos.doc(id).delete();

  Stream<QuerySnapshot<Map<String, dynamic>>> escucharPorUsuario(String uid) {
    return _recientes(_fotos.where('uid', isEqualTo: uid));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> escucharPorPrivacidad(
    String privacidad, {
    String? categoria,
    String? nombreLugar,
    required int limite,
  }) {
    return _recientes(
      _filtrar(
        privacidad,
        categoria: categoria,
        nombreLugar: nombreLugar,
      ).limit(limite),
    );
  }

  /// Fotos de un lugar, de la que tiene más likes a la que tiene menos.
  Stream<QuerySnapshot<Map<String, dynamic>>> escucharPopulares(
    String privacidad, {
    required String nombreLugar,
    required int limite,
  }) {
    return _filtrar(privacidad, nombreLugar: nombreLugar)
        .orderBy('likes', descending: true)
        .limit(limite)
        .snapshots();
  }

  Query<Map<String, dynamic>> _filtrar(
    String privacidad, {
    String? categoria,
    String? nombreLugar,
  }) {
    var consulta = _fotos.where('privacidad', isEqualTo: privacidad);
    if (categoria != null) {
      consulta = consulta.where('categoria', isEqualTo: categoria);
    }
    if (nombreLugar != null) {
      consulta = consulta.where('nombreLugar', isEqualTo: nombreLugar);
    }
    return consulta;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _recientes(
    Query<Map<String, dynamic>> consulta,
  ) {
    return consulta.orderBy('fechaSubida', descending: true).snapshots();
  }
}
