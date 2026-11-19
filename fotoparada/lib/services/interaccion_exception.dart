import 'package:cloud_firestore/cloud_firestore.dart';

/// Error de los servicios de interacción (comentarios, reacciones, check-ins y
/// retos) con un mensaje listo para mostrar.
class InteraccionException implements Exception {
  const InteraccionException(this.message);

  final String message;

  @override
  String toString() => message;

  factory InteraccionException.desdeFirebase(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
      case 'unauthenticated':
        return const InteraccionException(
          'No tienes permiso para realizar esta acción.',
        );
      case 'not-found':
        return const InteraccionException('El elemento ya no existe.');
      case 'unavailable':
        return const InteraccionException(
          'Sin conexión con el servidor. Intenta de nuevo.',
        );
      case 'resource-exhausted':
        return const InteraccionException(
          'Se superó el límite gratuito de Firebase por hoy.',
        );
      case 'failed-precondition':
        return const InteraccionException(
          'Falta crear el índice de Firestore para esta consulta.',
        );
      default:
        return const InteraccionException(
          'Ocurrió un error inesperado. Intenta de nuevo.',
        );
    }
  }
}

/// Convierte los errores de Firestore de un Stream en [InteraccionException].
Stream<T> convertirErrores<T>(Stream<T> stream) {
  return stream.handleError((Object error) {
    if (error is FirebaseException) {
      throw InteraccionException.desdeFirebase(error);
    }
    throw error;
  });
}
