import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../models/foto_model.dart';
import '../services/auth_service.dart';
import '../services/foto_metadata_service.dart';
import '../services/geocoding_service.dart';
import '../services/photo_service.dart';

enum OrigenImagen { camara, galeria }

enum OrigenUbicacion { foto, gps, manual }

class UploadPhotoViewModel extends ChangeNotifier {
  UploadPhotoViewModel({
    ImagePicker? imagePicker,
    PhotoService? photoService,
    AuthService? authService,
    GeocodingService? geocodingService,
    FotoMetadataService? metadataService,
  })  : _imagePicker = imagePicker ?? ImagePicker(),
        _photoService = photoService ?? PhotoService(),
        _authService = authService ?? AuthService(),
        _geocodingService = geocodingService ?? GeocodingService(),
        _metadataService = metadataService ?? FotoMetadataService();

  final ImagePicker _imagePicker;
  final PhotoService _photoService;
  final AuthService _authService;
  final GeocodingService _geocodingService;
  final FotoMetadataService _metadataService;

  File? _imagen;
  File? get imagen => _imagen;

  OrigenImagen? _origenImagen;
  OrigenImagen? get origenImagen => _origenImagen;

  String _titulo = '';
  String get titulo => _titulo;

  String _descripcion = '';
  String get descripcion => _descripcion;

  CategoriaFoto _categoria = CategoriaFoto.lugares;
  CategoriaFoto get categoria => _categoria;

  PrivacidadFoto _privacidad = PrivacidadFoto.publica;
  PrivacidadFoto get privacidad => _privacidad;

  double? _latitud;
  double? get latitud => _latitud;

  double? _longitud;
  double? get longitud => _longitud;

  OrigenUbicacion? _origenUbicacion;
  OrigenUbicacion? get origenUbicacion => _origenUbicacion;

  String _nombreLugar = '';
  String get nombreLugar => _nombreLugar;

  DateTime? _fechaToma;
  DateTime? get fechaToma => _fechaToma;

  bool _fechaDeExif = false;

  /// Solo una foto de galería sin fecha en su EXIF necesita que se la indiquen:
  /// en las demás la fecha es conocida.
  bool get fechaEditable =>
      _origenImagen == OrigenImagen.galeria && !_fechaDeExif;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingUbicacion = false;
  bool get isLoadingUbicacion => _isLoadingUbicacion;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Identifica la última petición de ubicación: elegir otra foto o tocar el
  // mapa invalida las respuestas que aún estén en camino.
  int _ultimaSolicitud = 0;

  // La vista puede cerrarse mientras se espera al GPS o a la red.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  // El texto lo muestran los controladores de la vista, no hace falta redibujar.
  void cambiarTitulo(String valor) => _titulo = valor;

  void cambiarDescripcion(String valor) => _descripcion = valor;

  void cambiarCategoria(CategoriaFoto valor) {
    _categoria = valor;
    notifyListeners();
  }

  void cambiarPrivacidad(PrivacidadFoto valor) {
    _privacidad = valor;
    notifyListeners();
  }

  void cambiarFechaToma(DateTime valor) {
    _fechaToma = valor;
    notifyListeners();
  }

  Future<void> elegirDeCamara() =>
      _elegirImagen(ImageSource.camera, OrigenImagen.camara);

  Future<void> elegirDeGaleria() =>
      _elegirImagen(ImageSource.gallery, OrigenImagen.galeria);

  Future<void> _elegirImagen(ImageSource fuente, OrigenImagen origen) async {
    _errorMessage = null;
    notifyListeners();

    final XFile? archivo;
    try {
      archivo = await _imagePicker.pickImage(
        source: fuente,
        imageQuality: 80,
        maxWidth: 1920,
      );
    } on PlatformException {
      _errorMessage = origen == OrigenImagen.camara
          ? 'No se pudo abrir la cámara.'
          : 'No se pudo abrir la galería.';
      notifyListeners();
      return;
    }

    if (archivo == null) return;

    _imagen = File(archivo.path);
    _origenImagen = origen;
    _fechaToma = DateTime.now();
    _fechaDeExif = false;
    _latitud = null;
    _longitud = null;
    _origenUbicacion = null;
    _nombreLugar = '';
    notifyListeners();

    await obtenerUbicacion();
  }

