import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoparada/models/foto_model.dart';

void main() {
  group('Foto.fromJson', () {
    test('construye una Foto desde un mapa JSON', () {
      final foto = Foto.fromJson({
        'id': 1,
        'url_imagen': 'https://example.com/foto.jpg',
        'titulo': 'Foto de prueba',
        'latitud': 0,
        'longitud': 0,
      });

      expect(foto.id, '1');
      expect(foto.urlImagen, 'https://example.com/foto.jpg');
      expect(foto.titulo, 'Foto de prueba');
      expect(foto.latitud, 0.0);
      expect(foto.longitud, 0.0);
    });
  });

  group('Foto.externa', () {
    test('conserva la URL y no lleva miniatura', () {
      final foto = Foto.externa(
        id: '1',
        urlImagen: 'https://example.com/foto.jpg',
        titulo: 'Externa',
        latitud: 0,
        longitud: 0,
      );

      expect(foto.urlImagen, 'https://example.com/foto.jpg');
      expect(foto.urlMiniatura, isEmpty);
      expect(foto.urlEliminar, isEmpty);
    });
  });

  group('Foto en Firestore', () {
    final fotoCompleta = Foto(
      id: 'abc',
      uid: 'usuario1',
      urlImagen: 'https://i.ibb.co/abc/foto.jpg',
      urlMiniatura: 'https://i.ibb.co/abc/foto-mini.jpg',
      urlEliminar: 'https://ibb.co/abc/borrar',
      titulo: 'Atardecer',
      descripcion: 'En la playa',
      categoria: CategoriaFoto.naturaleza,
      latitud: -12.5,
      longitud: -76.25,
      nombreLugar: 'Lima',
      fechaToma: DateTime.utc(2026, 1, 2),
      fechaSubida: DateTime.utc(2026, 1, 3),
      privacidad: PrivacidadFoto.amigos,
      likes: 7,
    );

    test('toMap y fromMap conservan todos los campos', () {
      final foto = Foto.fromMap('abc', fotoCompleta.toMap());

      expect(foto.id, 'abc');
      expect(foto.uid, 'usuario1');
      expect(foto.urlImagen, 'https://i.ibb.co/abc/foto.jpg');
      expect(foto.urlMiniatura, 'https://i.ibb.co/abc/foto-mini.jpg');
      expect(foto.urlEliminar, 'https://ibb.co/abc/borrar');
      expect(foto.titulo, 'Atardecer');
      expect(foto.descripcion, 'En la playa');
      expect(foto.categoria, CategoriaFoto.naturaleza);
      expect(foto.latitud, -12.5);
      expect(foto.longitud, -76.25);
      expect(foto.nombreLugar, 'Lima');
      expect(foto.fechaToma.isAtSameMomentAs(DateTime.utc(2026, 1, 2)), isTrue);
      expect(
        foto.fechaSubida.isAtSameMomentAs(DateTime.utc(2026, 1, 3)),
        isTrue,
      );
      expect(foto.privacidad, PrivacidadFoto.amigos);
      expect(foto.likes, 7);
    });

    test('toMap guarda enums como texto, fechas como Timestamp y sin id', () {
      final mapa = fotoCompleta.toMap();

      expect(mapa.containsKey('id'), isFalse);
      expect(mapa.containsKey('rutaStorage'), isFalse);
      expect(mapa['categoria'], 'naturaleza');
      expect(mapa['privacidad'], 'amigos');
      expect(mapa['fechaToma'], isA<Timestamp>());
    });

    test('toMap guarda las URLs y ya no guarda base64', () {
      final mapa = fotoCompleta.toMap();

      expect(mapa['urlImagen'], 'https://i.ibb.co/abc/foto.jpg');
      expect(mapa['urlMiniatura'], 'https://i.ibb.co/abc/foto-mini.jpg');
      expect(mapa['urlEliminar'], 'https://ibb.co/abc/borrar');
      expect(mapa.containsKey('imagenBase64'), isFalse);
      expect(mapa.containsKey('miniaturaBase64'), isFalse);
    });

    test('un documento antiguo sin URLs se lee con URLs vacías', () {
      final foto = Foto.fromMap('viejo', {
        'uid': 'usuario1',
        'imagenBase64': 'aW1hZ2Vu',
        'miniaturaBase64': 'bWluaQ==',
        'titulo': 'Antigua',
      });

      expect(foto.urlImagen, isEmpty);
      expect(foto.urlMiniatura, isEmpty);
      expect(foto.urlEliminar, isEmpty);
    });

    test('una privacidad desconocida o ausente se trata como privada', () {
      expect(
        Foto.fromMap('a', {'privacidad': 'otra'}).privacidad,
        PrivacidadFoto.privada,
      );
      expect(Foto.fromMap('a', {}).privacidad, PrivacidadFoto.privada);
    });

    test('tolera fechaSubida nula de un serverTimestamp pendiente', () {
      final foto = Foto.fromMap('a', {'fechaSubida': null});

      expect(foto.fechaSubida, isA<DateTime>());
    });

    test('camposCambiados devuelve solo lo editable que difiere', () {
      expect(fotoCompleta.camposCambiados(fotoCompleta), isEmpty);

      final cambiada = fotoCompleta.copyWith(
        titulo: 'Nuevo',
        categoria: CategoriaFoto.arte,
        fechaToma: DateTime.utc(2020),
        // Estos no son editables y nunca deben enviarse.
        likes: 99,
        uid: 'otro',
        urlImagen: 'https://i.ibb.co/otra.jpg',
        urlMiniatura: 'https://i.ibb.co/otra-mini.jpg',
        urlEliminar: 'https://ibb.co/otra/borrar',
      );

      expect(cambiada.camposCambiados(fotoCompleta), {
        'titulo': 'Nuevo',
        'categoria': 'arte',
        'fechaToma': Timestamp.fromDate(DateTime.utc(2020)),
      });
    });

    test('copyWith cambia solo los campos indicados', () {
      final copia = fotoCompleta.copyWith(
        titulo: 'Nuevo',
        privacidad: PrivacidadFoto.privada,
      );

      expect(copia.titulo, 'Nuevo');
      expect(copia.privacidad, PrivacidadFoto.privada);
      expect(copia.id, fotoCompleta.id);
      expect(copia.uid, fotoCompleta.uid);
      expect(copia.likes, fotoCompleta.likes);
      expect(copia.fechaToma, fotoCompleta.fechaToma);
      expect(copia.urlImagen, fotoCompleta.urlImagen);
      expect(copia.urlMiniatura, fotoCompleta.urlMiniatura);
      expect(copia.urlEliminar, fotoCompleta.urlEliminar);

      final otraImagen = fotoCompleta.copyWith(
        urlMiniatura: 'https://i.ibb.co/otra-mini.jpg',
        urlEliminar: 'https://ibb.co/otra/borrar',
      );
      expect(otraImagen.urlMiniatura, 'https://i.ibb.co/otra-mini.jpg');
      expect(otraImagen.urlEliminar, 'https://ibb.co/otra/borrar');
      expect(otraImagen.urlImagen, fotoCompleta.urlImagen);
    });
  });
}
