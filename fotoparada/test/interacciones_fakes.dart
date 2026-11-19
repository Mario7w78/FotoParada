import 'package:fotoparada/models/foto_model.dart';
import 'package:fotoparada/models/reto_model.dart';
import 'package:fotoparada/services/auth_service.dart';
import 'package:fotoparada/services/foto_metadata_service.dart';
import 'package:latlong2/latlong.dart';

/// Usuario con sesión iniciada y nombre, para comentarios, retos y check-ins.
class FakeAuthConNombre implements AuthService {
  FakeAuthConNombre(this.uid, {this.displayName = 'Franco Luna'});

  @override
  final String? uid;

  @override
  final String displayName;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// GPS simulado: devuelve [posicion] o lanza [error].
class FakeMetadata implements FotoMetadataService {
  FakeMetadata({this.posicion = const LatLng(-12.0464, -77.0428)});

  LatLng posicion;
  Object? error;

  @override
  Future<LatLng> ubicacionActual() async {
    if (error != null) throw error!;
    return posicion;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Plaza de Armas de Lima.
const LatLng plazaDeArmas = LatLng(-12.0464, -77.0428);

Foto fotoEn({
  String id = 'f1',
  String uid = 'u1',
  LatLng punto = plazaDeArmas,
  CategoriaFoto categoria = CategoriaFoto.arte,
  PrivacidadFoto privacidad = PrivacidadFoto.publica,
  DateTime? fechaToma,
}) {
  final ahora = DateTime.now();
  return Foto(
    id: id,
    uid: uid,
    urlImagen: 'https://i.ibb.co/x/$id.jpg',
    urlMiniatura: 'https://i.ibb.co/x/$id-mini.jpg',
    titulo: 'Mural $id',
    descripcion: '',
    categoria: categoria,
    latitud: punto.latitude,
    longitud: punto.longitude,
    nombreLugar: 'Plaza de Armas',
    fechaToma: fechaToma ?? ahora,
    fechaSubida: ahora,
    privacidad: privacidad,
  );
}

Reto retoDePrueba({
  String id = 'r1',
  CategoriaFoto? categoria = CategoriaFoto.arte,
  LatLng? punto = plazaDeArmas,
  int fotosObjetivo = 2,
  DateTime? fechaInicio,
  DateTime? fechaFin,
}) {
  final ahora = DateTime.now();
  return Reto(
    id: id,
    creadorUid: 'creador',
    creadorNombre: 'Mario',
    titulo: 'Murales del centro',
    descripcion: 'Fotografía un mural',
    categoria: categoria,
    latitud: punto?.latitude,
    longitud: punto?.longitude,
    nombreLugar: 'Plaza de Armas',
    radioMetros: 200,
    fotosObjetivo: fotosObjetivo,
    fechaInicio: fechaInicio ?? ahora.subtract(const Duration(days: 1)),
    fechaFin: fechaFin ?? ahora.add(const Duration(days: 6)),
  );
}
