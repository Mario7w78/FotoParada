// Los botones con llamadas remotas cambian la pantalla antes de que responda el
// servidor y la devuelven a su estado si la llamada falla.
import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoparada/models/coleccion_model.dart';
import 'package:fotoparada/models/comentario_model.dart';
import 'package:fotoparada/models/reaccion_model.dart';
import 'package:fotoparada/models/reto_model.dart';
import 'package:fotoparada/repositories/foto_repository.dart';
import 'package:fotoparada/services/challenge_service.dart';
import 'package:fotoparada/services/coleccion_service.dart';
import 'package:fotoparada/services/foto_firestore_service.dart';
import 'package:fotoparada/services/interaccion_exception.dart';
import 'package:fotoparada/services/interaction_service.dart';
import 'package:fotoparada/services/recuerdos_exception.dart';
import 'package:fotoparada/viewmodel/challenge_detail_viewmodel.dart';
import 'package:fotoparada/viewmodel/collection_detail_viewmodel.dart';
import 'package:fotoparada/viewmodel/collections_viewmodel.dart';
import 'package:fotoparada/viewmodel/photo_interactions_viewmodel.dart';
import 'package:fotoparada/viewmodel/save_to_collection_viewmodel.dart';

import 'interacciones_fakes.dart';

/// Cada llamada queda en espera hasta que la prueba la resuelve.
class Servidor {
  final List<String> llamadas = [];
  final List<Completer<void>> _pendientes = [];

  Future<void> llamar(String nombre) {
    llamadas.add(nombre);
    final completer = Completer<void>();
    _pendientes.add(completer);
    return completer.future;
  }

  Future<void> responder() async {
    _pendientes.removeAt(0).complete();
    await pausa();
  }

  Future<void> fallar(Object error) async {
    _pendientes.removeAt(0).completeError(error);
    await pausa();
  }
}

Future<void> pausa() => Future<void>.delayed(Duration.zero);

class InteraccionesLentas implements InteractionService {
  InteraccionesLentas(this.servidor);

  final Servidor servidor;
  final comentarios = StreamController<List<Comentario>>.broadcast();
  final reacciones = StreamController<List<Reaccion>>.broadcast();

  @override
  Stream<List<Comentario>> obtenerComentarios(String fotoId) =>
      comentarios.stream;

  @override
  Stream<List<Reaccion>> obtenerReacciones(String fotoId) => reacciones.stream;

  @override
  Future<void> reaccionar({
    required String fotoId,
    required String uid,
    required TipoReaccion tipo,
  }) =>
      servidor.llamar('reaccionar ${tipo.name}');

  @override
  Future<void> eliminarComentario(String fotoId, String comentarioId) =>
      servidor.llamar('eliminar $comentarioId');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Usa Firestore simulado para leer, pero las escrituras esperan al servidor.
class ColeccionesLentas extends ColeccionService {
  ColeccionesLentas(this.servidor, FakeFirebaseFirestore firestore)
      : super(firestore: firestore);

  final Servidor servidor;

  @override
  Future<bool> agregarElemento(
    String coleccionId,
    ElementoColeccion elemento,
  ) async {
    await servidor.llamar('agregar');
    return super.agregarElemento(coleccionId, elemento);
  }

  @override
  Future<void> quitarElemento(String coleccionId, String elementoId) async {
    await servidor.llamar('quitar');
    await super.quitarElemento(coleccionId, elementoId);
  }

  @override
  Future<void> actualizarNota(
    String coleccionId,
    String elementoId,
    String nota,
  ) async {
    await servidor.llamar('nota');
    await super.actualizarNota(coleccionId, elementoId, nota);
  }

  @override
  Future<void> eliminarColeccion(Coleccion coleccion) async {
    await servidor.llamar('eliminar colección');
    await super.eliminarColeccion(coleccion);
  }
}

class RetosLentos implements ChallengeService {
  RetosLentos(this.servidor);

  final Servidor servidor;
  final participantes = StreamController<List<ParticipacionReto>>.broadcast();

  @override
  Stream<List<ParticipacionReto>> obtenerParticipantes(String retoId) =>
      participantes.stream;

  @override
  Future<void> enviarFoto({
    required reto,
    required foto,
    required String uid,
    required String nombreUsuario,
  }) =>
      servidor.llamar('enviar ${foto.id}');

  @override
  Future<void> quitarFoto({
    required String retoId,
    required String uid,
    required String fotoId,
  }) =>
      servidor.llamar('retirar $fotoId');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final auth = FakeAuthConNombre('u1');
  late Servidor servidor;

  setUp(() => servidor = Servidor());

  const errorRed = InteraccionException('Sin conexión');

