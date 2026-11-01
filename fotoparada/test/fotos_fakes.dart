import 'dart:async';

import 'package:fotoparada/models/foto_model.dart';
import 'package:fotoparada/services/auth_service.dart';
import 'package:fotoparada/services/geocoding_service.dart';
import 'package:fotoparada/services/photo_service.dart';

Foto crearFoto({
  String id = 'abc',
  String titulo = 'Atardecer',
  String descripcion = 'En la playa',
  PrivacidadFoto privacidad = PrivacidadFoto.publica,
  String nombreLugar = 'Lima',
}) {
  return Foto(
    id: id,
    uid: 'usuario1',
    urlImagen: 'https://example.com/$id.jpg',
    rutaStorage: 'fotos/usuario1/$id.jpg',
    titulo: titulo,
    descripcion: descripcion,
    categoria: CategoriaFoto.naturaleza,
    latitud: -12.5,
    longitud: -76.25,
    nombreLugar: nombreLugar,
    fechaToma: DateTime.utc(2026, 1, 2, 10, 30),
    fechaSubida: DateTime.utc(2026, 1, 3),
    privacidad: privacidad,
    likes: 7,
  );
}

class FakePhotoService implements PhotoService {
  final misFotos = StreamController<List<Foto>>.broadcast();
  String? uidConsultado;
  int escuchas = 0;

  String? idActualizado;
  Map<String, dynamic>? camposActualizados;
  int actualizaciones = 0;
  Object? errorActualizar;
  Completer<void>? actualizarPendiente;

  final List<Foto> eliminadas = [];
  Object? errorEliminar;
  Completer<void>? eliminarPendiente;

  @override
  Stream<List<Foto>> obtenerMisFotos(String uid) {
    uidConsultado = uid;
    escuchas++;
    return misFotos.stream;
  }

  @override
  Future<void> actualizarFoto(String id, Map<String, dynamic> campos) async {
    actualizaciones++;
    idActualizado = id;
    camposActualizados = campos;
    if (actualizarPendiente != null) await actualizarPendiente!.future;
    if (errorActualizar != null) throw errorActualizar!;
  }

  @override
  Future<void> eliminarFoto(Foto foto) async {
    eliminadas.add(foto);
    if (eliminarPendiente != null) await eliminarPendiente!.future;
    if (errorEliminar != null) throw errorEliminar!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuth implements AuthService {
  FakeAuth(this.uid);

  @override
  final String? uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeGeocoding implements GeocodingService {
  String? nombre = 'Cusco';
  bool falla = false;
  Completer<String?>? pendiente;

  @override
  Future<String?> reverse(double latitude, double longitude) async {
    if (pendiente != null) return pendiente!.future;
    if (falla) throw Exception('sin API key');
    return nombre;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
