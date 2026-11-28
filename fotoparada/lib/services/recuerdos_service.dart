import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/foto_model.dart';
import 'recuerdos_exception.dart';

/// Integrante 4 - Fotos de un lugar para la línea de tiempo y la comparación.
///
/// La búsqueda por cercanía filtra en Firestore por un recuadro de latitud y
/// longitud, y necesita dos índices compuestos (ver README). El radio exacto y
/// el orden por fecha de toma se resuelven en el teléfono.
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

  /// Algo menos que lo que mide un grado de latitud (~111 320 m), para que el
  /// recuadro de búsqueda nunca quede más chico que el radio.
  static const double _metrosPorGrado = 111000;

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
    final centro = latitud != null && longitud != null
        ? LatLng(latitud, longitud)
        : null;

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
      // Firestore no filtra por radio: se pide el recuadro que lo contiene y
      // las esquinas se descartan en el teléfono. El tope se aplica así solo a
      // las fotos de la zona.
      if (centro != null) ...[
        _enRecuadro(
          _fotos.where('privacidad', isEqualTo: PrivacidadFoto.publica.name),
          centro,
        ).limit(limitePorConsulta),
        if (uid != null)
          _enRecuadro(_fotos.where('uid', isEqualTo: uid), centro)
              .limit(limitePorConsulta),
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

  /// Limita [consulta] al cuadrado de lado `2 * radioMetros` alrededor de
  /// [centro].
  static Query<Map<String, dynamic>> _enRecuadro(
    Query<Map<String, dynamic>> consulta,
    LatLng centro,
  ) {
    const margenLatitud = radioMetros / _metrosPorGrado;
    // Un grado de longitud se acorta al alejarse del ecuador.
    final coseno = math.cos(centro.latitude * math.pi / 180).abs();
    final margenLongitud = margenLatitud / math.max(coseno, 0.01);

    return consulta
        .where(
          'latitud',
          isGreaterThanOrEqualTo: centro.latitude - margenLatitud,
        )
        .where('latitud', isLessThanOrEqualTo: centro.latitude + margenLatitud)
        .where(
          'longitud',
          isGreaterThanOrEqualTo: centro.longitude - margenLongitud,
        )
        .where(
          'longitud',
          isLessThanOrEqualTo: centro.longitude + margenLongitud,
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
      // El mensaje original trae el enlace para crear un índice que falte.
      debugPrint('RecuerdosService: $error');
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
