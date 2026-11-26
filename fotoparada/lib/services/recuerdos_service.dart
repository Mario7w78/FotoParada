import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../models/foto_model.dart';
import 'recuerdos_exception.dart';

/// Integrante 4 - Fotos de un lugar para la línea de tiempo y la comparación.
///
/// Solo usa consultas de igualdad (sin orderBy) para no depender de índices
/// compuestos; el orden por fecha de toma y el filtro por distancia se hacen
/// en el teléfono.
class RecuerdosService {
  RecuerdosService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Tope por consulta para no descargar lugares enormes de golpe.
  static const int limitePorConsulta = 200;

  CollectionReference<Map<String, dynamic>> get _fotos =>
      _firestore.collection('fotos');

  /// Distancia máxima para considerar que una foto es "del mismo lugar" cuando
  /// se busca por coordenadas.
  static const double radioMetros = 200;

  /// Fotos públicas de [nombreLugar] más las del usuario [uid] (también las
  /// privadas o de amigos: son sus propios recuerdos). Sin duplicados y de la
  /// más antigua a la más reciente.
  ///
  /// Si se dan [latitud] y [longitud] también entran las fotos a menos de
  /// [radioMetros], aunque no tengan nombre de lugar (pasa cuando la foto se
  /// subió sin la clave de geocodificación).
  Stream<List<Foto>> fotosDelLugar(
    String nombreLugar, {
    String? uid,
    double? latitud,
    double? longitud,
  }) {
    final porCercania = latitud != null && longitud != null;
    final centro = porCercania ? LatLng(latitud, longitud) : null;

    final fuentes = <Query<Map<String, dynamic>>>[
      if (nombreLugar.isNotEmpty) ...[
        _fotos
            .where('privacidad', isEqualTo: PrivacidadFoto.publica.name)
            .where('nombreLugar', isEqualTo: nombreLugar)
            .limit(limitePorConsulta),
        if (uid != null)
          _fotos
              .where('uid', isEqualTo: uid)
              .where('nombreLugar', isEqualTo: nombreLugar)
              .limit(limitePorConsulta),
      ],
      // Firestore no filtra por distancia: se traen las públicas (y las
      // propias) y se filtran en el teléfono.
      if (porCercania) ...[
        _fotos
            .where('privacidad', isEqualTo: PrivacidadFoto.publica.name)
            .limit(limitePorConsulta),
        if (uid != null)
          _fotos.where('uid', isEqualTo: uid).limit(limitePorConsulta),
      ],
    ];

    if (fuentes.isEmpty) return Stream.value(const []);

    return _combinar(
      fuentes,
      incluir: (foto) =>
          (nombreLugar.isNotEmpty && foto.nombreLugar == nombreLugar) ||
          (centro != null && estaCerca(foto, centro)),
    );
  }

  static bool estaCerca(Foto foto, LatLng centro) {
    if (foto.latitud == 0 && foto.longitud == 0) return false;
    final distancia = const Distance().as(
      LengthUnit.Meter,
      centro,
      LatLng(foto.latitud, foto.longitud),
    );
    return distancia <= radioMetros;
  }

  /// Une varias consultas en una sola lista. Emite cuando todas respondieron
  /// al menos una vez y luego con cada cambio de cualquiera.
  Stream<List<Foto>> _combinar(
    List<Query<Map<String, dynamic>>> consultas, {
    required bool Function(Foto) incluir,
  }) {
    final ultimos = List<List<Foto>?>.filled(consultas.length, null);
    final suscripciones = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    late final StreamController<List<Foto>> controller;

    void emitir() {
      if (ultimos.any((lista) => lista == null)) return;
      final porId = <String, Foto>{};
      for (final lista in ultimos) {
        for (final foto in lista!) {
          if (incluir(foto)) porId[foto.id] = foto;
        }
      }
      final todas = porId.values.toList()
        ..sort((a, b) => a.fechaToma.compareTo(b.fechaToma));
      controller.add(todas);
    }

    void reportarError(Object error) {
      controller.addError(
        error is FirebaseException
            ? RecuerdosException.desdeFirebase(error)
            : error,
      );
    }

    controller = StreamController<List<Foto>>(
      onListen: () {
        for (var i = 0; i < consultas.length; i++) {
          suscripciones.add(
            consultas[i].snapshots().listen(
              (snapshot) {
                ultimos[i] = snapshot.docs.map(Foto.fromFirestore).toList();
                emitir();
              },
              onError: reportarError,
            ),
          );
        }
      },
      onCancel: () async {
        for (final suscripcion in suscripciones) {
          await suscripcion.cancel();
        }
      },
    );

    return controller.stream;
  }
}
