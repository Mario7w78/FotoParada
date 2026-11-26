import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoparada/models/coleccion_model.dart';
import 'package:fotoparada/models/foto_model.dart';
import 'package:fotoparada/services/coleccion_service.dart';
import 'package:fotoparada/services/recuerdos_exception.dart';
import 'package:fotoparada/services/recuerdos_service.dart';

import 'interacciones_fakes.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ColeccionService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = ColeccionService(firestore: firestore);
  });

  Future<Coleccion> leer(String id) async => Coleccion.fromFirestore(
        await firestore.collection('colecciones').doc(id).get(),
      );

  group('colecciones predeterminadas', () {
    test('se crean una sola vez', () async {
      await service.asegurarPredeterminadas('u1');
      await service.asegurarPredeterminadas('u1');

      final colecciones = await service.obtenerColecciones('u1').first;
      expect(
        colecciones.map((c) => c.tipo),
        [TipoColeccion.quieroVisitar, TipoColeccion.misViajes],
      );
      expect(colecciones.first.id, 'u1_quiero_visitar');
    });

    test('no se pueden eliminar ni renombrar', () async {
      await service.asegurarPredeterminadas('u1');
      final quieroVisitar = await leer('u1_quiero_visitar');

      expect(
        () => service.eliminarColeccion(quieroVisitar),
        throwsA(isA<RecuerdosException>()),
      );
      expect(
        () => service.editarColeccion(quieroVisitar, nombre: 'Otra'),
        throwsA(isA<RecuerdosException>()),
      );
    });

    test('cada usuario ve solo las suyas', () async {
      await service.asegurarPredeterminadas('u1');
      await service.crearColeccion(uid: 'u2', nombre: 'Cafés');
      final deU1 = await service.obtenerColecciones('u1').first;
      expect(deU1.every((c) => c.uid == 'u1'), isTrue);
    });
  });

  group('crear y editar', () {
    test('valida el nombre', () async {
      expect(
        () => service.crearColeccion(uid: 'u1', nombre: '   '),
        throwsA(isA<RecuerdosException>()),
      );
      expect(
        () => service.crearColeccion(uid: 'u1', nombre: 'x' * 41),
        throwsA(isA<RecuerdosException>()),
      );
    });

    test('las personalizadas van después de las predeterminadas', () async {
      await service.asegurarPredeterminadas('u1');
      await service.crearColeccion(uid: 'u1', nombre: '  Murales  ');
      final colecciones = await service.obtenerColecciones('u1').first;
      expect(colecciones.last.nombre, 'Murales');
      expect(colecciones.last.tipo, TipoColeccion.personalizada);
    });

    test('renombra una personalizada', () async {
      final creada = await service.crearColeccion(uid: 'u1', nombre: 'Cafés');
      await service.editarColeccion(
        creada,
        nombre: 'Cafés de Barranco',
        descripcion: 'Para el finde',
      );
      final editada = await leer(creada.id);
      expect(editada.nombre, 'Cafés de Barranco');
      expect(editada.descripcion, 'Para el finde');
    });
  });

  group('elementos', () {
    late Coleccion coleccion;

    setUp(() async {
      coleccion = await service.crearColeccion(uid: 'u1', nombre: 'Murales');
    });

    test('agregar suma al contador y no duplica', () async {
      final elemento = ElementoColeccion.desdeFoto(fotoEn(id: 'f1'));

      expect(await service.agregarElemento(coleccion.id, elemento), isTrue);
      expect(await service.agregarElemento(coleccion.id, elemento), isFalse);

      final actual = await leer(coleccion.id);
      expect(actual.cantidad, 1);
      expect(actual.portadaUrl, elemento.urlImagen);
      final elementos = await service.obtenerElementos(coleccion.id).first;
      expect(elementos.single.fotoId, 'f1');
    });

    test('quitar resta y recalcula la portada', () async {
      final primera = ElementoColeccion.desdeFoto(fotoEn(id: 'f1'));
      final segunda = ElementoColeccion.desdeFoto(fotoEn(id: 'f2'));
      await service.agregarElemento(coleccion.id, primera);
      await service.agregarElemento(coleccion.id, segunda);

      await service.quitarElemento(coleccion.id, segunda.id);
      // Quitar algo que ya no está no cambia nada.
      await service.quitarElemento(coleccion.id, segunda.id);

      final actual = await leer(coleccion.id);
      expect(actual.cantidad, 1);
      expect(actual.portadaUrl, primera.urlImagen);
    });

    test('coleccionesQueContienen marca dónde está guardado', () async {
      final otra = await service.crearColeccion(uid: 'u1', nombre: 'Viaje');
      final lugar = ElementoColeccion.desdeLugar(
        const Lugar(nombre: 'Plaza de Armas', latitud: -12, longitud: -77),
      );
      await service.agregarElemento(otra.id, lugar);

      final ids =
          await service.coleccionesQueContienen([coleccion, otra], lugar.id);
      expect(ids, {otra.id});
    });

    test('mover pasa de "Quiero visitar" a "Mis viajes"', () async {
      await service.asegurarPredeterminadas('u1');
      const origen = 'u1_quiero_visitar';
      const destino = 'u1_mis_viajes';
      final lugar = ElementoColeccion.desdeLugar(
        const Lugar(
          nombre: 'Machu Picchu',
          latitud: -13.16,
          longitud: -72.54,
          urlImagen: 'https://i.ibb.co/x/mp.jpg',
        ),
      );
      await service.agregarElemento(origen, lugar);

      await service.moverElemento(
        elemento: lugar,
        origenId: origen,
        destinoId: destino,
      );

      expect((await leer(origen)).cantidad, 0);
      expect((await leer(origen)).portadaUrl, isEmpty);
      expect((await leer(destino)).cantidad, 1);
      final enDestino = await service.obtenerElementos(destino).first;
      expect(enDestino.single.titulo, 'Machu Picchu');
    });

    test('la nota se guarda y se valida su largo', () async {
      final elemento = ElementoColeccion.desdeFoto(fotoEn(id: 'f1'));
      await service.agregarElemento(coleccion.id, elemento);

      await service.actualizarNota(coleccion.id, elemento.id, ' Ir de noche ');
      final elementos = await service.obtenerElementos(coleccion.id).first;
      expect(elementos.single.nota, 'Ir de noche');

      expect(
        () => service.actualizarNota(coleccion.id, elemento.id, 'x' * 201),
        throwsA(isA<RecuerdosException>()),
      );
    });

    test('eliminar la colección borra también sus elementos', () async {
      await service.agregarElemento(
        coleccion.id,
        ElementoColeccion.desdeFoto(fotoEn(id: 'f1')),
      );
      await service.eliminarColeccion(await leer(coleccion.id));

      final doc =
          await firestore.collection('colecciones').doc(coleccion.id).get();
      expect(doc.exists, isFalse);
      final elementos = await firestore
          .collection('colecciones')
          .doc(coleccion.id)
          .collection('elementos')
          .get();
      expect(elementos.docs, isEmpty);
    });
  });

  group('RecuerdosService.fotosDelLugar', () {
    Future<void> guardar(Foto foto) =>
        firestore.collection('fotos').doc(foto.id).set(foto.toMap());

    test('une las públicas con las propias, sin duplicar y por fecha', () async {
      await guardar(fotoEn(id: 'publica-otro', uid: 'u2',
          fechaToma: DateTime(2022)));
      await guardar(fotoEn(id: 'privada-mia', uid: 'u1',
          privacidad: PrivacidadFoto.privada, fechaToma: DateTime(2015)));
      await guardar(fotoEn(id: 'publica-mia', uid: 'u1',
          fechaToma: DateTime(2026)));
      await guardar(fotoEn(id: 'privada-otro', uid: 'u2',
          privacidad: PrivacidadFoto.privada, fechaToma: DateTime(2020)));
      await guardar(
        fotoEn(id: 'otro-lugar', uid: 'u1').copyWith(nombreLugar: 'Barranco'),
      );

      final recuerdos = RecuerdosService(firestore: firestore);
      final fotos =
          await recuerdos.fotosDelLugar('Plaza de Armas', uid: 'u1').first;

      expect(
        fotos.map((f) => f.id),
        ['privada-mia', 'publica-otro', 'publica-mia'],
      );
    });

    test('sin sesión solo trae públicas', () async {
      await guardar(fotoEn(id: 'p', uid: 'u2'));
      await guardar(fotoEn(id: 'x', uid: 'u1',
          privacidad: PrivacidadFoto.privada));

      final fotos = await RecuerdosService(firestore: firestore)
          .fotosDelLugar('Plaza de Armas')
          .first;
      expect(fotos.map((f) => f.id), ['p']);
    });
  });
}
