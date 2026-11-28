/// Valores que la pantalla ya muestra mientras el servidor los recibe en
/// segundo plano ("actualización optimista").
///
/// Por cada clave hay como mucho un envío a la vez: si el usuario vuelve a
/// tocar mientras tanto, al terminar se envía solo lo último que pidió.
class CambiosOptimistas<K, V> {
  final Map<K, V> _deseados = {};
  final Set<K> _enviando = {};

  /// Lo que debe mostrarse: el cambio pedido o, si no hay, [confirmado].
  V valor(K clave, V confirmado) =>
      _deseados.containsKey(clave) ? _deseados[clave] as V : confirmado;

  bool pendiente(K clave) => _deseados.containsKey(clave);

  bool enviando(K clave) => _enviando.contains(clave);

  /// Deja de superponer el cambio, cuando los datos reales ya lo incluyen.
  void descartar(K clave) => _deseados.remove(clave);

  /// Registra [nuevo] de inmediato (antes del primer `await`) y lo envía.
  ///
  /// Si ya había un envío en curso para [clave], termina enseguida: ese envío
  /// se encarga. Si [enviar] falla, se descarta el cambio y se relanza el
  /// error.
  Future<void> aplicar({
    required K clave,
    required V nuevo,
    required V confirmado,
    required Future<void> Function(V desde, V hacia) enviar,
    void Function(V valor)? alConfirmar,
  }) async {
    _deseados[clave] = nuevo;
    if (!_enviando.add(clave)) return;

    var actual = confirmado;
    try {
      while (_deseados[clave] != actual) {
        final destino = _deseados[clave] as V;
        await enviar(actual, destino);
        actual = destino;
        alConfirmar?.call(actual);
      }
    } catch (_) {
      _deseados.remove(clave);
      rethrow;
    } finally {
      _enviando.remove(clave);
    }
  }
}
