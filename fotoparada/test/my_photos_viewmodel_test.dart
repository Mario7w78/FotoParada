import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fotoparada/models/foto_model.dart';
import 'package:fotoparada/services/photo_service.dart';
import 'package:fotoparada/viewmodel/my_photos_viewmodel.dart';

import 'fotos_fakes.dart';

void main() {
  late FakePhotoService servicio;
  late MyPhotosViewModel viewModel;

  Future<void> emitir(List<Foto> fotos) async {
    servicio.misFotos.add(fotos);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    servicio = FakePhotoService();
    viewModel = MyPhotosViewModel(
      photoService: servicio,
      authService: FakeAuth('usuario1'),
    );
  });

  group('carga', () {
    test('está cargando hasta recibir el primer resultado', () async {
      viewModel.iniciar();

      expect(viewModel.isLoading, isTrue);
      expect(viewModel.sinFotos, isFalse);
      expect(servicio.uidConsultado, 'usuario1');

      await emitir([crearFoto()]);

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.fotos, hasLength(1));
    });

    test('sin fotos activa el estado vacío', () async {
      viewModel.iniciar();
      await emitir([]);

      expect(viewModel.sinFotos, isTrue);
      expect(viewModel.errorMessage, isNull);
    });

    test('se actualiza con cada cambio del Stream', () async {
      viewModel.iniciar();
      await emitir([crearFoto(id: 'a'), crearFoto(id: 'b')]);
      await emitir([crearFoto(id: 'b')]);

      expect(viewModel.fotos.map((foto) => foto.id), ['b']);
    });

    test('muestra el mensaje de PhotoException', () async {
      viewModel.iniciar();
      servicio.misFotos.addError(const PhotoException('Sin permiso'));
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, 'Sin permiso');
      expect(viewModel.sinFotos, isFalse);
    });

    test('un error desconocido muestra un mensaje genérico', () async {
      viewModel.iniciar();
      servicio.misFotos.addError(StateError('fallo'));
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.errorMessage, contains('No se pudieron cargar'));
    });

    test('reintentar limpia el error y vuelve a escuchar', () async {
      viewModel.iniciar();
      servicio.misFotos.addError(const PhotoException('Sin permiso'));
      await Future<void>.delayed(Duration.zero);

      viewModel.iniciar();
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.isLoading, isTrue);
      expect(servicio.escuchas, 2);

      await emitir([crearFoto()]);
      expect(viewModel.fotos, hasLength(1));
    });

    test('sin sesión informa el error y no consulta', () {
      viewModel = MyPhotosViewModel(
        photoService: servicio,
        authService: FakeAuth(null),
      );
      viewModel.iniciar();

      expect(viewModel.errorMessage, contains('sesión'));
      expect(viewModel.isLoading, isFalse);
      expect(servicio.escuchas, 0);
    });

    test('al liberar deja de escuchar el Stream', () async {
      viewModel.iniciar();
      expect(servicio.misFotos.hasListener, isTrue);

      viewModel.dispose();
      expect(servicio.misFotos.hasListener, isFalse);
    });
  });

  group('filtro', () {
    setUp(() async {
      viewModel.iniciar();
      await emitir([
        crearFoto(id: 'pub'),
        crearFoto(id: 'ami', privacidad: PrivacidadFoto.amigos),
        crearFoto(id: 'pri', privacidad: PrivacidadFoto.privada),
      ]);
    });

    test('por defecto muestra todas', () {
      expect(viewModel.filtro, isNull);
      expect(viewModel.fotos, hasLength(3));
    });

    test('filtra por privacidad y se puede quitar', () {
      viewModel.cambiarFiltro(PrivacidadFoto.amigos);
      expect(viewModel.fotos.map((foto) => foto.id), ['ami']);

      viewModel.cambiarFiltro(null);
      expect(viewModel.fotos, hasLength(3));
    });

    test('un filtro sin resultados no es el estado vacío', () async {
      await emitir([crearFoto(id: 'pub')]);
      viewModel.cambiarFiltro(PrivacidadFoto.privada);

      expect(viewModel.fotos, isEmpty);
      expect(viewModel.sinFotos, isFalse);
    });
  });

  group('eliminarFoto', () {
    test('llama al servicio con esa foto', () async {
      final foto = crearFoto();

      expect(await viewModel.eliminarFoto(foto), isTrue);
      expect(servicio.eliminadas, [foto]);
      expect(viewModel.estaEliminando(foto), isFalse);
    });

    test('marca la foto y evita eliminarla dos veces', () async {
      final foto = crearFoto();
      servicio.eliminarPendiente = Completer<void>();

      final primero = viewModel.eliminarFoto(foto);
      expect(viewModel.estaEliminando(foto), isTrue);
      expect(await viewModel.eliminarFoto(foto), isFalse);

      servicio.eliminarPendiente!.complete();
      expect(await primero, isTrue);
      expect(servicio.eliminadas, hasLength(1));
    });

    test('un error se informa sin romper la lista', () async {
      viewModel.iniciar();
      final foto = crearFoto();
      await emitir([foto]);
      servicio.errorEliminar = const PhotoException('Sin permiso');

      expect(await viewModel.eliminarFoto(foto), isFalse);
      expect(viewModel.errorEliminar, 'Sin permiso');
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.fotos, hasLength(1));
      expect(viewModel.estaEliminando(foto), isFalse);
    });
  });
}
