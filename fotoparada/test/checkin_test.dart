import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoparada/models/checkin_model.dart';
import 'package:fotoparada/services/checkin_service.dart';
import 'package:fotoparada/services/foto_metadata_service.dart';
import 'package:fotoparada/viewmodel/checkin_viewmodel.dart';
import 'package:latlong2/latlong.dart';

import 'interacciones_fakes.dart';

void main() {
  const plaza = LugarCheckIn(
    nombre: 'Plaza de Armas',
    latitud: -12.0464,
    longitud: -77.0428,
  );

  late FakeFirebaseFirestore firestore;
  late FakeMetadata gps;
  late CheckInService servicio;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    gps = FakeMetadata();
    servicio = CheckInService(firestore: firestore, metadataService: gps);
  });

  group('CheckInService', () {
    test('mide la distancia en metros', () {
      final distancia = servicio.distanciaMetros(
        plazaDeArmas,
        const LatLng(-12.0455, -77.0428),
      );
      expect(distancia, inInclusiveRange(90, 110));
    });

    test('no registra un check-in fuera del radio', () {
      expect(
        () => servicio.registrar(
          uid: 'u1',
          lugar: plaza,
          distanciaMetros: 500,
        ),
        throwsA(anything),
      );
    });

    test('lista solo los check-ins del usuario, el más reciente primero',
        () async {
      await firestore.collection('checkins').add(
            CheckIn(
              id: '',
              uid: 'u1',
              nombreLugar: 'Antiguo',
              latitud: 0,
              longitud: 0,
              distanciaMetros: 10,
              fecha: DateTime(2026, 1, 1),
            ).toMap(),
          );
      await firestore.collection('checkins').add(
            CheckIn(
              id: '',
              uid: 'otro',
              nombreLugar: 'Ajeno',
              latitud: 0,
              longitud: 0,
              distanciaMetros: 10,
              fecha: DateTime(2026, 6, 1),
            ).toMap(),
          );
      await servicio.registrar(uid: 'u1', lugar: plaza, distanciaMetros: 20);

      final lista = await servicio.obtenerMisCheckIns('u1').first;
      expect(lista.map((c) => c.nombreLugar), ['Plaza de Armas', 'Antiguo']);
    });
  });

  group('CheckInViewModel', () {
    late CheckInViewModel viewModel;

    setUp(() {
      viewModel = CheckInViewModel(
        lugar: plaza,
        checkInService: servicio,
        authService: FakeAuthConNombre('u1'),
      );
    });

    tearDown(() => viewModel.dispose());

    test('dentro del radio valida y guarda el check-in', () async {
      gps.posicion = const LatLng(-12.0460, -77.0428); // ~45 m

      final exito = await viewModel.hacerCheckIn();

      expect(exito, isTrue);
      expect(viewModel.estado, EstadoCheckIn.validado);
      expect(viewModel.distanciaMetros, lessThan(150));
      final guardados = await firestore.collection('checkins').get();
      expect(guardados.docs.single.data()['uid'], 'u1');
    });

    test('fuera del radio informa la distancia y no guarda nada', () async {
      gps.posicion = const LatLng(-12.1211, -77.0297); // Miraflores

      final exito = await viewModel.hacerCheckIn();

      expect(exito, isFalse);
      expect(viewModel.estado, EstadoCheckIn.fueraDeRango);
      expect(viewModel.distanciaMetros, greaterThan(1000));
      expect((await firestore.collection('checkins').get()).docs, isEmpty);
    });

    test('sin GPS muestra el motivo', () async {
      gps.error = const UbicacionException('Activa la ubicación');

      final exito = await viewModel.hacerCheckIn();

      expect(exito, isFalse);
      expect(viewModel.estado, EstadoCheckIn.pendiente);
      expect(viewModel.errorMessage, 'Activa la ubicación');
    });

    test('si ya hizo check-in hoy en el lugar, aparece validado', () async {
      await servicio.registrar(uid: 'u1', lugar: plaza, distanciaMetros: 30);

      viewModel.iniciar();
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.yaHizoCheckInHoy, isTrue);
      expect(viewModel.estado, EstadoCheckIn.validado);
    });
  });
}
