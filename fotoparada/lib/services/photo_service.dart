import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/foto_model.dart';

class PhotoException implements Exception {
  const PhotoException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PhotoService {
  PhotoService({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _fotos =>
      _firestore.collection('fotos');

  /// Sube [archivo] a `fotos/{uid}/{id}.jpg` y crea su documento en "fotos".
  Future<Foto> subirFoto({
    required File archivo,
    required String uid,
    required String titulo,
    required String descripcion,
    required CategoriaFoto categoria,
    required double latitud,
    required double longitud,
    required String nombreLugar,
    required DateTime fechaToma,
    required PrivacidadFoto privacidad,
  }) async {
    final documento = _fotos.doc();
    final rutaStorage = 'fotos/$uid/${documento.id}.jpg';
    final referencia = _storage.ref(rutaStorage);

    try {
      await referencia.putFile(
        archivo,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    } on FirebaseException catch (e) {
      throw PhotoException(_mapError(e));
    }

    try {
      final foto = Foto(
        id: documento.id,
        uid: uid,
        urlImagen: await referencia.getDownloadURL(),
        rutaStorage: rutaStorage,
        titulo: titulo,
        descripcion: descripcion,
        categoria: categoria,
        latitud: latitud,
        longitud: longitud,
        nombreLugar: nombreLugar,
        fechaToma: fechaToma,
        fechaSubida: DateTime.now(),
        privacidad: privacidad,
      );

      await documento.set({
        ...foto.toMap(),
        // La hora del servidor evita que el reloj del teléfono altere el orden.
        'fechaSubida': FieldValue.serverTimestamp(),
      });
      return foto;
    } on FirebaseException catch (e) {
      // Sin documento nadie podría encontrar ni borrar el archivo ya subido.
      await referencia.delete().catchError((_) {});
      throw PhotoException(_mapError(e));
    }
  }

  Stream<List<Foto>> obtenerMisFotos(String uid) {
    return _escuchar(
      _fotos.where('uid', isEqualTo: uid),
    );
  }

  Stream<List<Foto>> obtenerFotosPublicas() {
    return _escuchar(
      _fotos.where('privacidad', isEqualTo: PrivacidadFoto.publica.name),
    );
  }

  /// Guarda solo los campos editables: los likes, el dueño, el archivo y la
  /// fecha de subida no se tocan para no pisar cambios concurrentes.
  Future<void> actualizarFoto(Foto foto) async {
    try {
      await _fotos.doc(foto.id).update({
        'titulo': foto.titulo,
        'descripcion': foto.descripcion,
        'categoria': foto.categoria.name,
        'latitud': foto.latitud,
        'longitud': foto.longitud,
        'nombreLugar': foto.nombreLugar,
        'fechaToma': Timestamp.fromDate(foto.fechaToma),
        'privacidad': foto.privacidad.name,
      });
    } on FirebaseException catch (e) {
      throw PhotoException(_mapError(e));
    }
  }

  /// Borra primero el archivo y tolera que ya no exista, de modo que si falla
  /// el borrado del documento se pueda reintentar la operación completa.
  Future<void> eliminarFoto(Foto foto) async {
    try {
      if (foto.rutaStorage.isNotEmpty) {
        await _eliminarArchivo(foto.rutaStorage);
      }
      await _fotos.doc(foto.id).delete();
    } on FirebaseException catch (e) {
      throw PhotoException(_mapError(e));
    }
  }

  Future<void> _eliminarArchivo(String rutaStorage) async {
    try {
      await _storage.ref(rutaStorage).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }

  Stream<List<Foto>> _escuchar(Query<Map<String, dynamic>> consulta) {
    return consulta
        .orderBy('fechaSubida', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Foto.fromFirestore).toList())
        .handleError((Object error) {
      if (error is FirebaseException) {
        throw PhotoException(_mapError(error));
      }
      throw error;
    });
  }

  String _mapError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
      case 'unauthorized':
      case 'unauthenticated':
        return 'No tienes permiso para realizar esta acción.';
      case 'not-found':
      case 'object-not-found':
        return 'La foto ya no existe.';
      case 'unavailable':
      case 'retry-limit-exceeded':
        return 'Sin conexión con el servidor. Intenta de nuevo.';
      case 'quota-exceeded':
        return 'Se superó el límite de almacenamiento.';
      case 'canceled':
        return 'La operación fue cancelada.';
      default:
        return 'Ocurrió un error inesperado. Intenta de nuevo.';
    }
  }
}
