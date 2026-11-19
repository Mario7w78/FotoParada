import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoparada/models/reaccion_model.dart';
import 'package:fotoparada/services/challenge_service.dart';
import 'package:fotoparada/services/interaction_service.dart';
import 'package:fotoparada/view/challenges_view.dart';
import 'package:fotoparada/view/photo_interactions_view.dart';
import 'package:fotoparada/viewmodel/challenges_viewmodel.dart';
import 'package:fotoparada/viewmodel/photo_interactions_viewmodel.dart';

import 'interacciones_fakes.dart';

void main() {
  group('PhotoInteractionsView', () {
    late FakeFirebaseFirestore firestore;
    late InteractionService servicio;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      servicio = InteractionService(firestore: firestore);
      await firestore.collection('fotos').doc('f1').set({'likes': 0});
    });

    Future<void> abrir(WidgetTester tester, {String uid = 'u1'}) async {
      final foto = fotoEn(id: 'f1', uid: 'duenio');
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoInteractionsView(
            foto: foto,
            viewModel: PhotoInteractionsViewModel(
              foto: foto,
              interactionService: servicio,
              authService: FakeAuthConNombre(uid, displayName: 'Ana Pérez'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('sin comentarios invita a comentar', (tester) async {
      await abrir(tester);

      expect(find.text('Mural f1'), findsOneWidget);
      expect(find.text('Comentarios (0)'), findsOneWidget);
      expect(find.textContaining('¡Sé el primero!'), findsOneWidget);
    });

    testWidgets('publicar un comentario lo muestra y limpia el campo',
        (tester) async {
      await abrir(tester);

      await tester.enterText(find.byType(TextField), 'Qué buena luz');
      await tester.tap(find.byTooltip('Enviar'));
      await tester.pumpAndSettle();

      expect(find.text('Qué buena luz'), findsOneWidget);
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('Comentarios (1)'), findsOneWidget);
      final campo = tester.widget<TextField>(find.byType(TextField));
      expect(campo.controller!.text, isEmpty);
    });

    testWidgets('solo el autor ve el botón para eliminar su comentario',
        (tester) async {
      await servicio.agregarComentario(
        fotoId: 'f1',
        uid: 'otro',
        nombreUsuario: 'Luis',
        texto: 'Hola',
      );
      await abrir(tester);
      expect(find.byTooltip('Eliminar comentario'), findsNothing);

      await servicio.agregarComentario(
        fotoId: 'f1',
        uid: 'u1',
        nombreUsuario: 'Ana Pérez',
        texto: 'Mío',
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Eliminar comentario'), findsOneWidget);
    });

    testWidgets('reaccionar actualiza el conteo y el like de la foto',
        (tester) async {
      await abrir(tester);

      final boton = find.text(TipoReaccion.meEncanta.emoji);
      await tester.ensureVisible(boton);
      await tester.pumpAndSettle();
      await tester.tap(boton);
      await tester.pumpAndSettle();

      expect(find.textContaining('Reaccionaste con "Me encanta"'),
          findsOneWidget);
      final foto = await firestore.collection('fotos').doc('f1').get();
      expect(foto.data()!['likes'], 1);
    });
  });

  group('ChallengesView', () {
    testWidgets('muestra los retos activos y filtra los finalizados',
        (tester) async {
      final firestore = FakeFirebaseFirestore();
      final servicio = ChallengeService(firestore: firestore);
      final activo = retoDePrueba(id: 'activo');
      final vencido = retoDePrueba(
        id: 'vencido',
        fechaInicio: DateTime(2025, 1, 1),
        fechaFin: DateTime(2025, 1, 2),
      );
      await firestore.collection('retos').doc('activo').set(activo.toMap());
      await firestore.collection('retos').doc('vencido').set({
        ...vencido.toMap(),
        'titulo': 'Reto viejo',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ChallengesView(
            viewModel: ChallengesViewModel(
              challengeService: servicio,
              authService: FakeAuthConNombre('u1'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Murales del centro'), findsOneWidget);
      expect(find.text('Reto viejo'), findsNothing);
      expect(find.text('Arte'), findsOneWidget);

      await tester.tap(find.text('Finalizados'));
      await tester.pumpAndSettle();

      expect(find.text('Reto viejo'), findsOneWidget);
      expect(find.text('Murales del centro'), findsNothing);
    });
  });
}
