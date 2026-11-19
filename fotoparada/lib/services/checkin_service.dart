import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../models/checkin_model.dart';
import 'foto_metadata_service.dart';
import 'interaccion_exception.dart';

/// Check-ins fotográficos: valida con el GPS que el usuario esté en el lugar y
/// guarda el registro en la colección `checkins`.
class CheckInService {
  CheckInService({
    FirebaseFirestore? firestore,
    FotoMetadataService? metadataService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _metadataService = metadataService ?? FotoMetadataService();

  final FirebaseFirestore _firestore;
  final FotoMetadataService _metadataService;

  /// Distancia máxima al lugar para validar la presencia. Deja margen para el
  /// error típico del GPS de un teléfono en la ciudad.
  static const double radioValidacionMetros = 150;

  CollectionReference<Map<String, dynamic>> get _checkins =>
      _firestore.collection('checkins');

  /// Lanza [UbicacionException] si no hay GPS o permiso.
  Future<LatLng> ubicacionActual() => _metadataService.ubicacionActual();

  double distanciaMetros(LatLng desde, LatLng hasta) {
    return const Distance().as(LengthUnit.Meter, desde, hasta);
  }

  bool estaDentroDelRadio(double distanciaMetros) =>
      distanciaMetros <= radioValidacionMetros;

  Future<CheckIn> registrar({
    required String uid,
    required LugarCheckIn lugar,
    required double distanciaMetros,
  }) async {
    if (!estaDentroDelRadio(distanciaMetros)) {
      throw const InteraccionException(
        'Debes estar en el lugar para hacer check-in.',
      );
    }

    final documento = _checkins.doc();
    final checkIn = CheckIn(
      id: documento.id,
      uid: uid,
      nombreLugar: lugar.nombre,
      latitud: lugar.latitud,
      longitud: lugar.longitud,
      distanciaMetros: distanciaMetros,
      fecha: DateTime.now(),
    );

    try {
      await documento.set({
        ...checkIn.toMap(),
        'fecha': FieldValue.serverTimestamp(),
      });
      return checkIn;
    } on FirebaseException catch (e) {
      throw InteraccionException.desdeFirebase(e);
    }
  }

  /// Se ordena en el teléfono para no necesitar un índice compuesto
  /// (uid + fecha) en Firestore.
  Stream<List<CheckIn>> obtenerMisCheckIns(String uid) {
    return convertirErrores(
      _checkins.where('uid', isEqualTo: uid).snapshots().map((snapshot) {
        final lista = snapshot.docs.map(CheckIn.fromFirestore).toList();
        lista.sort((a, b) => b.fecha.compareTo(a.fecha));
        return lista;
      }),
    );
  }
}
