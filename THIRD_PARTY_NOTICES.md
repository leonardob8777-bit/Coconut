# Procedencia y atribuciones

## Pocket Poster — GPL-3.0

Autor acreditado en el código original: **lemin**; proyecto de **leminlimez**.

- Repositorio: https://github.com/leminlimez/Pocket-Poster
- Revisión auditada: `fb07aa45586ea4d2590c6f6d258777b207e1b8c9`.
- Licencia original: https://github.com/leminlimez/Pocket-Poster/blob/fb07aa45586ea4d2590c6f6d258777b207e1b8c9/LICENSE
- Archivo derivado: `Sources/WallpaperInstaller/ExperimentalPosterBoardWriter.swift`.
- Adaptador de rutas y papelera: `Sources/WallpaperInstaller/PocketPosterTransport.swift`, derivado de `SymHandler.swift`, incluido soporte `LC_HOME_PATH`.
- Corrección del 20-10-2026: destino `.Trash` de LiveContainer igual al upstream, recuperación exclusiva de enlaces al mismo destino, exclusión de restablecimiento automático de Colecciones y apertura tras 350 ms. Créditos visibles también en Acerca de.
- Apertura opcional de PosterBoard: `App/PosterBoardLauncher.swift`, derivada del método de apertura de `PosterBoardManager.swift:50–58`, con atribución en su encabezado. No realiza resets y solo se invoca por acción del usuario después del intento.
- Origen de la adaptación: `SymHandler.swift` (enlace `.Trash`) y `PosterBoardManager.swift` (identificadores y movimiento por `trashItem`). Las líneas exactas se indican en el encabezado del archivo derivado.
- Cambios del 16-10-2026: módulo Foundation sin UI; copias de trabajo; validación de UUID y proveedor; límite al dispositivo y versión objetivo; bloqueo de `.Trash` preexistente; registro previo; consentimiento y referencia de respaldo; resultado descrito como intento sin verificación de PosterBoard; exclusión de reset, CarPlay y limpiezas generales.
- El proyecto de referencia acredita a **Nathan / verygenericname** y **DuyKhanhTran / khanhduytran0** por el mecanismo de acceso, y a **PosterRestore** por su ayuda con PosterBoard. Se conservan esas atribuciones relevantes. No se copia código del gist de Duy Tran.

La licencia GPL-3.0 completa está en `LICENSE` y en la pantalla de licencias de la PoC. Este software se suministra sin garantía conforme a esa licencia. No es una versión oficial de Pocket Poster ni está respaldado por sus autores.

## ZIPFoundation — MIT

- Autor: **Thomas Zoechling**, copyright 2017–2024.
- Versión: **0.9.19**.
- Revisión: `02b6abe5f6eef7e3cbd5f247c5cc24e246efcfe0`.
- Origen: https://github.com/weichsel/ZIPFoundation
- Fuentes: `Vendor/ZIPFoundation/Sources`; manifiesto y licencia originales incluidos.
- Texto íntegro: `Vendor/ZIPFoundation/LICENSE`, también incluido en la app.
- No se modificaron las fuentes ni el manifiesto de ZIPFoundation. Se incluye únicamente el subconjunto de fuentes, manifiesto y licencia necesario para compilar; no sus tests originales.

## Referencias estudiadas, no incorporadas

Nugget `26e0c50ec114ca3a4ff6ab2fb4ae309abfd39fa1` usa AGPL-3.0. Se estudió su obtención y envío del UUID, pero no se copió ni enlazó su código. Sus fuentes de referencia están fuera de este repositorio independiente.

Dynamic, CachedAsyncImage, GIFImage y recursos VideoCAML de Pocket Poster no están incluidos en Coconut Lab. Las copias de licencias y cabeceras en `evidence/` son documentación de auditoría, no dependencias de ejecución.

## Acceso experimental — Eagle/Lara y DarkSword

`Labs/OnDeviceAccess` incluye una extracción del motor de Eagle/Lara bajo AGPL-3.0 y las bibliotecas XPF, libgrabkernel2 y cabeceras ChOma con sus avisos MIT. La ruta inicial de Coconut 0.5.1 estuvo limitada a iPhone17,1 / iOS 18.6.2 / 22G100; Coconut 0.6.24 retira ese límite fijo y conserva las comprobaciones de compatibilidad del motor. `App/PosterBoardRefresh.swift` adapta la solicitud de recarga de `AnimatedWallpapersView.swift` de Eagle bajo AGPL-3.0; la verificación de archivos de destino se reimplementó en `DescriptorFingerprint.swift`. Procedencia, modificaciones, hashes y condiciones se documentan en `Labs/OnDeviceAccess/README.md` y `Labs/OnDeviceAccess/Vendor/EagleAccess/provenance.json`. La app incluye el texto AGPL completo y los avisos de las bibliotecas. La compatibilidad nueva todavía requiere pruebas físicas por modelo y build.

## Fondos de prueba incluidos en 0.2.0

Los 27 paquetes y sus vídeos se incorporaron desde la carpeta `preview/` del usuario para la prueba privada solicitada. No se atribuye la titularidad de las imágenes de origen ni se presume una licencia libre para esos activos. La procedencia y los permisos deben comprobarse antes de una publicación pública. Las miniaturas son fotogramas de los vídeos suministrados, sin cambiar el diseño de los fondos.
