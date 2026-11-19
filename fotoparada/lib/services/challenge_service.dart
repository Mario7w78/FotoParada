import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/foto_model.dart';
import '../models/reto_model.dart';
import 'interaccion_exception.dart';

/// Retos fotográficos (colección `retos`) y el avance de cada participante
/// (subcolección `retos/{retoId}/participantes/{uid}`).
class ChallengeService {
  ChallengeService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _retos =>
      _firestore.collection('retos');

  CollectionReference<Map<String, dynamic>> _participantes(String retoId) =>
      _retos.doc(retoId).collection('participantes');

  /// Todos los retos, los que terminan antes primero.
  Stream<List<Reto>> obtenerRetos() {
    return convertirErrores(
      _retos.orderBy('fechaFin').snapshots().map(
            (snapshot) => snapshot.docs.map(Reto.fromFirestore).toList(),
          ),
    );
  }

  Future<Reto> crearReto({
    required String creadorUid,
    required String creadorNombre,
    required String titulo,
    required String descripcion,
    CategoriaFoto? categoria,
    double? latitud,
    double? longitud,
    String nombreLugar = '',
    double radioMetros = Reto.radioPorDefecto,
    int fotosObjetivo = 1,
    required DateTime fechaFin,
  }) async {
    if (titulo.trim().isEmpty) {
      throw const InteraccionException('Escribe un título para el reto.');
    }
    final ahora = DateTime.now();
    if (!fechaFin.isAfter(ahora)) {
      throw const InteraccionException(
        'La fecha de fin debe ser posterior a hoy.',
      );
    }
    if (fotosObjetivo < 1) {
      throw const InteraccionException('El reto debe pedir al menos una foto.');
    }

    final documento = _retos.doc();
    final reto = Reto(
      id: documento.id,
      creadorUid: creadorUid,
      creadorNombre: creadorNombre,
      titulo: titulo.trim(),
      descripcion: descripcion.trim(),
      categoria: categoria,
      latitud: latitud,
      longitud: longitud,
      nombreLugar: nombreLugar,
      radioMetros: radioMetros,
      fotosObjetivo: fotosObjetivo,
      fechaInicio: ahora,
      fechaFin: fechaFin,
    );

    try {
      await documento.set(reto.toMap());
      return reto;
    } on FirebaseException catch (e) {
      throw InteraccionException.desdeFirebase(e);
    }
  }

  /// Solo el creador puede eliminarlo (lo controlan las reglas de Firestore).
  /// Los participantes quedan huérfanos pero ya no se muestran.
  Future<void> eliminarReto(String retoId) async {
    try {
      await _retos.doc(retoId).delete();
    } on FirebaseException catch (e) {
      throw InteraccionException.desdeFirebase(e);
    }
  }

  /// Participantes ordenados por cantidad de fotos enviadas.
  Stream<List<ParticipacionReto>> obtenerParticipantes(String retoId) {
    return convertirErrores(
      _participantes(retoId).snapshots().map((snapshot) {
        final lista =
            snapshot.docs.map(ParticipacionReto.fromFirestore).toList();
        lista.sort((a, b) {
          final porFotos = b.fotoIds.length.compareTo(a.fotoIds.length);
          if (porFotos != 0) return porFotos;
          return a.fechaActualizacion.compareTo(b.fechaActualizacion);
        });
        return lista;
      }),
    );
  }

  /// Envía [foto] al reto si cumple todas sus condiciones.
  Future<void> enviarFoto({
    required Reto reto,
    required Foto foto,
    required String uid,
    required String nombreUsuario,
  }) async {
    if (!reto.estaActivo()) {
      throw const InteraccionException('Este reto ya no está activo.');
    }
    if (foto.uid != uid) {
      throw const InteraccionException('Solo puedes enviar tus propias fotos.');
    }
    final motivo = reto.motivoNoCumple(foto);
    if (motivo != null) throw InteraccionException(motivo);

    try {
      await _participantes(reto.id).doc(uid).set({
        'nombreUsuario': nombreUsuario,
        'fotoIds': FieldValue.arrayUnion([foto.id]),
        'fechaActualizacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw InteraccionException.desdeFirebase(e);
    }
  }

  Future<void> quitarFoto({
    required String retoId,
    required String uid,
    required String fotoId,
  }) async {
    try {
      await _participantes(retoId).doc(uid).update({
        'fotoIds': FieldValue.arrayRemove([fotoId]),
        'fechaActualizacion': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw InteraccionException.desdeFirebase(e);
    }
  }
}
