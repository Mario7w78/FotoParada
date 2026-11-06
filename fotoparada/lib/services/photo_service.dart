import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/foto_model.dart';
import 'imagen_compresor.dart';
import 'imgbb_service.dart';

class PhotoException implements Exception {
  const PhotoException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PhotoService {
  PhotoService({
    FirebaseFirestore? firestore,
    ImagenCompresor? compresor,
    ImgbbService? imgbb,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _compresor = compresor ?? ImagenCompresor(),
        _imgbb = imgbb ?? ImgbbService();

  final FirebaseFirestore _firestore;
  final ImagenCompresor _compresor;
  final ImgbbService _imgbb;

  CollectionReference<Map<String, dynamic>> get _fotos =>
      _firestore.collection('fotos');

  /// Comprime [archivo], lo sube a ImgBB y guarda sus URLs en un documento
  /// nuevo de "fotos". Si la subida falla no se crea el documento.
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
    // Antes de comprimir, para no hacer esperar en vano si falta la clave.
    if (!_imgbb.tieneClave) {
      throw const PhotoException(mensajeFaltaClaveImgbb);
    }

    final bytes = await _comprimir(archivo);
    final subida = await _imgbb.subirImagen(bytes);
    final documento = _fotos.doc();

    final foto = Foto(
      id: documento.id,
      uid: uid,
      urlImagen: subida.url,
      urlMiniatura: subida.urlMiniatura,
      urlEliminar: subida.urlEliminar,
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

    try {
      await documento.set({
        ...foto.toMap(),
        // La hora del servidor evita que el reloj del teléfono altere el orden.
        'fechaSubida': FieldValue.serverTimestamp(),
      });
      return foto;
    } on FirebaseException catch (e) {
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

  /// Guarda solo [campos] (ver [Foto.camposCambiados]) para no pisar cambios
  /// concurrentes en el resto del documento, como los likes.
  Future<void> actualizarFoto(String id, Map<String, dynamic> campos) async {
    if (campos.isEmpty) return;

    try {
      await _fotos.doc(id).update(campos);
    } on FirebaseException catch (e) {
      throw PhotoException(_mapError(e));
    }
  }

  /// Borra solo el documento. La imagen sigue en ImgBB, que no permite
  /// borrarla por API: se puede quitar a mano desde [Foto.urlEliminar].
  Future<void> eliminarFoto(Foto foto) async {
    try {
      await _fotos.doc(foto.id).delete();
    } on FirebaseException catch (e) {
      throw PhotoException(_mapError(e));
    }
  }

  Future<Uint8List> _comprimir(File archivo) async {
    final Uint8List bytes;
    try {
      bytes = await archivo.readAsBytes();
    } on FileSystemException {
      throw const PhotoException('No se pudo leer la imagen.');
    }

    try {
      return await _compresor.comprimir(bytes);
    } on ImagenNoValidaException catch (e) {
      throw PhotoException(e.message);
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
      case 'unauthenticated':
        return 'No tienes permiso para realizar esta acción.';
      case 'not-found':
        return 'La foto ya no existe.';
      case 'unavailable':
        return 'Sin conexión con el servidor. Intenta de nuevo.';
      case 'resource-exhausted':
        return 'Se superó el límite gratuito de Firebase por hoy.';
      case 'canceled':
        return 'La operación fue cancelada.';
      case 'failed-precondition':
        return 'Falta crear el índice de Firestore para esta consulta.';
      default:
        return 'Ocurrió un error inesperado. Intenta de nuevo.';
    }
  }
}
