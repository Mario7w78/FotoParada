import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoparada/models/foto_model.dart';
import 'package:fotoparada/repositories/foto_repository.dart';
import 'package:fotoparada/routes/app_routes.dart';
import 'package:fotoparada/services/foto_firestore_service.dart';
import 'package:fotoparada/services/interaction_service.dart';
import 'package:fotoparada/view/Map/Components/nearby_photos_section.dart';
import 'package:fotoparada/view/photo_interactions_view.dart';
import 'package:fotoparada/view/widgets/foto_completa.dart';
import 'package:fotoparada/view/widgets/interaccion_widgets.dart';
import 'package:fotoparada/viewmodel/map_viewmodel.dart';
import 'package:fotoparada/viewmodel/photo_interactions_viewmodel.dart';
import 'package:geolocator/geolocator.dart';

import 'interacciones_fakes.dart';

/// Mapa con una ubicación fija y una sola foto cercana, sin usar el GPS.
class _MapaConFoto extends MapViewModel {
  _MapaConFoto(this.foto)
      : super(
          fotoRepository: FotoRepository(
            service: FotoFirestoreService(firestore: FakeFirebaseFirestore()),
          ),
        );

  final Foto foto;

  @override
  Position? get currentPosition => Position(
        latitude: foto.latitud,
        longitude: foto.longitud,
        timestamp: DateTime(2026),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

  @override
  List<({Foto foto, double distancia})> get fotosCercanas =>
      [(foto: foto, distancia: 20)];
}

void main() {
  group('Descubre cerca de ti', () {
    final foto = fotoEn(id: 'f1');
    Object? abierta;

    Future<void> mostrar(WidgetTester tester) async {
      abierta = null;
      final mapa = _MapaConFoto(foto);
      addTearDown(mapa.dispose);

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            if (settings.name != AppRoutes.photoInteractions) return null;
            abierta = settings.arguments;
            return MaterialPageRoute<void>(
              builder: (_) => const Text('detalle'),
            );
          },
          home: Scaffold(body: NearbyPhotosSection(mapViewModel: mapa)),
        ),
      );
    }

    testWidgets('tocar una tarjeta abre el detalle de la foto', (tester) async {
      await mostrar(tester);

      await tester.tap(find.text('Mural f1'));
      await tester.pumpAndSettle();

      expect(find.text('detalle'), findsOneWidget);
      expect(abierta, same(foto));
    });

    testWidgets('tocar una foto en "Ver Todos" también la abre',
        (tester) async {
      await mostrar(tester);

      await tester.tap(find.text('Ver Todos'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(find.text('detalle'), findsOneWidget);
      expect(abierta, same(foto));
    });
  });

  testWidgets('tocar la imagen del detalle la muestra completa y se cierra',
      (tester) async {
    final foto = fotoEn(id: 'f1', uid: 'duenio');
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoInteractionsView(
          foto: foto,
          viewModel: PhotoInteractionsViewModel(
            foto: foto,
            interactionService:
                InteractionService(firestore: FakeFirebaseFirestore()),
            authService: FakeAuthConNombre('u1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FotoConDegradado));
    await tester.pumpAndSettle();

    final vista = tester.widget<FotoCompletaView>(
      find.byType(FotoCompletaView),
    );
    expect(vista.url, foto.urlImagen);
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(FotoCompletaView), findsNothing);
  });
}