  group('reacciones', () {
    late InteraccionesLentas servicio;
    late PhotoInteractionsViewModel viewModel;

    setUp(() async {
      servicio = InteraccionesLentas(servidor);
      viewModel = PhotoInteractionsViewModel(
        foto: fotoEn(),
        interactionService: servicio,
        authService: auth,
      )..iniciar();
      servicio.reacciones.add(const []);
      await pausa();
    });

    tearDown(() => viewModel.dispose());

    test('se ve al instante, antes de que responda el servidor', () {
      viewModel.reaccionar(TipoReaccion.meGusta);

      expect(viewModel.miReaccion, TipoReaccion.meGusta);
      expect(viewModel.conteo(TipoReaccion.meGusta), 1);
      expect(viewModel.totalReacciones, 1);
    });

    test('si falla, vuelve a como estaba y avisa', () async {
      final resultado = viewModel.reaccionar(TipoReaccion.meGusta);
      await servidor.fallar(errorRed);

      expect(await resultado, isFalse);
      expect(viewModel.miReaccion, isNull);
      expect(viewModel.totalReacciones, 0);
      expect(viewModel.errorAccion, 'Sin conexión');
    });

    test('toques seguidos se envían en orden y gana el último', () async {
      viewModel.reaccionar(TipoReaccion.meGusta);
      viewModel.reaccionar(TipoReaccion.aplauso);
      viewModel.reaccionar(TipoReaccion.asombro);

      expect(viewModel.miReaccion, TipoReaccion.asombro);
      expect(servidor.llamadas, ['reaccionar meGusta']);

      await servidor.responder();
      expect(viewModel.miReaccion, TipoReaccion.asombro);
      // El intermedio ya no hace falta enviarlo.
      expect(servidor.llamadas.last, 'reaccionar asombro');
      await servidor.responder();
      expect(servidor.llamadas, hasLength(2));
    });

    test('quitar mientras se envía manda la misma reacción otra vez', () async {
      viewModel.reaccionar(TipoReaccion.meGusta);
      viewModel.reaccionar(TipoReaccion.meGusta);

      expect(viewModel.miReaccion, isNull);
      await servidor.responder();
      expect(servidor.llamadas, [
        'reaccionar meGusta',
        'reaccionar meGusta',
      ]);
    });
  });

  group('comentarios', () {
    test('desaparece al instante y vuelve si falla', () async {
      final servicio = InteraccionesLentas(servidor);
      final viewModel = PhotoInteractionsViewModel(
        foto: fotoEn(),
        interactionService: servicio,
        authService: auth,
      )..iniciar();
      final comentario = Comentario(
        id: 'c1',
        uid: 'u1',
        nombreUsuario: 'Ana',
        texto: 'Hola',
        fecha: DateTime(2026),
      );
      servicio.comentarios.add([comentario]);
      await pausa();

      final resultado = viewModel.eliminarComentario(comentario);
      expect(viewModel.comentarios, isEmpty);

      await servidor.fallar(errorRed);
      expect(await resultado, isFalse);
      expect(viewModel.comentarios, [comentario]);
      viewModel.dispose();
    });
  });

  group('colecciones', () {
    late FakeFirebaseFirestore firestore;
    late ColeccionesLentas servicio;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      servicio = ColeccionesLentas(servidor, firestore);
    });

    const errorColeccion = RecuerdosException('Sin conexión');

    test('marcar se ve al instante y se deshace si falla', () async {
      final viewModel = SaveToCollectionViewModel(
        elemento: ElementoColeccion.desdeFoto(fotoEn()),
        coleccionService: servicio,
        authService: auth,
      );
      await viewModel.cargar();
      final coleccion = viewModel.colecciones.first;

      final resultado = viewModel.alternar(coleccion);
      expect(viewModel.estaGuardadoEn(coleccion), isTrue);
      expect(viewModel.colecciones.first.cantidad, 1);

      await servidor.fallar(errorColeccion);
      expect(await resultado, isFalse);
      expect(viewModel.estaGuardadoEn(coleccion), isFalse);
      expect(viewModel.colecciones.first.cantidad, 0);
      expect(viewModel.errorAccion, 'Sin conexión');
      viewModel.dispose();
    });

    test('marcar y desmarcar seguido termina desmarcado', () async {
      final viewModel = SaveToCollectionViewModel(
        elemento: ElementoColeccion.desdeFoto(fotoEn()),
        coleccionService: servicio,
        authService: auth,
      );
      await viewModel.cargar();
      final coleccion = viewModel.colecciones.first;

      viewModel.alternar(coleccion);
      viewModel.alternar(coleccion);
      expect(viewModel.estaGuardadoEn(coleccion), isFalse);

      await servidor.responder();
      await pausa();
      await servidor.responder();
      await pausa();

      expect(servidor.llamadas, ['agregar', 'quitar']);
      expect(viewModel.estaGuardadoEn(coleccion), isFalse);
      expect(viewModel.colecciones.first.cantidad, 0);
      viewModel.dispose();
    });

