import 'package:cloud_firestore/cloud_firestore.dart';

import 'foto_model.dart';

/// Integrante 4 - Recuerdos y organización.
///
/// Las colecciones viven en `colecciones/{coleccionId}` y lo que guardan en la
/// subcolección `colecciones/{coleccionId}/elementos/{elementoId}`.

/// Las colecciones predeterminadas se crean solas la primera vez que el
/// usuario abre "Guardado" y no se pueden borrar ni renombrar.
enum TipoColeccion { quieroVisitar, misViajes, personalizada }

extension TipoColeccionInfo on TipoColeccion {
  bool get esPredeterminada => this != TipoColeccion.personalizada;

  String get nombrePorDefecto {
    switch (this) {
      case TipoColeccion.quieroVisitar:
        return 'Quiero visitar';
      case TipoColeccion.misViajes:
        return 'Mis viajes';
      case TipoColeccion.personalizada:
        return 'Nueva colección';
    }
  }

  String get descripcionPorDefecto {
    switch (this) {
      case TipoColeccion.quieroVisitar:
        return 'Lugares que te gustaría conocer.';
      case TipoColeccion.misViajes:
        return 'Lugares que ya visitaste y sus fotos.';
      case TipoColeccion.personalizada:
        return '';
    }
  }

  /// Sufijo del id del documento: `{uid}_{sufijo}`. Un id fijo evita que se
  /// creen duplicados si dos pantallas lo intentan a la vez.
  String get sufijoId {
    switch (this) {
      case TipoColeccion.quieroVisitar:
        return 'quiero_visitar';
      case TipoColeccion.misViajes:
        return 'mis_viajes';
      case TipoColeccion.personalizada:
        return '';
    }
  }
}

class Coleccion {
  const Coleccion({
    required this.id,
    required this.uid,
    required this.nombre,
    required this.descripcion,
    required this.tipo,
    required this.cantidad,
    required this.portadaUrl,
    required this.fechaCreacion,
    required this.fechaActualizacion,
  });

  static const int largoMaximoNombre = 40;
  static const int largoMaximoDescripcion = 120;

  final String id;
  final String uid;
  final String nombre;
  final String descripcion;
  final TipoColeccion tipo;

  /// Cantidad de elementos. Se mantiene con cada alta y baja para no tener
  /// que leer la subcolección completa solo para mostrar el número.
  final int cantidad;

  /// Miniatura del último elemento con imagen. Vacía si no hay ninguno.
  final String portadaUrl;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;

  bool get esPredeterminada => tipo.esPredeterminada;

  /// Copia con otro contador, para reflejar un cambio sin volver a leerla.
  Coleccion conCantidad(int nuevaCantidad) => Coleccion(
        id: id,
        uid: uid,
        nombre: nombre,
        descripcion: descripcion,
        tipo: tipo,
        cantidad: nuevaCantidad < 0 ? 0 : nuevaCantidad,
        portadaUrl: portadaUrl,
        fechaCreacion: fechaCreacion,
        fechaActualizacion: fechaActualizacion,
      );

  static String idPredeterminada(String uid, TipoColeccion tipo) =>
      '${uid}_${tipo.sufijoId}';

