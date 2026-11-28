# FotoParada: configuración

Descripción, pantallas y tecnologías en el [README principal](../README.md).

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

La línea de tiempo, la comparación de fotos y el detalle de ubicación buscan en
`fotos` por nombre de lugar y por cercanía (un recuadro de latitud y longitud), y
ordenan en el teléfono. La búsqueda por cercanía necesita **dos índices
compuestos** en la colección `fotos` (Firestore Database → Índices), ambos con
todos los campos en orden ascendente:

| Campos | Para |
|---|---|
| `privacidad`, `latitud`, `longitud` | Fotos públicas cercanas |
| `uid`, `latitud`, `longitud` | Fotos propias cercanas |

Sin ellos esas pantallas muestran "Falta crear el índice de Firestore"; la
consola de depuración trae el enlace para crearlos.
