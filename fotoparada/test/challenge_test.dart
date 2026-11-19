import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoparada/models/foto_model.dart';
import 'package:fotoparada/models/reto_model.dart';
import 'package:fotoparada/services/challenge_service.dart';
import 'package:fotoparada/services/interaccion_exception.dart';
import 'package:latlong2/latlong.dart';

import 'interacciones_fakes.dart';

void main() {
  group('Reto.motivoNoCumple', () {
    final reto = retoDePrueba();

    test('acepta una foto pública, de la categoría y dentro del radio', () {
      // ~100 m al norte de la plaza.
      final cerca = fotoEn(punto: const LatLng(-12.0455, -77.0428));
      expect(reto.motivoNoCumple(cerca), isNull);
    });

    test('rechaza fotos privadas', () {
      final foto = fotoEn(privacidad: PrivacidadFoto.privada);
      expect(reto.motivoNoCumple(foto), contains('pública'));
    });

    test('rechaza otra categoría', () {
      final foto = fotoEn(categoria: CategoriaFoto.comida);
      expect(reto.motivoNoCumple(foto), contains('categoría'));
    });

    test('rechaza fotos fuera del radio', () {
      // Miraflores, a varios km.
      final lejos = fotoEn(punto: const LatLng(-12.1211, -77.0297));
      expect(reto.motivoNoCumple(lejos), contains('200 m'));
    });

    test('rechaza fotos tomadas antes del reto', () {
      final vieja = fotoEn(fechaToma: DateTime(2020));
      expect(reto.motivoNoCumple(vieja), contains('activo'));
    });

    test('sin categoría ni lugar acepta cualquier foto pública', () {
      final libre = retoDePrueba(categoria: null, punto: null);
      final foto = fotoEn(
        categoria: CategoriaFoto.mascotas,
        punto: const LatLng(40.4, -3.7),
      );
      expect(libre.motivoNoCumple(foto), isNull);
    });
  });

  test('estaActivo respeta las fechas', () {
    final ahora = DateTime(2026, 11, 18);
    final reto = retoDePrueba(
      fechaInicio: DateTime(2026, 11, 10),
      fechaFin: DateTime(2026, 11, 20),
    );
    expect(reto.estaActivo(ahora), isTrue);
    expect(reto.estaActivo(DateTime(2026, 11, 21)), isFalse);
    expect(reto.estaActivo(DateTime(2026, 11, 9)), isFalse);
  });

  test('toMap y fromMap conservan los datos', () {
    final original = retoDePrueba();
    final copia = Reto.fromMap(original.id, original.toMap());

    expect(copia.titulo, original.titulo);
    expect(copia.categoria, CategoriaFoto.arte);
    expect(copia.latitud, original.latitud);
    expect(copia.radioMetros, 200);
    expect(copia.fotosObjetivo, 2);
    expect(copia.fechaFin, original.fechaFin);
  });

  group('ChallengeService', () {
    late FakeFirebaseFirestore firestore;
    late ChallengeService servicio;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      servicio = ChallengeService(firestore: firestore);
    });

    test('crea y lista retos', () async {
      await servicio.crearReto(
        creadorUid: 'u1',
        creadorNombre: 'Franco',
        titulo: '  Encuentra un mural  ',
        descripcion: '',
        fechaFin: DateTime.now().add(const Duration(days: 3)),
      );

      final retos = await servicio.obtenerRetos().first;
      expect(retos.single.titulo, 'Encuentra un mural');
      expect(retos.single.categoria, isNull);
      expect(retos.single.tieneUbicacion, isFalse);
    });

    test('no crea retos sin título o ya vencidos', () {
      expect(
        () => servicio.crearReto(
          creadorUid: 'u1',
          creadorNombre: 'Franco',
          titulo: '',
          descripcion: '',
          fechaFin: DateTime.now().add(const Duration(days: 1)),
        ),
        throwsA(isA<InteraccionException>()),
      );
      expect(
        () => servicio.crearReto(
          creadorUid: 'u1',
          creadorNombre: 'Franco',
          titulo: 'Reto',
          descripcion: '',
          fechaFin: DateTime.now().subtract(const Duration(days: 1)),
        ),
        throwsA(isA<InteraccionException>()),
      );
    });

    test('enviar fotos registra el avance sin duplicados', () async {
      final reto = retoDePrueba();

      await servicio.enviarFoto(
        reto: reto,
        foto: fotoEn(id: 'a'),
        uid: 'u1',
        nombreUsuario: 'Franco',
      );
      await servicio.enviarFoto(
        reto: reto,
        foto: fotoEn(id: 'a'),
        uid: 'u1',
        nombreUsuario: 'Franco',
      );
      await servicio.enviarFoto(
        reto: reto,
        foto: fotoEn(id: 'b'),
        uid: 'u1',
        nombreUsuario: 'Franco',
      );

      final participantes = await servicio.obtenerParticipantes(reto.id).first;
      expect(participantes.single.fotoIds, ['a', 'b']);
      expect(participantes.single.completo(reto), isTrue);
    });

    test('no acepta fotos que no cumplen o de otro usuario', () async {
      final reto = retoDePrueba();

      expect(
        () => servicio.enviarFoto(
          reto: reto,
          foto: fotoEn(categoria: CategoriaFoto.comida),
          uid: 'u1',
          nombreUsuario: 'Franco',
        ),
        throwsA(isA<InteraccionException>()),
      );
      expect(
        () => servicio.enviarFoto(
          reto: reto,
          foto: fotoEn(uid: 'otro'),
          uid: 'u1',
          nombreUsuario: 'Franco',
        ),
        throwsA(isA<InteraccionException>()),
      );
    });

    test('ordena a los participantes por fotos enviadas', () async {
      final reto = retoDePrueba(fotosObjetivo: 3);
      await servicio.enviarFoto(
        reto: reto,
        foto: fotoEn(id: 'a', uid: 'u1'),
        uid: 'u1',
        nombreUsuario: 'Uno',
      );
      for (final id in ['b', 'c']) {
        await servicio.enviarFoto(
          reto: reto,
          foto: fotoEn(id: id, uid: 'u2'),
          uid: 'u2',
          nombreUsuario: 'Dos',
        );
      }

      final participantes = await servicio.obtenerParticipantes(reto.id).first;
      expect(participantes.map((p) => p.nombreUsuario), ['Dos', 'Uno']);
    });

    test('quitar una foto la retira del avance', () async {
      final reto = retoDePrueba();
      await servicio.enviarFoto(
        reto: reto,
        foto: fotoEn(id: 'a'),
        uid: 'u1',
        nombreUsuario: 'Franco',
      );

      await servicio.quitarFoto(retoId: reto.id, uid: 'u1', fotoId: 'a');

      final participantes = await servicio.obtenerParticipantes(reto.id).first;
      expect(participantes.single.fotoIds, isEmpty);
    });
  });
}