    Future<CollectionDetailViewModel> abrirDetalle() async {
      await servicio.asegurarPredeterminadas('u1');
      final coleccion =
          (await servicio.obtenerColecciones('u1').first).first;
      await ColeccionService(firestore: firestore).agregarElemento(
        coleccion.id,
        ElementoColeccion.desdeFoto(fotoEn()),
      );
      final viewModel = CollectionDetailViewModel(
        coleccion: coleccion,
        coleccionService: servicio,
        fotoRepository: FotoRepository(
          service: FotoFirestoreService(firestore: firestore),
        ),
        authService: auth,
      )..iniciar();
      await pausa();
      await pausa();
      return viewModel;
    }

    test('quitar un elemento lo oculta al instante y vuelve si falla',
        () async {
      final viewModel = await abrirDetalle();
      final elemento = viewModel.elementos.single;

      final resultado = viewModel.quitar(elemento);
      expect(viewModel.elementos, isEmpty);
      expect(viewModel.coleccion.cantidad, 0);

      await servidor.fallar(errorColeccion);
      expect(await resultado, isFalse);
      expect(viewModel.elementos, hasLength(1));
      expect(viewModel.coleccion.cantidad, 1);
      viewModel.dispose();
    });

    test('la nota nueva se ve al instante y vuelve si falla', () async {
      final viewModel = await abrirDetalle();

      final resultado =
          viewModel.guardarNota(viewModel.elementos.single, ' Ir de noche ');
      expect(viewModel.elementos.single.nota, 'Ir de noche');

      await servidor.fallar(errorColeccion);
      expect(await resultado, isFalse);
      expect(viewModel.elementos.single.nota, isEmpty);
      viewModel.dispose();
    });

    test('eliminar una colección la quita de la lista al instante', () async {
      await servicio.crearColeccion(uid: 'u1', nombre: 'Cafés');
      final viewModel = CollectionsViewModel(
        coleccionService: servicio,
        authService: auth,
      );
      await viewModel.iniciar();
      await pausa();
      final cafes = viewModel.personalizadas.single;

      final resultado = viewModel.eliminarColeccion(cafes);
      expect(viewModel.personalizadas, isEmpty);

      await servidor.fallar(errorColeccion);
      expect(await resultado, isFalse);
      expect(viewModel.personalizadas, hasLength(1));
      viewModel.dispose();
    });
  });

  group('retos', () {
    test('si una de dos fotos falla, solo esa se descuenta', () async {
      final viewModel = ChallengeDetailViewModel(
        reto: Reto(
          id: 'r1',
          creadorUid: 'u2',
          creadorNombre: 'Eva',
          titulo: 'Murales',
          descripcion: '',
          fotosObjetivo: 3,
          fechaInicio: DateTime(2020),
          fechaFin: DateTime(2100),
        ),
        challengeService: RetosLentos(servidor),
        fotoRepository: FotoRepository(
          service: FotoFirestoreService(firestore: FakeFirebaseFirestore()),
        ),
        authService: auth,
      );

      final primera = viewModel.enviarFoto(fotoEn(id: 'a'));
      final segunda = viewModel.enviarFoto(fotoEn(id: 'b'));
      expect(viewModel.misFotosEnviadas, 2);

      await servidor.responder();
      await servidor.fallar(errorRed);

      expect(await primera, isTrue);
      expect(await segunda, isFalse);
      expect(viewModel.miParticipacion!.fotoIds, ['a']);
      viewModel.dispose();
    });

    test('enviar y retirar una foto cambian el progreso al instante', () async {
      final servicio = RetosLentos(servidor);
      final foto = fotoEn();
      final reto = Reto(
        id: 'r1',
        creadorUid: 'u2',
        creadorNombre: 'Eva',
        titulo: 'Murales',
        descripcion: '',
        fotosObjetivo: 2,
        fechaInicio: DateTime(2020),
        fechaFin: DateTime(2100),
      );
      final viewModel = ChallengeDetailViewModel(
        reto: reto,
        challengeService: servicio,
        fotoRepository: FotoRepository(
          service: FotoFirestoreService(firestore: FakeFirebaseFirestore()),
        ),
        authService: auth,
      )..iniciar();
      servicio.participantes.add([]);
      await pausa();

      final envio = viewModel.enviarFoto(foto);
      expect(viewModel.misFotosEnviadas, 1);
      expect(viewModel.fotosEnviadas, [foto]);

      await servidor.fallar(errorRed);
      expect(await envio, isFalse);
      expect(viewModel.misFotosEnviadas, 0);
      expect(viewModel.fotosEnviadas, isEmpty);

      servicio.participantes.add([
        ParticipacionReto(
          uid: 'u1',
          nombreUsuario: 'Franco',
          fotoIds: [foto.id],
          fechaActualizacion: DateTime(2026),
        ),
      ]);
      await pausa();

      final retiro = viewModel.quitarFoto(foto);
      expect(viewModel.misFotosEnviadas, 0);
      await servidor.fallar(errorRed);
      expect(await retiro, isFalse);
      expect(viewModel.misFotosEnviadas, 1);
      viewModel.dispose();
    });
  });
}
