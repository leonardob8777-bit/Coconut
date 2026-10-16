#!/bin/zsh
# Añade un tema al catálogo de Coconut.
#
# Uso:
#   scripts/add-theme.sh <id> "<Nombre>" "<Autor>" <archivo.tendies> <vista-previa.jpg|png>
#
# Ejemplo:
#   scripts/add-theme.sh aurora "Aurora" "Leonardo" ~/Downloads/aurora.tendies ~/Downloads/aurora.jpg
#
# Qué hace, en orden:
#   1. Comprueba los archivos y calcula la huella SHA-256 del .tendies.
#   2. Crea una release en GitHub con la etiqueta <id> y sube los dos archivos.
#   3. Añade la entrada a catalog.json, hace commit y push.
# La app lee catalog.json y, al descargar, rechaza el .tendies si la huella no coincide.
set -euo pipefail

if [[ $# -ne 5 ]]; then
  sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
fi

id=$1 name=$2 author=$3 package=$4 preview=$5
repo_dir=${0:A:h:h}
cd "$repo_dir"

# El id va en direcciones web: solo minúsculas, números y guiones.
[[ $id =~ '^[a-z0-9][a-z0-9-]*$' ]] || { echo "El id solo puede llevar minúsculas, números y guiones: $id"; exit 1; }
[[ -f $package && $package == *.tendies ]] || { echo "No encuentro el .tendies: $package"; exit 1; }
[[ -f $preview ]] || { echo "No encuentro la vista previa: $preview"; exit 1; }
preview_ext=${preview:e:l}
[[ $preview_ext == (jpg|jpeg|png) ]] || { echo "La vista previa debe ser .jpg o .png"; exit 1; }
unzip -tq "$package" >/dev/null || { echo "El .tendies no es un ZIP válido."; exit 1; }
grep -q "\"id\": \"$id\"" catalog.json && { echo "Ya existe un tema con id $id."; exit 1; }

git pull --quiet --ff-only
sha=$(shasum -a 256 "$package" | cut -d' ' -f1)
owner_repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
base="https://github.com/$owner_repo/releases/download/$id"

# Los archivos se suben con nombres fijos para que las direcciones sean predecibles.
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
cp "$package" "$staging/$id.tendies"
cp "$preview" "$staging/$id-preview.$preview_ext"

echo "Subiendo $name a la release $id…"
gh release create "$id" "$staging/$id.tendies" "$staging/$id-preview.$preview_ext" \
  --title "$name" --notes "Tema de Coconut · $author · SHA-256 $sha"

python3 -I - "$id" "$name" "$author" "$base/$id.tendies" "$base/$id-preview.$preview_ext" "$sha" <<'EOF'
import json, sys
id, name, author, package_url, preview_url, sha = sys.argv[1:]
with open("catalog.json") as f:
    catalog = json.load(f)
catalog["themes"].append({"id": id, "name": name, "author": author,
                          "previewURL": preview_url, "packageURL": package_url, "sha256": sha})
with open("catalog.json", "w") as f:
    json.dump(catalog, f, indent=2, ensure_ascii=False)
    f.write("\n")
EOF

git add catalog.json
git commit --quiet -m "Añadir tema $name"
git push --quiet
echo "Listo: $name ya está en el catálogo. La app lo verá en unos minutos."
