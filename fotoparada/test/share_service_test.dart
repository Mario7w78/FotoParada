import 'package:flutter_test/flutter_test.dart';
import 'package:fotoparada/services/share_service.dart';
import 'package:fotoparada/viewmodel/share_location_viewmodel.dart';

import 'interacciones_fakes.dart';

void main() {
  final servicio = ShareService();

  test('enlace de Google Maps con las coordenadas', () {
    expect(
      servicio.enlaceUbicacion(-12.0464, -77.0428),
      'https://www.google.com/maps/search/?api=1&query=-12.046400,-77.042800',
    );
  });

  test('enlace de OpenStreetMap con marcador y zoom', () {
    expect(
      servicio.enlaceUbicacion(
        -12.0464,
        -77.0428,
        proveedor: ProveedorMapa.openStreetMap,
      ),
      'https://www.openstreetmap.org/?mlat=-12.046400&mlon=-77.042800'
      '#map=17/-12.046400/-77.042800',
    );
  });

  test('el texto de una foto incluye el título y el enlace a la imagen', () {
    final foto = fotoEn(id: 'x');
    final texto = servicio.textoParaCompartir(
      nombreLugar: 'Plaza de Armas',
      latitud: foto.latitud,
      longitud: foto.longitud,
      foto: foto,
    );

    expect(texto, contains('"Mural x" en Plaza de Armas'));
    expect(texto, contains(foto.urlImagen));
    expect(texto, contains('google.com/maps'));
  });

  test('sin foto (o sin incluirla) comparte solo el lugar', () {
    final foto = fotoEn();
    final texto = servicio.textoParaCompartir(
      nombreLugar: '',
      latitud: 1,
      longitud: 2,
      foto: foto,
      incluirFoto: false,
    );

    expect(texto, contains('Te comparto este lugar'));
    expect(texto, isNot(contains(foto.urlImagen)));
  });

  test('el viewmodel actualiza el texto al cambiar de proveedor', () {
    final viewModel = ShareLocationViewModel(
      args: ShareLocationArgs.desdeFoto(fotoEn()),
    );
    expect(viewModel.texto, contains('google.com'));

    viewModel.cambiarProveedor(ProveedorMapa.openStreetMap);
    expect(viewModel.texto, contains('openstreetmap.org'));
    expect(viewModel.enlace, contains('openstreetmap.org'));
  });
}
