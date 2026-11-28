import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoparada/models/coleccion_model.dart';
import 'package:fotoparada/models/foto_model.dart';
import 'package:fotoparada/repositories/foto_repository.dart';
import 'package:fotoparada/services/coleccion_service.dart';
import 'package:fotoparada/services/foto_firestore_service.dart';
import 'package:fotoparada/services/recuerdos_service.dart';
import 'package:fotoparada/view/collection_detail_view.dart';
import 'package:fotoparada/view/collections_view.dart';
import 'package:fotoparada/view/compare_photos_view.dart';
import 'package:fotoparada/view/timeline_view.dart';
import 'package:fotoparada/view/widgets/recuerdos_widgets.dart';
import 'package:fotoparada/viewmodel/collection_detail_viewmodel.dart';
import 'package:fotoparada/viewmodel/collections_viewmodel.dart';
import 'package:fotoparada/viewmodel/compare_photos_viewmodel.dart';
import 'package:fotoparada/viewmodel/save_to_collection_viewmodel.dart';
import 'package:fotoparada/viewmodel/timeline_viewmodel.dart';

import 'interacciones_fakes.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ColeccionService colecciones;
  late RecuerdosService recuerdos;
  final auth = FakeAuthConNombre('u1');

  setUp(() {
    firestore = FakeFirebaseFirestore();
    colecciones = ColeccionService(firestore: firestore);
    recuerdos = RecuerdosService(firestore: firestore);
  });

  Future<void> guardarFoto(Foto foto) =>
      firestore.collection('fotos').doc(foto.id).set(foto.toMap());

  Widget app(Widget pantalla) => MaterialApp(home: pantalla);

  /// Pantalla de teléfono (360 x 780) en lugar de los 800 x 600 por defecto.
  void tamanoTelefono(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  group('CollectionsViewModel', () {
    test('crea las predeterminadas y evita nombres repetidos', () async {
      final viewModel = CollectionsViewModel(
        coleccionService: colecciones,
        authService: auth,
      );
      await viewModel.iniciar();
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.predeterminadas.length, 2);
      expect(await viewModel.crearColeccion('Cafés', ''), isNotNull);
      await Future<void>.delayed(Duration.zero);
      expect(await viewModel.crearColeccion(' cafés ', ''), isNull);
      expect(viewModel.errorAccion, contains('ese nombre'));
      viewModel.dispose();
    });
  });

  group('SaveToCollectionViewModel', () {
    test('alterna guardar y quitar en una colección', () async {
      final viewModel = SaveToCollectionViewModel(
        elemento: ElementoColeccion.desdeFoto(fotoEn(id: 'f1')),
        coleccionService: colecciones,
        authService: auth,
      );
      await viewModel.cargar();
      final quieroVisitar = viewModel.colecciones.first;

      expect(viewModel.estaGuardadoEn(quieroVisitar), isFalse);
      await viewModel.alternar(quieroVisitar);
      expect(viewModel.estaGuardadoEn(quieroVisitar), isTrue);
      await viewModel.alternar(quieroVisitar);
      expect(viewModel.guardadoEnAlguna, isFalse);

      expect(await viewModel.crearYGuardar('Favoritas'), isTrue);
      expect(viewModel.colecciones.length, 3);
      expect(viewModel.guardadoEnAlguna, isTrue);
      viewModel.dispose();
    });
  });

  group('TimelineViewModel', () {
    test('filtra "mis recuerdos" y permite comparar con 2 fotos', () async {
      await guardarFoto(fotoEn(id: 'a', uid: 'u2', fechaToma: DateTime(2019)));
      await guardarFoto(fotoEn(id: 'b', uid: 'u1', fechaToma: DateTime(2025)));

      final viewModel = TimelineViewModel(
        nombreLugar: 'Plaza de Armas',
        recuerdosService: recuerdos,
        authService: auth,
      )..iniciar();
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.fotos.length, 2);
      expect(viewModel.puedeComparar, isTrue);
      expect(viewModel.grupos.first.anio, 2019);

      viewModel.alternarOrden();
      expect(viewModel.grupos.first.anio, 2025);

      viewModel.cambiarFiltro(FiltroLineaTiempo.mias);
      expect(viewModel.fotos.map((f) => f.id), ['b']);
      viewModel.dispose();
    });
  });

  group('ComparePhotosViewModel', () {
    test('elige la más antigua y la más reciente, y se puede cambiar', () async {
      await guardarFoto(fotoEn(id: 'vieja', fechaToma: DateTime(2016, 5)));
      await guardarFoto(fotoEn(id: 'media', fechaToma: DateTime(2020, 5)));
      await guardarFoto(fotoEn(id: 'nueva', fechaToma: DateTime(2026, 8)));

      final viewModel = ComparePhotosViewModel(
        args: const ComparePhotosArgs(nombreLugar: 'Plaza de Armas'),
        recuerdosService: recuerdos,
        authService: auth,
      )..iniciar();
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.antes!.id, 'vieja');
      expect(viewModel.despues!.id, 'nueva');
      expect(viewModel.diferencia, '10 años y 3 meses');

      viewModel.elegir(viewModel.fotos[1]); // cambia "antes"
      expect(viewModel.antes!.id, 'media');
      expect(viewModel.ladoActivo, LadoComparacion.despues);

      viewModel.intercambiar();
      expect(viewModel.ordenInvertido, isTrue);

      viewModel.moverDeslizador(3);
      expect(viewModel.posicion, 1);
      viewModel.dispose();
    });
  });

  group('pedirNota', () {
    for (final (boton, esperado) in [
      ('Guardar', 'Ir de noche'),
      ('Cancelar', null),
    ]) {
      testWidgets('$boton cierra el diálogo sin errores', (tester) async {
        String? resultado = 'sin respuesta';
        await tester.pumpWidget(app(Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  resultado = await pedirNota(context, 'Ir de noche'),
              child: const Text('abrir'),
            ),
          ),
        )));
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(boton));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(resultado, esperado);
      });
    }
  });

  group('Pantallas', () {
    testWidgets('CollectionsView muestra predeterminadas y personalizadas',
        (tester) async {
      tamanoTelefono(tester);
      await colecciones.crearColeccion(uid: 'u1', nombre: 'Murales de Lima');
      final viewModel = CollectionsViewModel(
        coleccionService: colecciones,
        authService: auth,
      );

      await tester.pumpWidget(app(CollectionsView(viewModel: viewModel)));
      await tester.pumpAndSettle();

      expect(find.text('Mis colecciones'), findsOneWidget);
      expect(find.text('Quiero visitar'), findsOneWidget);
      expect(find.text('Mis viajes'), findsOneWidget);
      expect(find.text('Murales de Lima'), findsOneWidget);
    });

    testWidgets('CollectionDetailView separa lugares y fotos', (tester) async {
      tamanoTelefono(tester);
      await colecciones.asegurarPredeterminadas('u1');
      const id = 'u1_quiero_visitar';
      await colecciones.agregarElemento(
        id,
        ElementoColeccion.desdeLugar(
          const Lugar(nombre: 'Huacachina', latitud: -14.08, longitud: -75.76),
        ),
      );
      await colecciones.agregarElemento(
        id,
        ElementoColeccion.desdeFoto(fotoEn(id: 'f1')),
      );
      final coleccion = Coleccion.fromFirestore(
        await firestore.collection('colecciones').doc(id).get(),
      );

      await tester.pumpWidget(
        app(
          CollectionDetailView(
            coleccion: coleccion,
            viewModel: CollectionDetailViewModel(
              coleccion: coleccion,
              coleccionService: colecciones,
              fotoRepository: FotoRepository(
                service: FotoFirestoreService(firestore: firestore),
              ),
              authService: auth,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lugares (1)'), findsOneWidget);
      expect(find.text('Fotos (1)'), findsOneWidget);
      expect(find.text('Huacachina'), findsOneWidget);
      // En "Quiero visitar" se puede marcar como visitado.
      expect(find.byTooltip('Ya lo visité'), findsOneWidget);
    });

    testWidgets('TimelineView agrupa por año', (tester) async {
      tamanoTelefono(tester);
      await guardarFoto(fotoEn(id: 'a', fechaToma: DateTime(2018, 3, 2)));
      await guardarFoto(fotoEn(id: 'b', fechaToma: DateTime(2025, 9, 9)));

      await tester.pumpWidget(
        app(
          TimelineView(
            nombreLugar: 'Plaza de Armas',
            viewModel: TimelineViewModel(
              nombreLugar: 'Plaza de Armas',
              recuerdosService: recuerdos,
              authService: auth,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2018'), findsOneWidget);
      expect(find.text('Comparar antes y después'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('2025'), 300);
      expect(find.text('2025'), findsOneWidget);
    });

    testWidgets('ComparePhotosView muestra la diferencia de tiempo',
        (tester) async {
      tamanoTelefono(tester);
      await guardarFoto(fotoEn(id: 'a', fechaToma: DateTime(2020, 1, 1)));
      await guardarFoto(fotoEn(id: 'b', fechaToma: DateTime(2022, 1, 1)));
      const args = ComparePhotosArgs(nombreLugar: 'Plaza de Armas');

      await tester.pumpWidget(
        app(
          ComparePhotosView(
            args: args,
            viewModel: ComparePhotosViewModel(
              args: args,
              recuerdosService: recuerdos,
              authService: auth,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 años entre ambas fotos'), findsOneWidget);
      expect(find.text('ANTES · 2020'), findsOneWidget);

      await tester.tap(find.text('Lado a lado'));
      await tester.pumpAndSettle();
      expect(find.text('ANTES'), findsOneWidget);
      expect(find.text('DESPUÉS'), findsOneWidget);
    });
  });
}
