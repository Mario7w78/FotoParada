import 'dart:io';
import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoparada/models/foto_model.dart';
import 'package:fotoparada/services/imgbb_service.dart';
import 'package:fotoparada/services/photo_service.dart';
import 'package:image/image.dart' as img;

class FakeImgbb implements ImgbbService {
  final List<Uint8List> subidas = [];
  Object? error;

  @override
  bool tieneClave = true;

  @override
  Future<ImagenSubida> subirImagen(Uint8List bytes) async {
    subidas.add(bytes);
    if (error != null) throw error!;
    final n = subidas.length;
    return ImagenSubida(
      url: 'https://i.ibb.co/$n/foto.jpg',
      urlMiniatura: 'https://i.ibb.co/$n/foto-mini.jpg',
      urlEliminar: 'https://ibb.co/$n/borrar',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeFirebaseFirestore firestore;
  late FakeImgbb imgbb;
  late PhotoService servicio;
  late Directory carpeta;
  late File archivo;

  Future<Foto> subir({
    String uid = 'usuario1',
    PrivacidadFoto privacidad = PrivacidadFoto.publica,
    String descripcion = 'En la playa',
    File? imagen,
  }) {
    return servicio.subirFoto(
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
    imgbb = FakeImgbb();
    servicio = PhotoService(firestore: firestore, imgbb: imgbb);
    carpeta = await Directory.systemTemp.createTemp('fotos_test');
    archivo = File('${carpeta.path}/foto.jpg');
    final original = img.Image(width: 1500, height: 1000);
    img.fill(original, color: img.ColorRgb8(200, 120, 40));
    await archivo.writeAsBytes(img.encodeJpg(original));
  });

  tearDown(() => carpeta.delete(recursive: true));

  group('subirFoto', () {
    test('sube la imagen comprimida a ImgBB y guarda sus URLs', () async {
      final foto = await subir();

      final doc = await firestore.collection('fotos').doc(foto.id).get();
      final datos = doc.data()!;

      final subida = img.decodeJpg(imgbb.subidas.single)!;
      expect(subida.width, 1500);
      expect(datos['urlImagen'], 'https://i.ibb.co/1/foto.jpg');
      expect(datos['urlMiniatura'], 'https://i.ibb.co/1/foto-mini.jpg');
      expect(datos['urlEliminar'], 'https://ibb.co/1/borrar');
      expect(datos['uid'], 'usuario1');
      expect(datos['titulo'], 'Atardecer');
      expect(datos['privacidad'], 'publica');
      expect(datos['likes'], 0);
      expect(datos.containsKey('imagenBase64'), isFalse);
      expect(datos.containsKey('miniaturaBase64'), isFalse);
      expect(datos.containsKey('rutaStorage'), isFalse);
    });

    test('devuelve la foto con su id y URLs', () async {
      final foto = await subir();

      expect(foto.id, isNotEmpty);
      expect(foto.urlImagen, 'https://i.ibb.co/1/foto.jpg');
      expect(foto.urlMiniatura, 'https://i.ibb.co/1/foto-mini.jpg');
      expect(foto.urlEliminar, 'https://ibb.co/1/borrar');
    });

    test('si ImgBB falla no crea el documento', () async {
      imgbb.error = const PhotoException('No se pudo subir la imagen: x');

      await expectLater(
        subir(),
        throwsA(
          isA<PhotoException>().having(
            (e) => e.message,
            'message',
            'No se pudo subir la imagen: x',
          ),
        ),
      );
      expect((await firestore.collection('fotos').get()).docs, isEmpty);
    });

    test('sin clave de ImgBB avisa sin comprimir ni subir', () async {
      imgbb.tieneClave = false;

      await expectLater(
        subir(),
        throwsA(
          isA<PhotoException>().having(
            (e) => e.message,
            'message',
            'Falta IMGBB_API_KEY. Revisa claves.json',
          ),
        ),
      );
      expect(imgbb.subidas, isEmpty);
      expect((await firestore.collection('fotos').get()).docs, isEmpty);
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
      expect(imgbb.subidas, isEmpty);
    });
  });

  group('consultas', () {
    test('obtenerMisFotos solo trae las del usuario y con imagen', () async {
      await subir();
      await subir(uid: 'otro');

      final fotos = await servicio.obtenerMisFotos('usuario1').first;

      expect(fotos, hasLength(1));
      expect(fotos.single.uid, 'usuario1');
      expect(fotos.single.urlMiniatura, isNotEmpty);
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
      expect(datos['urlImagen'], foto.urlImagen);
      expect(datos['urlMiniatura'], foto.urlMiniatura);
      expect(datos['urlEliminar'], foto.urlEliminar);
    });
  });

  group('eliminarFoto', () {
    test('borra el documento sin intentar borrar en ImgBB', () async {
      final foto = await subir();

      await servicio.eliminarFoto(foto);

      final doc = await firestore.collection('fotos').doc(foto.id).get();
      expect(doc.exists, isFalse);
    });
  });
}