  /// Cámara: GPS actual. Galería: GPS y fecha del EXIF, o GPS actual si la foto
  /// no trae ubicación.
  Future<void> obtenerUbicacion() async {
    final solicitud = ++_ultimaSolicitud;
    _isLoadingUbicacion = true;
    _errorMessage = null;
    notifyListeners();

    try {
      LatLng? punto;
      var origen = OrigenUbicacion.gps;

      if (_origenImagen == OrigenImagen.galeria && _imagen != null) {
        final exif = await _metadataService.leerExif(_imagen!.path);
        if (solicitud != _ultimaSolicitud) return;

        _fechaToma = exif.fecha ?? _fechaToma;
        _fechaDeExif = exif.fecha != null;
        punto = exif.ubicacion;
        if (punto != null) origen = OrigenUbicacion.foto;
      }

      punto ??= await _metadataService.ubicacionActual();
      if (solicitud != _ultimaSolicitud) return;

      await _aplicarUbicacion(punto, origen, solicitud);
    } on UbicacionException catch (e) {
      if (solicitud == _ultimaSolicitud) _errorMessage = e.message;
    } catch (_) {
      if (solicitud == _ultimaSolicitud) {
        _errorMessage =
            'No se pudo obtener tu ubicación. Elige el lugar tocando el mapa.';
      }
    } finally {
      if (solicitud == _ultimaSolicitud) {
        _isLoadingUbicacion = false;
        notifyListeners();
      }
    }
  }

  Future<void> cambiarUbicacion(double latitud, double longitud) async {
    final solicitud = ++_ultimaSolicitud;
    _isLoadingUbicacion = true;
    _errorMessage = null;

    try {
      await _aplicarUbicacion(
        LatLng(latitud, longitud),
        OrigenUbicacion.manual,
        solicitud,
      );
    } finally {
      if (solicitud == _ultimaSolicitud) {
        _isLoadingUbicacion = false;
        notifyListeners();
      }
    }
  }

  Future<void> _aplicarUbicacion(
    LatLng punto,
    OrigenUbicacion origen,
    int solicitud,
  ) async {
    _latitud = punto.latitude;
    _longitud = punto.longitude;
    _origenUbicacion = origen;
    _nombreLugar = '';
    notifyListeners();

    // El nombre es opcional: sin él la foto se publica solo con coordenadas.
    String nombre = '';
    try {
      nombre =
          await _geocodingService.reverse(punto.latitude, punto.longitude) ??
              '';
    } catch (e) {
      debugPrint('No se pudo obtener el nombre del lugar: $e');
    }

    if (solicitud == _ultimaSolicitud) _nombreLugar = nombre;
  }

  /// Devuelve true si la foto se publicó. Si no, deja el motivo en [errorMessage].
  Future<bool> publicar() async {
    if (_isLoading) return false;

    final uid = _authService.uid;
    final errorValidacion = _validar(uid);
    if (errorValidacion != null) {
      _errorMessage = errorValidacion;
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _photoService.subirFoto(
        archivo: _imagen!,
        uid: uid!,
        titulo: _titulo.trim(),
        descripcion: _descripcion.trim(),
        categoria: _categoria,
        latitud: _latitud!,
        longitud: _longitud!,
        nombreLugar: _nombreLugar,
        fechaToma: _fechaToma ?? DateTime.now(),
        privacidad: _privacidad,
      );
      return true;
    } on PhotoException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (_) {
      _errorMessage = 'No se pudo publicar la foto. Intenta de nuevo.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String? _validar(String? uid) {
    if (_imagen == null) return 'Elige una foto con la cámara o la galería.';
    if (_titulo.trim().isEmpty) return 'Escribe un título para la foto.';
    if (_isLoadingUbicacion) return 'Espera a que se obtenga la ubicación.';
    if (_latitud == null || _longitud == null) {
      return 'Elige la ubicación de la foto tocando el mapa.';
    }
    if (uid == null) return 'Debes iniciar sesión para publicar.';
    return null;
  }
}
