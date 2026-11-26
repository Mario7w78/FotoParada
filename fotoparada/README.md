# fotoparada

A new Flutter project.

## Cómo configurar las claves

Las claves de las APIs no se suben al repo: se leen de `claves.json`.

1. Copia `claves.example.json` como `claves.json` (en esta misma carpeta).
2. Reemplaza `pon_aqui_tu_clave` por tus claves de
   [geocode.maps.co](https://geocode.maps.co) (`GEOCODE_API_KEY`) y de
   [ImgBB](https://api.imgbb.com) (`IMGBB_API_KEY`).
3. Ejecuta la app con:

   ```sh
   flutter run --dart-define-from-file=claves.json
   ```

   En Android Studio: **Run → Edit Configurations → Additional run args** y
   agrega `--dart-define-from-file=claves.json`.

Si falta una clave, la app lo avisa con un mensaje que menciona `claves.json`.

## Reglas de Firestore

Las reglas están en `firestore.rules`. Para aplicarlas, cópialas completas en
la consola de Firebase (**Firestore Database → Reglas → Publicar**). Si agregas
una colección nueva, agrega sus reglas ahí sin borrar las demás.

Colecciones que usa la app:

| Colección | Uso |
| --- | --- |
| `fotos` | Fotos (imagen en ImgBB, solo el link en Firestore). |
| `fotos/{id}/comentarios` | Comentarios de una foto. |
| `fotos/{id}/reacciones/{uid}` | Una reacción por usuario; actualiza `likes` de la foto. |
| `checkins` | Check-ins validados con GPS (radio de 150 m). |
| `retos`, `retos/{id}/participantes/{uid}` | Retos fotográficos y avance de cada usuario. |
| `colecciones` | Colecciones del usuario: "Quiero visitar", "Mis viajes" (id `{uid}_quiero_visitar` / `{uid}_mis_viajes`) y personalizadas. Guarda `cantidad` y `portadaUrl`. |
| `colecciones/{id}/elementos/{elementoId}` | Fotos (`foto_{fotoId}`) o lugares (`lugar_{nombre}`) guardados, con nota personal. |

La línea de tiempo y la comparación de fotos (Integrante 4) leen `fotos` solo
con filtros de igualdad (`privacidad` + `nombreLugar`, `uid` + `nombreLugar`) y
ordenan en el teléfono, así que **no necesitan índices compuestos**.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
