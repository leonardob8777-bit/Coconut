# Coconut Catalog

Catálogo de temas que muestra la pestaña **Descargar** de la app Coconut.

- `catalog.json` es la lista de temas. La app la lee desde
  `https://raw.githubusercontent.com/leonardob8777-bit/Coconut-Catalog/main/catalog.json`.
- Cada tema es una **release** de este repositorio: su etiqueta es el id del tema y
  lleva dos archivos, el `.tendies` y una imagen de vista previa.
- Cada entrada guarda la huella SHA-256 del `.tendies`. Si el archivo publicado cambia,
  la app lo rechaza al descargarlo.

## Añadir un tema

Necesitas el `.tendies` (original o con permiso de su autor) y una imagen vertical
de vista previa (`.jpg` o `.png`, proporción de pantalla de iPhone).

```sh
scripts/add-theme.sh aurora "Aurora" "Leonardo" ~/Downloads/aurora.tendies ~/Downloads/aurora.jpg
```

El script comprueba los archivos, crea la release, añade la entrada a `catalog.json`
y hace push. GitHub tarda unos minutos en servir la versión nueva del catálogo.

## Quitar un tema

1. Borra su entrada de `catalog.json`, haz commit y push.
2. Borra la release: `gh release delete <id> --cleanup-tag`.

## Formato de una entrada

```json
{
  "id": "aurora",
  "name": "Aurora",
  "author": "Leonardo",
  "previewURL": "https://github.com/leonardob8777-bit/Coconut-Catalog/releases/download/aurora/aurora-preview.jpg",
  "packageURL": "https://github.com/leonardob8777-bit/Coconut-Catalog/releases/download/aurora/aurora.tendies",
  "sha256": "…"
}
```
