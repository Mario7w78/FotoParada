import 'package:flutter_test/flutter_test.dart';
import 'package:fotoparada/models/coleccion_model.dart';
import 'package:fotoparada/models/linea_tiempo.dart';

import 'interacciones_fakes.dart';

void main() {
  group('agruparPorAnio', () {
    final fotos = [
      fotoEn(id: 'b', fechaToma: DateTime(2024, 3, 1)),
      fotoEn(id: 'a', fechaToma: DateTime(2019, 7, 10)),
      fotoEn(id: 'c', fechaToma: DateTime(2024, 1, 5)),
      fotoEn(id: 'd', fechaToma: DateTime(2026, 11, 20)),
    ];

    test('agrupa por año de la más antigua a la más reciente', () {
      final grupos = agruparPorAnio(fotos);
      expect(grupos.map((g) => g.anio), [2019, 2024, 2026]);
      expect(grupos[1].fotos.map((f) => f.id), ['c', 'b']);
    });

    test('en orden descendente empieza por la más reciente', () {
      final grupos = agruparPorAnio(fotos, ascendente: false);
      expect(grupos.map((g) => g.anio), [2026, 2024, 2019]);
      expect(grupos[1].fotos.map((f) => f.id), ['b', 'c']);
    });

    test('sin fotos no hay grupos', () {
      expect(agruparPorAnio([]), isEmpty);
    });
  });

  group('describirDiferencia', () {
    test('años y meses', () {
      expect(
        describirDiferencia(DateTime(2021, 1, 15), DateTime(2023, 4, 20)),
        '2 años y 3 meses',
      );
    });

    test('el orden de las fechas no importa', () {
      expect(
        describirDiferencia(DateTime(2024, 6, 1), DateTime(2023, 6, 1)),
        '1 año',
      );
    });

    test('solo meses', () {
      expect(
        describirDiferencia(DateTime(2025, 1, 10), DateTime(2025, 6, 10)),
        '5 meses',
      );
    });

    test('menos de un mes se cuenta en días', () {
      expect(
        describirDiferencia(DateTime(2025, 1, 31), DateTime(2025, 2, 1)),
        '1 día',
      );
      expect(
        describirDiferencia(DateTime(2025, 3, 1), DateTime(2025, 3, 13)),
        '12 días',
      );
    });

    test('mismo día aunque cambie la hora', () {
      expect(
        describirDiferencia(
          DateTime(2025, 3, 1, 8),
          DateTime(2025, 3, 1, 20),
        ),
        'el mismo día',
      );
    });
  });

  test('resumen y par inicial usan la foto más antigua y la más reciente', () {
    final fotos = [
      fotoEn(id: 'nueva', fechaToma: DateTime(2026, 2, 1)),
      fotoEn(id: 'vieja', fechaToma: DateTime(2018, 2, 1)),
      fotoEn(id: 'media', fechaToma: DateTime(2022, 2, 1)),
    ];
    final resumen = ResumenLineaTiempo.desde(fotos)!;
    expect(resumen.cantidad, 3);
    expect(resumen.periodo, '8 años');

    final par = parInicialParaComparar(fotos)!;
    expect(par.antigua.id, 'vieja');
    expect(par.reciente.id, 'nueva');

    expect(parInicialParaComparar([fotos.first]), isNull);
    expect(ResumenLineaTiempo.desde([]), isNull);
  });

  group('ElementoColeccion', () {
    test('el id de un lugar no depende de mayúsculas ni espacios', () {
      expect(
        ElementoColeccion.idParaLugar('  Plaza de Armas '),
        ElementoColeccion.idParaLugar('plaza de armas'),
      );
      expect(
        ElementoColeccion.idParaLugar('Parque Kennedy / Miraflores'),
        'lugar_parque_kennedy_miraflores',
      );
    });

    test('desde una foto copia los datos para mostrarla', () {
      final elemento = ElementoColeccion.desdeFoto(fotoEn(id: 'f9'));
      expect(elemento.id, 'foto_f9');
      expect(elemento.fotoId, 'f9');
      expect(elemento.esFoto, isTrue);
      expect(elemento.urlImagen, contains('f9-mini'));
      expect(elemento.lugar.nombre, 'Plaza de Armas');
    });
  });
}
