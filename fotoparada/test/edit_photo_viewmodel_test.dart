import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoparada/models/foto_model.dart';
import 'package:fotoparada/services/photo_service.dart';
import 'package:fotoparada/viewmodel/edit_photo_viewmodel.dart';

import 'fotos_fakes.dart';

void main() {
  late FakePhotoService servicio;
  late FakeGeocoding geocoding;
  late EditPhotoViewModel viewModel;

  setUp(() {
    servicio = FakePhotoService();
    geocoding = FakeGeocoding();
    viewModel = EditPhotoViewModel(
      foto: crearFoto(),
      photoService: servicio,
      geocodingService: geocoding,
    );
  });

  group('hayCambios', () {
    test('es false al empezar', () {
      expect(viewModel.hayCambios, isFalse);
    });

    test('detecta el cambio de cada campo', () {
      final cambios = <void Function(EditPhotoViewModel)>[
        (vm) => vm.cambiarTitulo('Otro'),
        (vm) => vm.cambiarDescripcion('Otra'),
        (vm) => vm.cambiarCategoria(CategoriaFoto.arte),
        (vm) => vm.cambiarPrivacidad(PrivacidadFoto.privada),
        (vm) => vm.cambiarFechaToma(DateTime.utc(2020)),
      ];

      for (final cambio in cambios) {
        final nuevo = EditPhotoViewModel(
          foto: crearFoto(),
          photoService: servicio,
          geocodingService: geocoding,
        );
        cambio(nuevo);
        expect(nuevo.hayCambios, isTrue);
      }
    });

    test('volver al valor original deja de contar como cambio', () {
      viewModel.cambiarTitulo('Otro');
      viewModel.cambiarTitulo('Atardecer');

      expect(viewModel.hayCambios, isFalse);
    });

    test('los espacios sobrantes no cuentan como cambio', () {
      viewModel.cambiarTitulo('  Atardecer ');
      viewModel.cambiarDescripcion('En la playa  ');

      expect(viewModel.hayCambios, isFalse);
    });

    test('avisa a la vista para habilitar el botón', () {
      var avisos = 0;
      viewModel.addListener(() => avisos++);

      viewModel.cambiarTitulo('Otro');

      expect(avisos, 1);
    });
  });

  group('guardar', () {
    test('envía solo los campos cambiados', () async {
      viewModel.cambiarTitulo('  Otro ');
      viewModel.cambiarPrivacidad(PrivacidadFoto.privada);

      expect(await viewModel.guardar(), isTrue);
      expect(servicio.idActualizado, 'abc');
      expect(servicio.camposActualizados, {
        'titulo': 'Otro',
        'privacidad': 'privada',
      });
    });

    test('la fecha se envía como Timestamp', () async {
      final fecha = DateTime.utc(2020, 5, 17);
      viewModel.cambiarFechaToma(fecha);

      expect(await viewModel.guardar(), isTrue);
      expect(servicio.camposActualizados!.keys, ['fechaToma']);
      expect(servicio.camposActualizados!['fechaToma'], isA<Timestamp>());
    });

    test('no llama al servicio si no hay cambios', () async {
      expect(await viewModel.guardar(), isFalse);
      expect(servicio.actualizaciones, 0);
    });

    test('tras guardar ya no hay cambios pendientes', () async {
      viewModel.cambiarTitulo('Otro');
      await viewModel.guardar();

      expect(viewModel.hayCambios, isFalse);
      expect(viewModel.isLoading, isFalse);
    });

    test('falla con título vacío', () async {
      viewModel.cambiarTitulo('   ');

      expect(await viewModel.guardar(), isFalse);
      expect(viewModel.errorMessage, contains('título'));
      expect(servicio.actualizaciones, 0);
    });

    test('un error conserva los cambios para reintentar', () async {
      servicio.errorActualizar = const PhotoException('Sin conexión');
      viewModel.cambiarTitulo('Otro');

      expect(await viewModel.guardar(), isFalse);
      expect(viewModel.errorMessage, 'Sin conexión');
      expect(viewModel.hayCambios, isTrue);
      expect(viewModel.isLoading, isFalse);
    });

    test('ignora un segundo toque mientras guarda', () async {
      servicio.actualizarPendiente = Completer<void>();
      viewModel.cambiarTitulo('Otro');

      final primero = viewModel.guardar();
      expect(viewModel.isLoading, isTrue);
      expect(await viewModel.guardar(), isFalse);

      servicio.actualizarPendiente!.complete();
      expect(await primero, isTrue);
      expect(servicio.actualizaciones, 1);
    });
  });

  group('cambiarUbicacion', () {
    test('guarda coordenadas y el nuevo nombre del lugar', () async {
      await viewModel.cambiarUbicacion(-13.5, -72);

      expect(viewModel.foto.latitud, -13.5);
      expect(viewModel.foto.longitud, -72);
      expect(viewModel.foto.nombreLugar, 'Cusco');
      expect(viewModel.isLoadingUbicacion, isFalse);

      await viewModel.guardar();
      expect(servicio.camposActualizados, {
        'latitud': -13.5,
        'longitud': -72.0,
        'nombreLugar': 'Cusco',
      });
    });

    test('sin geocodificación borra el nombre del lugar anterior', () async {
      geocoding.falla = true;
      await viewModel.cambiarUbicacion(-13.5, -72);

      expect(viewModel.foto.nombreLugar, '');
      expect(viewModel.errorMessage, isNull);

      await viewModel.guardar();
      expect(servicio.camposActualizados!['nombreLugar'], '');
    });

    test('no deja guardar hasta tener el nombre del lugar', () async {
      geocoding.pendiente = Completer<String?>();
      final cambio = viewModel.cambiarUbicacion(-13.5, -72);

      expect(await viewModel.guardar(), isFalse);
      expect(viewModel.errorMessage, contains('Espera'));
      expect(servicio.actualizaciones, 0);

      geocoding.pendiente!.complete('Cusco');
      await cambio;
      expect(await viewModel.guardar(), isTrue);
    });

    test('solo cuenta la respuesta del último toque', () async {
      final primera = Completer<String?>();
      geocoding.pendiente = primera;
      final cambio1 = viewModel.cambiarUbicacion(1, 1);

      final segunda = Completer<String?>();
      geocoding.pendiente = segunda;
      final cambio2 = viewModel.cambiarUbicacion(2, 2);

      segunda.complete('Segundo');
      await cambio2;
      primera.complete('Primero');
      await cambio1;

      expect(viewModel.foto.latitud, 2);
      expect(viewModel.foto.nombreLugar, 'Segundo');
      expect(viewModel.isLoadingUbicacion, isFalse);
    });
  });

  group('eliminar', () {
    test('elimina la foto guardada aunque haya cambios sin guardar', () async {
      viewModel.cambiarTitulo('Otro');

      expect(await viewModel.eliminar(), isTrue);
      expect(servicio.eliminadas.single.titulo, 'Atardecer');
      expect(servicio.eliminadas.single.id, 'abc');
    });

    test('un error se informa', () async {
      servicio.errorEliminar = const PhotoException('Sin permiso');

      expect(await viewModel.eliminar(), isFalse);
      expect(viewModel.errorMessage, 'Sin permiso');
      expect(viewModel.isLoading, isFalse);
    });
  });
}
