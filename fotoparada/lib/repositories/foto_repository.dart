import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/foto_model.dart';
import '../services/foto_firestore_service.dart';
import '../services/imagen_compresor.dart';
import '../services/imgbb_service.dart';
import '../services/photo_exception.dart';

class FotoRepository {
  FotoRepository({
    FotoFirestoreService? service,
    ImagenCompresor? compresor,
    ImgbbService? imgbb,
  })  : _service = service ?? FotoFirestoreService(),
        _compresor = compresor ?? ImagenCompresor(),
        _imgbb = imgbb ?? ImgbbService();

  final FotoFirestoreService _service;
  final ImagenCompresor _compresor;
  final ImgbbService _imgbb;

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

    final foto = Foto(
      id: _service.nuevoId(),
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

    await _traducir(() => _service.crear(foto.id, foto.toMap()));
    return foto;
  }

  Stream<List<Foto>> obtenerMisFotos(String uid) {
    return _convertir(_service.escucharPorUsuario(uid));
  }

  Stream<List<Foto>> obtenerFotosPublicas({int limite = 30}) {
    return _convertir(
      _service.escucharPorPrivacidad(
        PrivacidadFoto.publica.name,
        limite: limite,
      ),
    );
  }

  Stream<List<Foto>> obtenerFotosPublicasPorCategoria(
    CategoriaFoto categoria, {
    int limite = 30,
  }) {
    return _convertir(
      _service.escucharPorPrivacidad(
        PrivacidadFoto.publica.name,
        categoria: categoria.name,
        limite: limite,
      ),
    );
  }

  /// Fotos públicas de [nombreLugar], las más recientes primero.
  Stream<List<Foto>> obtenerFotosPorLugarRecientes(
    String nombreLugar, {
    int limite = 30,
  }) {
    return _convertir(
      _service.escucharPorPrivacidad(
        PrivacidadFoto.publica.name,
        nombreLugar: nombreLugar,
        limite: limite,
      ),
    );
  }

  /// Fotos públicas de [nombreLugar], ordenadas de más a menos likes.
  Stream<List<Foto>> obtenerFotosPorLugarPopulares(
    String nombreLugar, {
    int limite = 30,
  }) {
    return _convertir(
      _service.escucharPopulares(
        PrivacidadFoto.publica.name,
        nombreLugar: nombreLugar,
        limite: limite,
      ),
    );
  }

  Future<Foto?> obtenerPorId(String id) {
    return _traducir(() async {
      final doc = await _service.obtener(id);
      return doc.exists ? Foto.fromFirestore(doc) : null;
    });
  }

  /// Guarda solo [campos] (ver [Foto.camposCambiados]) para no pisar cambios
  /// concurrentes en el resto del documento, como los likes.
  Future<void> actualizarFoto(String id, Map<String, dynamic> campos) async {
    if (campos.isEmpty) return;

    await _traducir(() => _service.actualizar(id, campos));
  }

  /// Borra solo el documento. La imagen sigue en ImgBB, que no permite
  /// borrarla por API: se puede quitar a mano desde [Foto.urlEliminar].
  Future<void> eliminarFoto(Foto foto) {
    return _traducir(() => _service.eliminar(foto.id));
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

  Future<T> _traducir<T>(Future<T> Function() operacion) async {
    try {
      return await operacion();
    } on FirebaseException catch (e) {
      throw PhotoException(_mapError(e));
    }
  }

  Stream<List<Foto>> _convertir(
    Stream<QuerySnapshot<Map<String, dynamic>>> consulta,
  ) {
    return consulta
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
