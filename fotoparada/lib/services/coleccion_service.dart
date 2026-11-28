import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/coleccion_model.dart';
import 'recuerdos_exception.dart';

/// Integrante 4 - Colecciones de fotos y lugares favoritos.
///
/// `colecciones/{coleccionId}` guarda nombre, dueño y contador;
/// `colecciones/{coleccionId}/elementos/{elementoId}` guarda cada foto o lugar.
class ColeccionService {
  ColeccionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const List<TipoColeccion> predeterminadas = [
    TipoColeccion.quieroVisitar,
    TipoColeccion.misViajes,
  ];

  CollectionReference<Map<String, dynamic>> get _colecciones =>
      _firestore.collection('colecciones');

  CollectionReference<Map<String, dynamic>> _elementos(String coleccionId) =>
      _colecciones.doc(coleccionId).collection('elementos');

  // ------------------------------------------------------------ Colecciones

  /// Colecciones de [uid]: predeterminadas primero. Se ordena en el teléfono
  /// para no necesitar un índice compuesto.
  Stream<List<Coleccion>> obtenerColecciones(String uid) {
    return _convertirErrores(
      _colecciones.where('uid', isEqualTo: uid).snapshots().map((snapshot) {
        final lista = snapshot.docs.map(Coleccion.fromFirestore).toList();
        lista.sort(Coleccion.comparar);
        return lista;
      }),
    );
  }

  /// Crea "Quiero visitar" y "Mis viajes" si el usuario aún no las tiene.
  Future<void> asegurarPredeterminadas(String uid) async {
    try {
      final existentes =
          await _colecciones.where('uid', isEqualTo: uid).get();
      final tipos = existentes.docs.map((doc) => doc.data()['tipo']).toSet();

      final lote = _firestore.batch();
      var faltaAlguna = false;
      final ahora = DateTime.now();
      for (final tipo in predeterminadas) {
        if (tipos.contains(tipo.name)) continue;
        faltaAlguna = true;
        final id = Coleccion.idPredeterminada(uid, tipo);
        lote.set(
          _colecciones.doc(id),
          Coleccion(
            id: id,
            uid: uid,
            nombre: tipo.nombrePorDefecto,
            descripcion: tipo.descripcionPorDefecto,
            tipo: tipo,
            cantidad: 0,
            portadaUrl: '',
            fechaCreacion: ahora,
            fechaActualizacion: ahora,
          ).toMap(),
        );
      }
      if (faltaAlguna) await lote.commit();
    } on FirebaseException catch (e) {
      throw RecuerdosException.desdeFirebase(e);
    }
  }

  Future<Coleccion> crearColeccion({
    required String uid,
    required String nombre,
    String descripcion = '',
  }) async {
    final coleccion = prepararColeccion(
      uid: uid,
      nombre: nombre,
      descripcion: descripcion,
    );
    await guardarColeccion(coleccion);
    return coleccion;
  }

  /// Valida los datos y arma una colección nueva, con su id definitivo, sin
  /// llamar al servidor.
  Coleccion prepararColeccion({
    required String uid,
    required String nombre,
    String descripcion = '',
  }) {
    final nombreLimpio = _validarNombre(nombre);
    final ahora = DateTime.now();
    return Coleccion(
      id: _colecciones.doc().id,
      uid: uid,
      nombre: nombreLimpio,
      descripcion: _validarDescripcion(descripcion),
      tipo: TipoColeccion.personalizada,
      cantidad: 0,
      portadaUrl: '',
      fechaCreacion: ahora,
      fechaActualizacion: ahora,
    );
  }

  Future<void> guardarColeccion(Coleccion coleccion) async {
    try {
      await _colecciones.doc(coleccion.id).set(coleccion.toMap());
    } on FirebaseException catch (e) {
      throw RecuerdosException.desdeFirebase(e);
    }
  }

  /// Solo las colecciones personalizadas se pueden renombrar.
  Future<void> editarColeccion(
    Coleccion coleccion, {
    required String nombre,
    String descripcion = '',
  }) async {
    if (coleccion.esPredeterminada) {
      throw const RecuerdosException(
        'Las colecciones predeterminadas no se pueden renombrar.',
      );
    }
    final cambios = {
      'nombre': _validarNombre(nombre),
      'descripcion': _validarDescripcion(descripcion),
      'fechaActualizacion': FieldValue.serverTimestamp(),
    };
    try {
      await _colecciones.doc(coleccion.id).update(cambios);
    } on FirebaseException catch (e) {
      throw RecuerdosException.desdeFirebase(e);
    }
  }

  /// Borra la colección y todo lo que contiene (Firestore no borra las
  /// subcolecciones por sí solo).
  Future<void> eliminarColeccion(Coleccion coleccion) async {
    if (coleccion.esPredeterminada) {
      throw const RecuerdosException(
        'Las colecciones predeterminadas no se pueden eliminar.',
      );
    }
    try {
      final elementos = await _elementos(coleccion.id).get();
      final lote = _firestore.batch();
      for (final doc in elementos.docs) {
        lote.delete(doc.reference);
      }
      lote.delete(_colecciones.doc(coleccion.id));
      await lote.commit();
    } on FirebaseException catch (e) {
      throw RecuerdosException.desdeFirebase(e);
    }
  }

  // -------------------------------------------------------------- Elementos

