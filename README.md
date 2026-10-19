# Coconut Catalog

Colección descargable de Coconut. La app incluye un catálogo inicial y miniaturas ligeras; descarga los paquetes al guardar o usar un tema y reproduce los vídeos de referencia bajo demanda.

- `catalog.json`: identificador, nombre, vistas previas y URL HTTPS del paquete.
- `sha256`: integridad del archivo `.tendies`, comprobada al descargar.
- La release `collection-2026-10-19` reúne 167 paquetes y sus recursos.
- Los paquetes se publican sin modificar los archivos validados. Las vistas previas no certifican el resultado de PosterBoard en un iPhone.

Los vídeos de referencia provienen del autor y pueden incluir el reloj y los controles del simulador. Las miniaturas se renderizan sin esos elementos.

El script `scripts/add-theme.sh` permite añadir temas individuales con su propia release. Para actualizar una revisión existente, publica el nuevo archivo y su SHA-256 juntos en el catálogo.
