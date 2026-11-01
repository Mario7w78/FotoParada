import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoparada/models/foto_model.dart';
import 'package:fotoparada/services/imagen_compresor.dart';
import 'package:fotoparada/services/photo_service.dart';
import 'package:image/image.dart' as img;

class FakeCompresor implements ImagenCompresor {
  FakeCompresor(this.resultado);

  final ImagenesComprimidas resultado;

  @override
  Future<ImagenesComprimidas> comprimir(Uint8List bytes) async => resultado;
}

void main() {
  late FakeFirebaseFirestore firestore;
  late PhotoService servicio;
  late Directory carpeta;
  late File archivo;

  Future<Foto> subir({
    String uid = 'usuario1',
    PhotoService? con,
    PrivacidadFoto privacidad = PrivacidadFoto.publica,
    String descripcion = 'En la playa',
    File? imagen,
  }) {
    return (con ?? servicio).subirFoto(
      archivo: imagen ?? archivo,
      uid: uid,
      titulo: 'Atardecer',
      descripcion: descripcion,
      categoria: CategoriaFoto.naturaleza,
      latitud: -12.5,
      longitud: -76.25,
      nombreLugar: 'Lima',
      fechaToma: DateTime.utc(2026, 1, 2),
      privacidad: privacidad,
    );
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    servicio = PhotoService(firestore: firestore);
    carpeta = await Directory.systemTemp.createTemp('fotos_test');
    archivo = File('${carpeta.path}/foto.jpg');
    final original = img.Image(width: 1500, height: 1000);
    img.fill(original, color: img.ColorRgb8(200, 120, 40));
    await archivo.writeAsBytes(img.encodeJpg(original));
  });

  tearDown(() => carpeta.delete(recursive: true));

  group('subirFoto', () {
    test('guarda imagen y miniatura en base64 dentro del documento', () async {
      final foto = await subir();

      final doc = await firestore.collection('fotos').doc(foto.id).get();
      final datos = doc.data()!;

      final imagen = img.decodeJpg(base64Decode(datos['imagenBase64']))!;
      final miniatura = img.decodeJpg(base64Decode(datos['miniaturaBase64']))!;
      expect(imagen.width, 1080);
      expect(miniatura.width, 300);
      expect(datos['uid'], 'usuario1');
      expect(datos['titulo'], 'Atardecer');
      expect(datos['privacidad'], 'publica');
      expect(datos['likes'], 0);
      expect(datos.containsKey('urlImagen'), isFalse);
      expect(datos.containsKey('rutaStorage'), isFalse);
    });

    test('devuelve la foto con su id e imágenes', () async {
      final foto = await subir();

      expect(foto.id, isNotEmpty);
      expect(foto.imagenBase64, isNotEmpty);
      expect(foto.miniaturaBase64, isNotEmpty);
    });

    test('un archivo que no existe da un error claro', () async {
      await expectLater(
        subir(imagen: File('${carpeta.path}/no_existe.jpg')),
        throwsA(
          isA<PhotoException>().having(
            (e) => e.message,
            'message',
            contains('leer'),
          ),
        ),
      );
    });

    test('un archivo que no es imagen da un error claro', () async {
      final texto = File('${carpeta.path}/texto.jpg');
      await texto.writeAsString('esto no es una imagen, aunque lo parezca');

      await expectLater(
        subir(imagen: texto),
        throwsA(
          isA<PhotoException>().having(
            (e) => e.message,
            'message',
            contains('Formato'),
          ),
        ),
      );
      expect((await firestore.collection('fotos').get()).docs, isEmpty);
    });

    test('rechaza lo que no cabría en un documento de Firestore', () async {
      // Imagen en el límite: una descripción enorme rebasaría 1 MiB.
      final compresor = FakeCompresor(
        ImagenesComprimidas(
          imagen: Uint8List(maxBytesImagen),
          miniatura: Uint8List(maxBytesMiniatura),
        ),
      );
      final limitado = PhotoService(firestore: firestore, compresor: compresor);

      await expectLater(
        subir(con: limitado, descripcion: 'x' * 100000),
        throwsA(
          isA<PhotoException>().having(
            (e) => e.message,
            'message',
            contains('descripción'),
          ),
        ),
      );
      expect((await firestore.collection('fotos').get()).docs, isEmpty);

      // Con una descripción normal, la misma imagen sí cabe.
      await subir(con: limitado);
      expect((await firestore.collection('fotos').get()).docs, hasLength(1));
    });
  });

  group('consultas', () {
    test('obtenerMisFotos solo trae las del usuario y con imagen', () async {
      await subir();
      await subir(uid: 'otro');

      final fotos = await servicio.obtenerMisFotos('usuario1').first;

      expect(fotos, hasLength(1));
      expect(fotos.single.uid, 'usuario1');
      expect(fotos.single.miniaturaBase64, isNotEmpty);
    });

    test('obtenerFotosPublicas excluye amigos y privadas', () async {
      await subir();
      await subir(privacidad: PrivacidadFoto.amigos);
      await subir(privacidad: PrivacidadFoto.privada);

      final fotos = await servicio.obtenerFotosPublicas().first;

      expect(fotos.map((foto) => foto.privacidad), [PrivacidadFoto.publica]);
    });
  });

  group('actualizarFoto', () {
    test('cambia solo los campos indicados y no toca la imagen', () async {
      final foto = await subir();

      await servicio.actualizarFoto(foto.id, {'titulo': 'Otro'});

      final datos =
          (await firestore.collection('fotos').doc(foto.id).get()).data()!;
      expect(datos['titulo'], 'Otro');
      expect(datos['descripcion'], 'En la playa');
      expect(datos['imagenBase64'], foto.imagenBase64);
      expect(datos['miniaturaBase64'], foto.miniaturaBase64);
    });
  });

  group('eliminarFoto', () {
    test('borra el documento con su imagen', () async {
      final foto = await subir();

      await servicio.eliminarFoto(foto);

      final doc = await firestore.collection('fotos').doc(foto.id).get();
      expect(doc.exists, isFalse);
    });
  });
}
