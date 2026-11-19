import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoparada/models/reaccion_model.dart';
import 'package:fotoparada/services/interaccion_exception.dart';
import 'package:fotoparada/services/interaction_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late InteractionService servicio;

  Future<int> likes() async {
    final doc = await firestore.collection('fotos').doc('foto1').get();
    return doc.data()!['likes'] as int;
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    servicio = InteractionService(firestore: firestore);
    await firestore.collection('fotos').doc('foto1').set({
      'uid': 'duenio',
      'titulo': 'Atardecer',
      'likes': 0,
    });
  });

  group('comentarios', () {
    test('se guardan limpios y se leen en orden', () async {
      await servicio.agregarComentario(
        fotoId: 'foto1',
        uid: 'u1',
        nombreUsuario: 'Ana',
        texto: '  ¡Qué bonita!  ',
      );
      await servicio.agregarComentario(
        fotoId: 'foto1',
        uid: 'u2',
        nombreUsuario: 'Luis',
        texto: 'Increíble',
      );

      final comentarios = await servicio.obtenerComentarios('foto1').first;

      expect(comentarios.map((c) => c.texto), ['¡Qué bonita!', 'Increíble']);
      expect(comentarios.first.nombreUsuario, 'Ana');
      expect(comentarios.first.uid, 'u1');
    });

    test('rechaza un comentario vacío o demasiado largo', () async {
      expect(
        () => servicio.agregarComentario(
          fotoId: 'foto1',
          uid: 'u1',
          nombreUsuario: 'Ana',
          texto: '   ',
        ),
        throwsA(isA<InteraccionException>()),
      );
      expect(
        () => servicio.agregarComentario(
          fotoId: 'foto1',
          uid: 'u1',
          nombreUsuario: 'Ana',
          texto: 'a' * 301,
        ),
        throwsA(isA<InteraccionException>()),
      );
    });

    test('eliminar quita el comentario', () async {
      await servicio.agregarComentario(
        fotoId: 'foto1',
        uid: 'u1',
        nombreUsuario: 'Ana',
        texto: 'Hola',
      );
      final id = (await servicio.obtenerComentarios('foto1').first).single.id;

      await servicio.eliminarComentario('foto1', id);

      expect(await servicio.obtenerComentarios('foto1').first, isEmpty);
    });
  });

  group('reacciones', () {
    test('reaccionar suma un like y guarda el tipo', () async {
      await servicio.reaccionar(
        fotoId: 'foto1',
        uid: 'u1',
        tipo: TipoReaccion.meEncanta,
      );

      final reacciones = await servicio.obtenerReacciones('foto1').first;
      expect(reacciones.single.uid, 'u1');
      expect(reacciones.single.tipo, TipoReaccion.meEncanta);
      expect(await likes(), 1);
    });

    test('la misma reacción otra vez la quita y resta el like', () async {
      await servicio.reaccionar(
        fotoId: 'foto1',
        uid: 'u1',
        tipo: TipoReaccion.meGusta,
      );
      await servicio.reaccionar(
        fotoId: 'foto1',
        uid: 'u1',
        tipo: TipoReaccion.meGusta,
      );

      expect(await servicio.obtenerReacciones('foto1').first, isEmpty);
      expect(await likes(), 0);
    });

    test('cambiar de reacción no altera el contador', () async {
      await servicio.reaccionar(
        fotoId: 'foto1',
        uid: 'u1',
        tipo: TipoReaccion.meGusta,
      );
      await servicio.reaccionar(
        fotoId: 'foto1',
        uid: 'u1',
        tipo: TipoReaccion.aplauso,
      );

      final reacciones = await servicio.obtenerReacciones('foto1').first;
      expect(reacciones.single.tipo, TipoReaccion.aplauso);
      expect(await likes(), 1);
    });

    test('cada usuario cuenta una sola vez', () async {
      for (final uid in ['u1', 'u2', 'u3']) {
        await servicio.reaccionar(
          fotoId: 'foto1',
          uid: uid,
          tipo: TipoReaccion.asombro,
        );
      }

      expect(await servicio.obtenerReacciones('foto1').first, hasLength(3));
      expect(await likes(), 3);
    });
  });
}
