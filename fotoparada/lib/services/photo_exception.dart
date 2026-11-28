/// Error al trabajar con fotos, con un mensaje listo para mostrar.
class PhotoException implements Exception {
  const PhotoException(this.message);

  final String message;

  @override
  String toString() => message;
}
