import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/foto_model.dart';
import 'recuerdos_exception.dart';

/// Integrante 4 - Fotos de un lugar para la línea de tiempo y la comparación.
///
/// Solo usa consultas de igualdad (sin orderBy) para no depender de índices
/// compuestos; el orden por fecha de toma se hace en el teléfono.
class RecuerdosService {
  RecuerdosService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Tope por consulta para no descargar lugares enormes de golpe.
  static const int limitePorConsulta = 200;

  CollectionReference<Map<String, dynamic>> get _fotos =>
      _firestore.collection('fotos');

  /// Fotos públicas de [nombreLugar] más las del usuario [uid] (también las
  /// privadas o de amigos: son sus propios recuerdos). Sin duplicados y de la
  /// más antigua a la más reciente.
  Stream<List<Foto>> fotosDelLugar(String nombreLugar, {String? uid}) {
    final publicas = _fotos
        .where('privacidad', isEqualTo: PrivacidadFoto.publica.name)
        .where('nombreLugar', isEqualTo: nombreLugar)
        .limit(limitePorConsulta);

    final fuentes = <Query<Map<String, dynamic>>>[
      publicas,
      if (uid != null)
        _fotos
            .where('uid', isEqualTo: uid)
            .where('nombreLugar', isEqualTo: nombreLugar)
            .limit(limitePorConsulta),
    ];

    return _combinar(fuentes);
  }

  /// Une varias consultas en una sola lista. Emite cuando todas respondieron
  /// al menos una vez y luego con cada cambio de cualquiera.
  Stream<List<Foto>> _combinar(List<Query<Map<String, dynamic>>> consultas) {
    final ultimos = List<List<Foto>?>.filled(consultas.length, null);
    final suscripciones = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    late final StreamController<List<Foto>> controller;

    void emitir() {
      if (ultimos.any((lista) => lista == null)) return;
      final porId = <String, Foto>{};
      for (final lista in ultimos) {
        for (final foto in lista!) {
          porId[foto.id] = foto;
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
