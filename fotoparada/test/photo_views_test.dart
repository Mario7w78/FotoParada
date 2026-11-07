import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoparada/models/foto_model.dart';
import 'package:fotoparada/routes/app_routes.dart';
import 'package:fotoparada/services/photo_service.dart';
import 'package:fotoparada/view/edit_photo_view.dart';
import 'package:fotoparada/view/my_photos_view.dart';
import 'package:fotoparada/view/widgets/foto_widgets.dart';
import 'package:fotoparada/viewmodel/edit_photo_viewmodel.dart';
import 'package:fotoparada/viewmodel/my_photos_viewmodel.dart';

import 'fotos_fakes.dart';

// Las imágenes y el mapa nunca terminan de cargar en una prueba, así que no se
// puede usar pumpAndSettle.
Future<void> avanzar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void usarPantallaGrande(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('EditPhotoView', () {
    late FakePhotoService servicio;

    Future<void> abrir(WidgetTester tester, {Foto? fotoInicial}) async {
      usarPantallaGrande(tester);
      servicio = FakePhotoService();
      final foto = fotoInicial ?? crearFoto();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditPhotoView(
                      foto: foto,
                      viewModel: EditPhotoViewModel(
                        foto: foto,
                        photoService: servicio,
                        geocodingService: FakeGeocoding(),
                      ),
                    ),
                  ),
                ),
                child: const Text('Mis fotos'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mis fotos'));
      await avanzar(tester);
    }

    ElevatedButton botonGuardar(WidgetTester tester) {
      return tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Guardar cambios'),
      );
    }

    Finder campoTitulo() => find.widgetWithText(TextFormField, 'Título');

    testWidgets('muestra los datos de la foto', (tester) async {
      await abrir(tester);

      final imagen = tester.widget<Image>(
        find.descendant(
          of: find.byType(ImagenFoto),
          matching: find.byType(Image),
        ),
      );
      expect(imagen.image, isA<NetworkImage>());
      expect((imagen.image as NetworkImage).url, urlImagenPrueba);

      expect(find.text('Atardecer'), findsOneWidget);
      expect(find.text('En la playa'), findsOneWidget);
      expect(find.text('Lima'), findsOneWidget);
      expect(find.text('Fecha de la foto: 02/01/2026 10:30'), findsOneWidget);
    });

    testWidgets('Guardar se habilita solo con cambios', (tester) async {
      await abrir(tester);
      expect(botonGuardar(tester).onPressed, isNull);

      await tester.enterText(campoTitulo(), 'Otro');
      await avanzar(tester);
      expect(botonGuardar(tester).onPressed, isNotNull);

      await tester.enterText(campoTitulo(), 'Atardecer');
      await avanzar(tester);
      expect(botonGuardar(tester).onPressed, isNull);
    });

    testWidgets('sin cambios, atrás sale sin preguntar', (tester) async {
      await abrir(tester);

      await tester.tap(find.byType(BackButton));
      await avanzar(tester);

      expect(find.text('¿Descartar los cambios?'), findsNothing);
      expect(find.byType(EditPhotoView), findsNothing);
    });

    testWidgets('con cambios, atrás pregunta y se puede seguir editando',
        (tester) async {
      await abrir(tester);
      await tester.enterText(campoTitulo(), 'Otro');
      await avanzar(tester);

      await tester.tap(find.byType(BackButton));
      await avanzar(tester);
      expect(find.text('¿Descartar los cambios?'), findsOneWidget);

      await tester.tap(find.text('Seguir editando'));
      await avanzar(tester);
      expect(find.byType(EditPhotoView), findsOneWidget);
      expect(find.text('Otro'), findsOneWidget);
    });

    testWidgets('con cambios, Descartar vuelve sin guardar', (tester) async {
      await abrir(tester);
      await tester.enterText(campoTitulo(), 'Otro');
      await avanzar(tester);

      await tester.tap(find.byType(BackButton));
      await avanzar(tester);
      await tester.tap(find.text('Descartar'));
      await avanzar(tester);

      expect(find.byType(EditPhotoView), findsNothing);
      expect(servicio.actualizaciones, 0);
    });

    testWidgets('guardar envía los cambios, avisa y vuelve', (tester) async {
      await abrir(tester);
      await tester.enterText(campoTitulo(), 'Otro');
      await avanzar(tester);

      await tester.tap(find.text('Guardar cambios'));
      await avanzar(tester);

      expect(servicio.camposActualizados, {'titulo': 'Otro'});
      expect(find.byType(EditPhotoView), findsNothing);
      expect(find.text('Cambios guardados'), findsOneWidget);
      expect(find.text('¿Descartar los cambios?'), findsNothing);
    });

    testWidgets('si guardar falla, avisa y no sale', (tester) async {
      await abrir(tester);
      servicio.errorActualizar = const PhotoException('Sin conexión');
      await tester.enterText(campoTitulo(), 'Otro');
      await avanzar(tester);

      await tester.tap(find.text('Guardar cambios'));
      await avanzar(tester);

      expect(find.byType(EditPhotoView), findsOneWidget);
      expect(find.text('Sin conexión'), findsOneWidget);
    });

    testWidgets('eliminar pide confirmación y se puede cancelar',
        (tester) async {
      await abrir(tester);

      await tester.tap(find.text('Eliminar foto'));
      await avanzar(tester);
      expect(find.text('¿Eliminar esta foto?'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await avanzar(tester);

      expect(servicio.eliminadas, isEmpty);
      expect(find.byType(EditPhotoView), findsOneWidget);
    });

    testWidgets('eliminar confirmado borra, avisa y vuelve, aun con cambios',
        (tester) async {
      await abrir(tester);
      await tester.enterText(campoTitulo(), 'Otro');
      await avanzar(tester);

      await tester.tap(find.text('Eliminar foto'));
      await avanzar(tester);
      await tester.tap(find.text('Eliminar'));
      await avanzar(tester);

      expect(servicio.eliminadas, hasLength(1));
      expect(find.byType(EditPhotoView), findsNothing);
      expect(find.text('Foto eliminada'), findsOneWidget);
      expect(find.text('¿Descartar los cambios?'), findsNothing);
    });

    testWidgets('la fecha se cambia con el selector', (tester) async {
      await abrir(tester);

      await tester.tap(find.text('Fecha de la foto: 02/01/2026 10:30'));
      await avanzar(tester);
      await tester.tap(find.text('15'));
      await tester.pump();
      await tester.tap(find.text('Aceptar'));
      await avanzar(tester);

      expect(find.text('Fecha de la foto: 15/01/2026 10:30'), findsOneWidget);
      expect(botonGuardar(tester).onPressed, isNotNull);
    });
  });

  group('MyPhotosView', () {
    late FakePhotoService servicio;

    Future<void> abrir(WidgetTester tester) async {
      usarPantallaGrande(tester);
      servicio = FakePhotoService();
      await tester.pumpWidget(
        MaterialApp(
          home: MyPhotosView(
            viewModel: MyPhotosViewModel(
              photoService: servicio,
              authService: FakeAuth('usuario1'),
            ),
          ),
          routes: {
            AppRoutes.upload: (_) => const Text('Pantalla de subida'),
          },
          onGenerateRoute: (settings) => MaterialPageRoute(
            builder: (_) => Text(
              'Editando ${(settings.arguments as Foto).id}',
            ),
          ),
        ),
      );
    }

    Future<void> emitir(WidgetTester tester, List<Foto> fotos) async {
      servicio.misFotos.add(fotos);
      await avanzar(tester);
    }

    testWidgets('muestra la carga y luego el estado vacío', (tester) async {
      await abrir(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await emitir(tester, []);
      expect(find.text('Subir mi primera foto'), findsOneWidget);

      await tester.tap(find.text('Subir mi primera foto'));
      await avanzar(tester);
      expect(find.text('Pantalla de subida'), findsOneWidget);
    });

    testWidgets('muestra el error y permite reintentar', (tester) async {
      await abrir(tester);
      servicio.misFotos.addError(const PhotoException('Sin permiso'));
      await avanzar(tester);
      expect(find.text('Sin permiso'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await avanzar(tester);
      await emitir(tester, [crearFoto()]);

      expect(find.text('Sin permiso'), findsNothing);
      expect(find.byIcon(Icons.public), findsWidgets);
    });

    testWidgets('grilla de 3 columnas con el ícono de privacidad',
        (tester) async {
      await abrir(tester);
      await emitir(tester, [
        crearFoto(id: 'a', privacidad: PrivacidadFoto.amigos),
      ]);

      final delegado = tester
          .widget<GridView>(find.byType(GridView))
          .gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegado.crossAxisCount, 3);

      final grilla = find.byType(GridView);
      expect(
        find.descendant(of: grilla, matching: find.byIcon(Icons.group)),
        findsOneWidget,
      );
    });

    testWidgets('la grilla usa la miniatura, no la imagen completa',
        (tester) async {
      await abrir(tester);
      await emitir(tester, [crearFoto(id: 'a')]);

      final imagen = tester.widget<Image>(find.byType(Image));
      expect((imagen.image as NetworkImage).url, urlMiniaturaPrueba);
    });

    testWidgets('sin miniatura muestra el ícono de error', (tester) async {
      await abrir(tester);
      await emitir(tester, [
        crearFoto(id: 'a').copyWith(urlMiniatura: ''),
        crearFoto(id: 'b').copyWith(urlMiniatura: ''),
      ]);

      expect(find.byIcon(Icons.broken_image), findsNWidgets(2));
    });

    testWidgets('los chips filtran y avisan si no hay resultados',
        (tester) async {
      await abrir(tester);
      await emitir(tester, [
        crearFoto(id: 'a'),
        crearFoto(id: 'b', privacidad: PrivacidadFoto.amigos),
      ]);
      expect(find.byKey(const ValueKey('a')), findsOneWidget);
      expect(find.byKey(const ValueKey('b')), findsOneWidget);

      await tester.tap(find.text('Amigos'));
      await avanzar(tester);
      expect(find.byKey(const ValueKey('a')), findsNothing);
      expect(find.byKey(const ValueKey('b')), findsOneWidget);

      await tester.tap(find.text('Privada'));
      await avanzar(tester);
      expect(find.text('No tienes fotos con esta privacidad.'), findsOneWidget);
      expect(find.text('Subir mi primera foto'), findsNothing);
    });

    testWidgets('tocar una foto abre la edición con esa foto', (tester) async {
      await abrir(tester);
      await emitir(tester, [crearFoto(id: 'a')]);

      await tester.tap(find.byKey(const ValueKey('a')));
      await avanzar(tester);

      expect(find.text('Editando a'), findsOneWidget);
    });

    testWidgets('mantener presionado permite eliminar tras confirmar',
        (tester) async {
      await abrir(tester);
      final foto = crearFoto(id: 'a');
      await emitir(tester, [foto]);

      await tester.longPress(find.byKey(const ValueKey('a')));
      await avanzar(tester);
      await tester.tap(find.text('Eliminar foto'));
      await avanzar(tester);
      expect(servicio.eliminadas, isEmpty);

      servicio.eliminarPendiente = Completer<void>();
      await tester.tap(find.text('Eliminar'));
      await avanzar(tester);
      expect(servicio.eliminadas, [foto]);
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      servicio.eliminarPendiente!.complete();
      await avanzar(tester);
      expect(find.text('Foto eliminada'), findsOneWidget);
    });

    testWidgets('si eliminar falla, muestra el motivo', (tester) async {
      await abrir(tester);
      await emitir(tester, [crearFoto(id: 'a')]);
      servicio.errorEliminar = const PhotoException('Sin permiso');

      await tester.longPress(find.byKey(const ValueKey('a')));
      await avanzar(tester);
      await tester.tap(find.text('Eliminar foto'));
      await avanzar(tester);
      await tester.tap(find.text('Eliminar'));
      await avanzar(tester);

      expect(find.text('Sin permiso'), findsOneWidget);
      expect(find.byKey(const ValueKey('a')), findsOneWidget);
    });
  });
}
