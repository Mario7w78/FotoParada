import 'package:cloud_firestore/cloud_firestore.dart';

/// Error de los servicios de recuerdos y colecciones (Integrante 4) con un
/// mensaje listo para mostrar.
class RecuerdosException implements Exception {
  const RecuerdosException(this.message);

  final String message;

  @override
  String toString() => message;

  factory RecuerdosException.desdeFirebase(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
      case 'unauthenticated':
        return const RecuerdosException(
          'No tienes permiso para realizar esta acción.',
        );
      case 'not-found':
        return const RecuerdosException('El elemento ya no existe.');
      case 'unavailable':
        return const RecuerdosException(
          'Sin conexión con el servidor. Intenta de nuevo.',
        );
      case 'resource-exhausted':
        return const RecuerdosException(
          'Se superó el límite gratuito de Firebase por hoy.',
        );
      case 'failed-precondition':
        return const RecuerdosException(
          'Falta crear el índice de Firestore para esta consulta.',
        );
      default:
        return const RecuerdosException(
          'Ocurrió un error inesperado. Intenta de nuevo.',
        );
    }
  }

  /// Mensaje para mostrar a partir de cualquier error.
  static String mensajeDe(Object error, String porDefecto) {
    if (error is RecuerdosException) return error.message;
    if (error is FirebaseException) {
      return RecuerdosException.desdeFirebase(error).message;
    }
    return porDefecto;
  }
}