  factory Coleccion.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Coleccion.fromMap(doc.id, doc.data() ?? const {});
  }

  factory Coleccion.fromMap(String id, Map<String, dynamic> data) {
    final tipo = TipoColeccion.values.asNameMap()[data['tipo']] ??
        TipoColeccion.personalizada;
    return Coleccion(
      id: id,
      uid: data['uid'] as String? ?? '',
      nombre: data['nombre'] as String? ?? tipo.nombrePorDefecto,
      descripcion: data['descripcion'] as String? ?? '',
      tipo: tipo,
      cantidad: (data['cantidad'] as num?)?.toInt() ?? 0,
      portadaUrl: data['portadaUrl'] as String? ?? '',
      fechaCreacion:
          (data['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fechaActualizacion: (data['fechaActualizacion'] as Timestamp?)?.toDate() ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nombre': nombre,
      'descripcion': descripcion,
      'tipo': tipo.name,
      'cantidad': cantidad,
      'portadaUrl': portadaUrl,
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      'fechaActualizacion': Timestamp.fromDate(fechaActualizacion),
    };
  }

  /// Predeterminadas primero (Quiero visitar, Mis viajes) y luego las
  /// personalizadas, las más recientes arriba.
  static int comparar(Coleccion a, Coleccion b) {
    final porTipo = a.tipo.index.compareTo(b.tipo.index);
    if (porTipo != 0) return porTipo;
    return b.fechaCreacion.compareTo(a.fechaCreacion);
  }
}

enum TipoElemento { foto, lugar }

/// Algo guardado en una colección: una foto o un lugar.
///
/// Se copian los datos que se muestran (título, miniatura, lugar) para poder
/// pintar la colección sin leer cada foto, y para que siga viéndose aunque la
/// foto original se borre.
class ElementoColeccion {
  const ElementoColeccion({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.nombreLugar,
    required this.latitud,
    required this.longitud,
    required this.fechaAgregado,
    this.fotoId = '',
    this.urlImagen = '',
    this.nota = '',
  });

  static const int largoMaximoNota = 200;

  final String id;
  final TipoElemento tipo;
  final String titulo;
  final String nombreLugar;
  final double latitud;
  final double longitud;
  final DateTime fechaAgregado;

  /// Solo en los elementos de tipo foto.
  final String fotoId;

  /// Miniatura para mostrar. Puede estar vacía en un lugar sin fotos.
  final String urlImagen;

  /// Nota personal, por ejemplo "ir en verano".
  final String nota;

  bool get esFoto => tipo == TipoElemento.foto;

  /// El id del documento identifica qué se guardó, así una misma foto o lugar
  /// no se repite dentro de la colección.
  static String idParaFoto(String fotoId) => 'foto_$fotoId';

  /// Los lugares sin nombre ("Cerca de «título»") pueden repetir el texto en
  /// sitios distintos, así que su id incluye además las coordenadas.
  static String idParaLugar(
    String nombreLugar, {
    double? latitud,
    double? longitud,
  }) {
    final limpio = nombreLugar
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9áéíóúüñ]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final id = 'lugar_${limpio.isEmpty ? 'sin_nombre' : limpio}';

    final sinNombre =
        limpio.isEmpty || nombreLugar.startsWith(Lugar.prefijoSinNombre);
    if (!sinNombre || latitud == null || longitud == null) return id;
    // 4 decimales (~11 m): el mismo punto conserva el id.
    return '${id}_${latitud.toStringAsFixed(4)}_'
        '${longitud.toStringAsFixed(4)}';
  }

  factory ElementoColeccion.desdeFoto(Foto foto, {String nota = ''}) {
    return ElementoColeccion(
      id: idParaFoto(foto.id),
      tipo: TipoElemento.foto,
      fotoId: foto.id,
      titulo: foto.titulo.isEmpty ? 'Foto' : foto.titulo,
      nombreLugar: foto.nombreLugar,
      latitud: foto.latitud,
      longitud: foto.longitud,
      urlImagen:
          foto.urlMiniatura.isNotEmpty ? foto.urlMiniatura : foto.urlImagen,
      fechaAgregado: DateTime.now(),
      nota: nota,
    );
  }

  factory ElementoColeccion.desdeLugar(Lugar lugar, {String nota = ''}) {
    return ElementoColeccion(
      id: idParaLugar(
        lugar.nombre,
        latitud: lugar.latitud,
        longitud: lugar.longitud,
      ),
      tipo: TipoElemento.lugar,
      titulo: lugar.nombre,
      nombreLugar: lugar.nombre,
      latitud: lugar.latitud,
      longitud: lugar.longitud,
      urlImagen: lugar.urlImagen,
      fechaAgregado: DateTime.now(),
      nota: nota,
    );
  }

  factory ElementoColeccion.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ElementoColeccion.fromMap(doc.id, doc.data() ?? const {});
  }

  factory ElementoColeccion.fromMap(String id, Map<String, dynamic> data) {
    return ElementoColeccion(
      id: id,
      tipo: TipoElemento.values.asNameMap()[data['tipo']] ?? TipoElemento.lugar,
      fotoId: data['fotoId'] as String? ?? '',
      titulo: data['titulo'] as String? ?? '',
      nombreLugar: data['nombreLugar'] as String? ?? '',
      latitud: (data['latitud'] as num?)?.toDouble() ?? 0.0,
      longitud: (data['longitud'] as num?)?.toDouble() ?? 0.0,
      urlImagen: data['urlImagen'] as String? ?? '',
      nota: data['nota'] as String? ?? '',
      fechaAgregado:
          (data['fechaAgregado'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tipo': tipo.name,
      'fotoId': fotoId,
      'titulo': titulo,
      'nombreLugar': nombreLugar,
      'latitud': latitud,
      'longitud': longitud,
      'urlImagen': urlImagen,
      'nota': nota,
      'fechaAgregado': Timestamp.fromDate(fechaAgregado),
    };
  }

  /// Lugar al que pertenece, para abrir su línea de tiempo.
  Lugar get lugar => Lugar(
        nombre: nombreLugar.isNotEmpty
            ? nombreLugar
            : esFoto
                ? '${Lugar.prefijoSinNombre}«$titulo»'
                : titulo,
        latitud: latitud,
        longitud: longitud,
        urlImagen: urlImagen,
      );
}

/// Un punto del mapa identificado por su nombre, igual que lo agrupan
/// LocationDetailView y las consultas por ubicación de PhotoService.
class Lugar {
  const Lugar({
    required this.nombre,
    required this.latitud,
    required this.longitud,
    this.urlImagen = '',
  });

  /// Comienzo del nombre que se inventa para un punto que no tiene uno.
  static const String prefijoSinNombre = 'Cerca de ';

  final String nombre;
  final double latitud;
  final double longitud;
  final String urlImagen;

  /// Toma el nombre y las coordenadas de una foto del lugar. Si la foto no
  /// tiene nombre de lugar se usa "Cerca de «título»".
  factory Lugar.desdeFoto(Foto foto) {
    final titulo = foto.titulo.isEmpty ? 'esta foto' : '«${foto.titulo}»';
    return Lugar(
      nombre: foto.nombreLugar.isEmpty
          ? '$prefijoSinNombre$titulo'
          : foto.nombreLugar,
      latitud: foto.latitud,
      longitud: foto.longitud,
      urlImagen:
          foto.urlMiniatura.isNotEmpty ? foto.urlMiniatura : foto.urlImagen,
    );
  }
}
