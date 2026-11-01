import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/foto_model.dart';
import 'imagen_compresor.dart';

class PhotoException implements Exception {
  const PhotoException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Límite de Firestore para un documento.
const int maxBytesDocumento = 1024 * 1024;

// Holgura para los nombres de los campos y los valores de tamaño fijo.
const int _margenCamposBytes = 2 * 1024;

class PhotoService {
  PhotoService({FirebaseFirestore? firestore, ImagenCompresor? compresor})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _compresor = compresor ?? ImagenCompresor();

  final FirebaseFirestore _firestore;
  final ImagenCompresor _compresor;

  CollectionReference<Map<String, dynamic>> get _fotos =>
      _firestore.collection('fotos');

  /// Comprime [archivo] y lo guarda en base64, con su miniatura, dentro de un
  /// documento nuevo de "fotos".
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
    final imagenes = await _comprimir(archivo);
    final documento = _fotos.doc();

    final foto = Foto(
      id: documento.id,
      uid: uid,
      imagenBase64: base64Encode(imagenes.imagen),
      miniaturaBase64: base64Encode(imagenes.miniatura),
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

    if (_tamanoAproximado(foto) > maxBytesDocumento) {
      throw const PhotoException(
        'La descripción es demasiado larga para esta foto. Acórtala e intenta '
        'de nuevo.',
      );
    }

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

  Future<void> eliminarFoto(Foto foto) async {
    try {
      await _fotos.doc(foto.id).delete();
    } on FirebaseException catch (e) {
      throw PhotoException(_mapError(e));
    }
  }

  Future<ImagenesComprimidas> _comprimir(File archivo) async {
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

  int _tamanoAproximado(Foto foto) {
    return foto.imagenBase64.length +
        foto.miniaturaBase64.length +
        utf8.encode(foto.titulo).length +
        utf8.encode(foto.descripcion).length +
        utf8.encode(foto.nombreLugar).length +
        _margenCamposBytes;
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
