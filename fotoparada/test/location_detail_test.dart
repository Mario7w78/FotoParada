import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoparada/models/coleccion_model.dart';
import 'package:fotoparada/models/foto_model.dart';
import 'package:fotoparada/repositories/foto_repository.dart';
import 'package:fotoparada/routes/app_routes.dart';
import 'package:fotoparada/services/foto_firestore_service.dart';
import 'package:fotoparada/services/recuerdos_service.dart';
import 'package:fotoparada/view/location_detail_view.dart';
import 'package:fotoparada/viewmodel/location_detail_viewmodel.dart';
import 'package:latlong2/latlong.dart';

import 'interacciones_fakes.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() => firestore = FakeFirebaseFirestore());

  Future<void> guardar(Foto foto) =>
      firestore.collection('fotos').doc(foto.id).set(foto.toMap());

  /// Foto sin relación por nombre con "mi ubicación": solo la une la distancia.
  Foto foto(
    String id, {
    LatLng punto = plazaDeArmas,
    int likes = 0,
    int dia = 1,
    PrivacidadFoto privacidad = PrivacidadFoto.publica,
  }) =>
      fotoEn(id: id, punto: punto, privacidad: privacidad)
          .copyWith(likes: likes, fechaSubida: DateTime(2026, 5, dia));

  final miUbicacion = Lugar.enPunto(
    plazaDeArmas.latitude,
    plazaDeArmas.longitude,
  );

  LocationDetailViewModel crear(Lugar lugar) => LocationDetailViewModel(
        nombreLugar: lugar.nombre,
        latitud: lugar.latitud,
        longitud: lugar.longitud,
        fotoRepository: FotoRepository(
          service: FotoFirestoreService(firestore: firestore),
        ),
        recuerdosService: RecuerdosService(firestore: firestore),
      );

  Future<void> esperar() => Future<void>.delayed(Duration.zero);

  test('el nombre de un punto indica sus coordenadas', () {
    expect(miUbicacion.nombre, 'Cerca de -12.0464, -77.0428');
  });

  test('con coordenadas muestra solo las fotos públicas cercanas', () async {
    await guardar(foto('cerca', punto: const LatLng(-12.0455, -77.0428)));
    await guardar(foto('lejos', punto: const LatLng(-12.1211, -77.0297)));
    await guardar(foto('privada', privacidad: PrivacidadFoto.privada));

    final viewModel = crear(miUbicacion);
    await esperar();

    expect(viewModel.errorMessage, isNull);
    expect(viewModel.fotos.map((f) => f.id), ['cerca']);
    viewModel.dispose();
  });

  test('con coordenadas ordena por recientes y por populares', () async {
    await guardar(foto('antigua', dia: 1, likes: 9));
    await guardar(foto('media', dia: 2, likes: 1));
    await guardar(foto('nueva', dia: 3, likes: 4));

    final viewModel = crear(miUbicacion);
    await esperar();
    expect(viewModel.fotos.map((f) => f.id), ['nueva', 'media', 'antigua']);

    viewModel.cambiarModoOrdenamiento(ModoOrdenamiento.populares);
    await esperar();
    expect(viewModel.fotos.map((f) => f.id), ['antigua', 'nueva', 'media']);
    viewModel.dispose();
  });

  test('sin coordenadas sigue buscando por nombre', () async {
    await guardar(foto('de-la-plaza'));
    await guardar(foto('otra').copyWith(nombreLugar: 'Barranco'));

    final viewModel = LocationDetailViewModel(
      nombreLugar: 'Plaza de Armas',
      fotoRepository: FotoRepository(
        service: FotoFirestoreService(firestore: firestore),
      ),
    );
    await esperar();

    expect(viewModel.fotos.map((f) => f.id), ['de-la-plaza']);
    viewModel.dispose();
  });

  testWidgets('la línea de tiempo recibe las coordenadas del punto',
      (tester) async {
    Object? argumentos;
    await tester.pumpWidget(MaterialApp(
      onGenerateRoute: (settings) {
        if (settings.name != AppRoutes.timeline) return null;
        argumentos = settings.arguments;
        return MaterialPageRoute(builder: (_) => const SizedBox());
      },
      home: LocationDetailView(
        nombreLugar: miUbicacion.nombre,
        latitud: miUbicacion.latitud,
        longitud: miUbicacion.longitud,
        viewModel: crear(miUbicacion),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Línea de tiempo'));
    await tester.pumpAndSettle();

    expect(
      argumentos,
      isA<Lugar>()
          .having((l) => l.latitud, 'latitud', plazaDeArmas.latitude)
          .having((l) => l.longitud, 'longitud', plazaDeArmas.longitude),
    );
  });
}