  /// Lo más reciente primero.
  Stream<List<ElementoColeccion>> obtenerElementos(String coleccionId) {
    return _convertirErrores(
      _elementos(coleccionId)
          .orderBy('fechaAgregado', descending: true)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs.map(ElementoColeccion.fromFirestore).toList(),
          ),
    );
  }

  /// Ids de las colecciones (de [colecciones]) que ya tienen [elementoId].
  Future<Set<String>> coleccionesQueContienen(
    List<Coleccion> colecciones,
    String elementoId,
  ) async {
    try {
      final resultados = await Future.wait(
        colecciones.map((coleccion) async {
          final doc = await _elementos(coleccion.id).doc(elementoId).get();
          return doc.exists ? coleccion.id : null;
        }),
      );
      return resultados.whereType<String>().toSet();
    } on FirebaseException catch (e) {
      throw RecuerdosException.desdeFirebase(e);
    }
  }

  /// Devuelve false si el elemento ya estaba en la colección. La transacción
  /// evita que el contador suba dos veces si se toca "guardar" muy rápido.
  Future<bool> agregarElemento(
    String coleccionId,
    ElementoColeccion elemento,
  ) async {
    try {
      return await _firestore.runTransaction((tx) async {
        final ref = _elementos(coleccionId).doc(elemento.id);
        final actual = await tx.get(ref);
        if (actual.exists) return false;

        tx.set(ref, elemento.toMap());
        tx.update(_colecciones.doc(coleccionId), {
          'cantidad': FieldValue.increment(1),
          'fechaActualizacion': FieldValue.serverTimestamp(),
          if (elemento.urlImagen.isNotEmpty) 'portadaUrl': elemento.urlImagen,
        });
        return true;
      });
    } on FirebaseException catch (e) {
      throw RecuerdosException.desdeFirebase(e);
    }
  }

  Future<void> quitarElemento(String coleccionId, String elementoId) async {
    try {
      final quitado = await _firestore.runTransaction((tx) async {
        final ref = _elementos(coleccionId).doc(elementoId);
        final actual = await tx.get(ref);
        if (!actual.exists) return false;

        tx.delete(ref);
        tx.update(_colecciones.doc(coleccionId), {
          'cantidad': FieldValue.increment(-1),
          'fechaActualizacion': FieldValue.serverTimestamp(),
        });
        return true;
      });
      if (quitado) await _recalcularPortada(coleccionId);
    } on FirebaseException catch (e) {
      throw RecuerdosException.desdeFirebase(e);
    }
  }

  /// Pasa [elemento] de una colección a otra, por ejemplo de "Quiero visitar"
  /// a "Mis viajes" cuando el usuario ya fue al lugar.
  Future<void> moverElemento({
    required ElementoColeccion elemento,
    required String origenId,
    required String destinoId,
  }) async {
    if (origenId == destinoId) return;
    try {
      await _firestore.runTransaction((tx) async {
        final refOrigen = _elementos(origenId).doc(elemento.id);
        final refDestino = _elementos(destinoId).doc(elemento.id);
        final enOrigen = await tx.get(refOrigen);
        final enDestino = await tx.get(refDestino);

        if (!enDestino.exists) {
          tx.set(refDestino, {
            ...elemento.toMap(),
            'fechaAgregado': FieldValue.serverTimestamp(),
          });
          tx.update(_colecciones.doc(destinoId), {
            'cantidad': FieldValue.increment(1),
            'fechaActualizacion': FieldValue.serverTimestamp(),
            if (elemento.urlImagen.isNotEmpty)
              'portadaUrl': elemento.urlImagen,
          });
        }
        if (enOrigen.exists) {
          tx.delete(refOrigen);
          tx.update(_colecciones.doc(origenId), {
            'cantidad': FieldValue.increment(-1),
            'fechaActualizacion': FieldValue.serverTimestamp(),
          });
        }
      });
      await _recalcularPortada(origenId);
    } on FirebaseException catch (e) {
      throw RecuerdosException.desdeFirebase(e);
    }
  }

  Future<void> actualizarNota(
    String coleccionId,
    String elementoId,
    String nota,
  ) async {
    final limpia = nota.trim();
    if (limpia.length > ElementoColeccion.largoMaximoNota) {
      throw const RecuerdosException(
        'La nota puede tener hasta ${ElementoColeccion.largoMaximoNota} '
        'caracteres.',
      );
    }
    try {
      await _elementos(coleccionId).doc(elementoId).update({'nota': limpia});
    } on FirebaseException catch (e) {
      throw RecuerdosException.desdeFirebase(e);
    }
  }

  // ---------------------------------------------------------------- Ayudas

  /// La portada pasa a ser la imagen del elemento más reciente que tenga una.
  Future<void> _recalcularPortada(String coleccionId) async {
    final recientes = await _elementos(coleccionId)
        .orderBy('fechaAgregado', descending: true)
        .limit(10)
        .get();
    final portada = recientes.docs
        .map((doc) => doc.data()['urlImagen'] as String? ?? '')
        .firstWhere((url) => url.isNotEmpty, orElse: () => '');
    await _colecciones.doc(coleccionId).update({'portadaUrl': portada});
  }

  String _validarNombre(String nombre) {
    final limpio = nombre.trim();
    if (limpio.isEmpty) {
      throw const RecuerdosException('Escribe un nombre para la colección.');
    }
    if (limpio.length > Coleccion.largoMaximoNombre) {
      throw const RecuerdosException(
        'El nombre puede tener hasta ${Coleccion.largoMaximoNombre} '
        'caracteres.',
      );
    }
    return limpio;
  }

  String _validarDescripcion(String descripcion) {
    final limpia = descripcion.trim();
    if (limpia.length > Coleccion.largoMaximoDescripcion) {
      throw const RecuerdosException(
        'La descripción puede tener hasta '
        '${Coleccion.largoMaximoDescripcion} caracteres.',
      );
    }
    return limpia;
  }

  Stream<T> _convertirErrores<T>(Stream<T> stream) {
    return stream.handleError((Object error) {
      if (error is FirebaseException) {
        throw RecuerdosException.desdeFirebase(error);
      }
      throw error;
    });
  }
}
