import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoparada/models/foto_model.dart';
import 'package:fotoparada/services/auth_service.dart';
import 'package:fotoparada/services/foto_metadata_service.dart';
import 'package:fotoparada/services/geocoding_service.dart';
import 'package:fotoparada/services/photo_service.dart';
import 'package:fotoparada/viewmodel/upload_photo_viewmodel.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

class _FakePicker implements ImagePicker {
  XFile? resultado = XFile('foto.jpg');
  Object? error;
  ImageSource? fuente;
  int? calidad;
  double? anchoMaximo;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    fuente = source;
    calidad = imageQuality;
    anchoMaximo = maxWidth;
    if (error != null) throw error!;
    return resultado;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuth implements AuthService {
  _FakeAuth(this.uid);

  @override
  final String? uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGeocoding implements GeocodingService {
  String? nombre = 'Lima, Perú';
  bool falla = false;

  @override
  Future<String?> reverse(double latitude, double longitude) async {
    if (falla) throw Exception('sin API key');
    return nombre;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMetadata implements FotoMetadataService {
  MetadatosExif exif = const MetadatosExif();
  LatLng gps = const LatLng(1, 2);
  Object? errorGps;
  Completer<LatLng>? gpsPendiente;
  int lecturasExif = 0;

  @override
  Future<MetadatosExif> leerExif(String ruta) async {
    lecturasExif++;
    return exif;
  }

  @override
  Future<LatLng> ubicacionActual() async {
    if (errorGps != null) throw errorGps!;
    if (gpsPendiente != null) return gpsPendiente!.future;
    return gps;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePhotoService implements PhotoService {
  int subidas = 0;
  Object? error;
  Completer<void>? pendiente;
  String? uid;
  String? titulo;
  String? descripcion;
  String? nombreLugar;
  double? latitud;
  double? longitud;
  PrivacidadFoto? privacidad;
  CategoriaFoto? categoria;
  DateTime? fechaToma;

  @override
  Future<Foto> subirFoto({
    required File archivo,
    required String uid,
    required String titulo,
    required String descripcion,
    required CategoriaFoto categoria,
    required double latitud,
    required double longitud,
    required String nombreLugar,
    required DateTime fechaToma,
    required PrivacidadFoto privacidad,
  }) async {
    subidas++;
    this.uid = uid;
    this.titulo = titulo;
    this.descripcion = descripcion;
    this.categoria = categoria;
    this.latitud = latitud;
    this.longitud = longitud;
    this.nombreLugar = nombreLugar;
    this.fechaToma = fechaToma;
    this.privacidad = privacidad;
    if (pendiente != null) await pendiente!.future;
    if (error != null) throw error!;
    return Foto.externa(
      id: 'x',
      urlImagen: '',
      titulo: titulo,
      latitud: latitud,
      longitud: longitud,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakePicker picker;
  late _FakeGeocoding geocoding;
  late _FakeMetadata metadata;
  late _FakePhotoService fotos;
  late UploadPhotoViewModel viewModel;

  UploadPhotoViewModel crear({String? uid = 'usuario1'}) {
    return UploadPhotoViewModel(
      imagePicker: picker,
      photoService: fotos,
      authService: _FakeAuth(uid),
      geocodingService: geocoding,
      metadataService: metadata,
    );
  }

  setUp(() {
    picker = _FakePicker();
    geocoding = _FakeGeocoding();
    metadata = _FakeMetadata();
    fotos = _FakePhotoService();
    viewModel = crear();
  });

  group('estado inicial', () {
    test('la privacidad por defecto es pública', () {
      expect(viewModel.privacidad, PrivacidadFoto.publica);
    });
  });

  group('publicar: validaciones', () {
    test('falla sin imagen', () async {
      viewModel.cambiarTitulo('Título');
      await viewModel.cambiarUbicacion(1, 2);

      expect(await viewModel.publicar(), isFalse);
      expect(viewModel.errorMessage, contains('foto'));
      expect(fotos.subidas, 0);
    });

    test('falla con título vacío o solo espacios', () async {
      await viewModel.elegirDeCamara();
      viewModel.cambiarTitulo('   ');

      expect(await viewModel.publicar(), isFalse);
      expect(viewModel.errorMessage, contains('título'));
      expect(fotos.subidas, 0);
    });

    test('falla sin ubicación', () async {
      metadata.errorGps = const UbicacionException('Sin permiso');
      await viewModel.elegirDeCamara();
      viewModel.cambiarTitulo('Título');

      expect(await viewModel.publicar(), isFalse);
      expect(viewModel.errorMessage, contains('ubicación'));
      expect(fotos.subidas, 0);
    });

    test('falla mientras la ubicación se está obteniendo', () async {
      metadata.gpsPendiente = Completer<LatLng>();
      final eleccion = viewModel.elegirDeCamara();
      await Future<void>.delayed(Duration.zero);
      viewModel.cambiarTitulo('Título');

      expect(await viewModel.publicar(), isFalse);
      expect(viewModel.errorMessage, contains('Espera'));
      expect(fotos.subidas, 0);

      metadata.gpsPendiente!.complete(const LatLng(1, 2));
      await eleccion;
    });

    test('falla sin sesión iniciada', () async {
      viewModel = crear(uid: null);
      await viewModel.elegirDeCamara();
      viewModel.cambiarTitulo('Título');

      expect(await viewModel.publicar(), isFalse);
      expect(viewModel.errorMessage, contains('sesión'));
      expect(fotos.subidas, 0);
    });
  });

  group('publicar: envío', () {
    test('envía los datos al servicio con el uid de la sesión', () async {
      await viewModel.elegirDeCamara();
      viewModel.cambiarTitulo('  Atardecer  ');
      viewModel.cambiarDescripcion(' En la playa ');
      viewModel.cambiarCategoria(CategoriaFoto.naturaleza);
      viewModel.cambiarPrivacidad(PrivacidadFoto.amigos);

      expect(await viewModel.publicar(), isTrue);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.isLoading, isFalse);
      expect(fotos.uid, 'usuario1');
      expect(fotos.titulo, 'Atardecer');
      expect(fotos.descripcion, 'En la playa');
      expect(fotos.categoria, CategoriaFoto.naturaleza);
      expect(fotos.privacidad, PrivacidadFoto.amigos);
      expect(fotos.latitud, 1);
      expect(fotos.longitud, 2);
      expect(fotos.nombreLugar, 'Lima, Perú');
    });

    test('muestra el mensaje de PhotoException', () async {
      fotos.error = const PhotoException('Formato no soportado.');
      await viewModel.elegirDeCamara();
      viewModel.cambiarTitulo('Título');

      expect(await viewModel.publicar(), isFalse);
      expect(viewModel.errorMessage, 'Formato no soportado.');
      expect(viewModel.isLoading, isFalse);
    });

    test('ignora un segundo toque mientras está publicando', () async {
      fotos.pendiente = Completer<void>();
      await viewModel.elegirDeCamara();
      viewModel.cambiarTitulo('Título');

      final primero = viewModel.publicar();
      expect(viewModel.isLoading, isTrue);
      expect(await viewModel.publicar(), isFalse);

      fotos.pendiente!.complete();
      expect(await primero, isTrue);
      expect(fotos.subidas, 1);
    });
  });

  group('elegir imagen', () {
    test('usa calidad 80 y ancho máximo 1920', () async {
      await viewModel.elegirDeGaleria();

      expect(picker.fuente, ImageSource.gallery);
      expect(picker.calidad, 80);
      expect(picker.anchoMaximo, 1920);
    });

    test('cancelar el selector no cambia nada', () async {
      picker.resultado = null;
      await viewModel.elegirDeCamara();

      expect(viewModel.imagen, isNull);
      expect(viewModel.latitud, isNull);
      expect(viewModel.errorMessage, isNull);
    });

    test('un error de la cámara se informa', () async {
      picker.error = PlatformException(code: 'no_available_camera');
      await viewModel.elegirDeCamara();

      expect(viewModel.imagen, isNull);
      expect(viewModel.errorMessage, contains('cámara'));
    });
  });

  group('obtenerUbicacion', () {
    test('la cámara usa el GPS actual y no lee el EXIF', () async {
      await viewModel.elegirDeCamara();

      expect(metadata.lecturasExif, 0);
      expect(viewModel.latitud, 1);
      expect(viewModel.origenUbicacion, OrigenUbicacion.gps);
      expect(viewModel.nombreLugar, 'Lima, Perú');
      expect(viewModel.isLoadingUbicacion, isFalse);
    });

    test('la galería prefiere GPS y fecha del EXIF', () async {
      final fecha = DateTime(2020, 5, 17);
      metadata.exif = MetadatosExif(
        ubicacion: const LatLng(10, 20),
        fecha: fecha,
      );
      await viewModel.elegirDeGaleria();

      expect(viewModel.latitud, 10);
      expect(viewModel.longitud, 20);
      expect(viewModel.fechaToma, fecha);
      expect(viewModel.origenUbicacion, OrigenUbicacion.foto);
    });

    test('la galería sin GPS en el EXIF usa el GPS actual', () async {
      await viewModel.elegirDeGaleria();

      expect(viewModel.latitud, 1);
      expect(viewModel.origenUbicacion, OrigenUbicacion.gps);
    });

    test('sin nombre de lugar la ubicación sigue siendo válida', () async {
      geocoding.falla = true;
      await viewModel.elegirDeCamara();
      viewModel.cambiarTitulo('Título');

      expect(viewModel.nombreLugar, '');
      expect(viewModel.errorMessage, isNull);
      expect(await viewModel.publicar(), isTrue);
    });

    test('un error de GPS se informa y deja elegir en el mapa', () async {
      metadata.errorGps = const UbicacionException('Sin permiso');
      await viewModel.elegirDeCamara();

      expect(viewModel.errorMessage, 'Sin permiso');
      expect(viewModel.isLoadingUbicacion, isFalse);

      await viewModel.cambiarUbicacion(5, 6);
      expect(viewModel.latitud, 5);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.origenUbicacion, OrigenUbicacion.manual);
    });

    test('tocar el mapa gana a un GPS que responde después', () async {
      metadata.gpsPendiente = Completer<LatLng>();
      final eleccion = viewModel.elegirDeCamara();
      await Future<void>.delayed(Duration.zero);

      await viewModel.cambiarUbicacion(5, 6);
      metadata.gpsPendiente!.complete(const LatLng(1, 2));
      await eleccion;

      expect(viewModel.latitud, 5);
      expect(viewModel.longitud, 6);
      expect(viewModel.origenUbicacion, OrigenUbicacion.manual);
      expect(viewModel.isLoadingUbicacion, isFalse);
    });
  });

  group('FormatoImagen.detectar', () {
    test('reconoce JPG y PNG por sus primeros bytes', () {
      expect(FormatoImagen.detectar([0xFF, 0xD8, 0xFF, 0xE0]), FormatoImagen.jpg);
      expect(FormatoImagen.detectar([0x89, 0x50, 0x4E, 0x47]), FormatoImagen.png);
    });

    test('rechaza otros formatos y archivos vacíos', () {
      expect(FormatoImagen.detectar([0x52, 0x49, 0x46, 0x46]), isNull);
      expect(FormatoImagen.detectar([]), isNull);
    });

    test('expone la extensión y el contentType reales', () {
      expect(FormatoImagen.png.extension, 'png');
      expect(FormatoImagen.png.contentType, 'image/png');
      expect(FormatoImagen.jpg.extension, 'jpg');
      expect(FormatoImagen.jpg.contentType, 'image/jpeg');
    });
  });
}
