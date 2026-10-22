#!/bin/zsh
# Add a theme to the Coconut catalog.
#
# Usage:
#   scripts/add-theme.sh <id> "<Name>" "<Author>" <file.tendies> <preview.jpg|png>
#
# Example:
#   scripts/add-theme.sh aurora "Aurora" "Leonardo" ~/Downloads/aurora.tendies ~/Downloads/aurora.jpg
#
# Steps:
#   1. Validate the files and calculate the SHA-256 digest of the .tendies package.
#   2. Create a GitHub release tagged <id> and upload both files.
#   3. Add the entry to catalog.json, commit and push.
# The app reads catalog.json and rejects a downloaded .tendies package if its digest does not match.
set -euo pipefail

if [[ $# -ne 5 ]]; then
  sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
fi

id=$1 name=$2 author=$3 package=$4 preview=$5
repo_dir=${0:A:h:h}
cd "$repo_dir"

# The ID is used in URLs: lowercase letters, digits and hyphens only.
[[ $id =~ '^[a-z0-9][a-z0-9-]*$' ]] || { echo "The ID may only contain lowercase letters, digits and hyphens: $id"; exit 1; }
[[ -f $package && $package == *.tendies ]] || { echo "Cannot find the .tendies package: $package"; exit 1; }
[[ -f $preview ]] || { echo "Cannot find the preview: $preview"; exit 1; }
preview_ext=${preview:e:l}
[[ $preview_ext == (jpg|jpeg|png) ]] || { echo "The preview must be .jpg, .jpeg or .png"; exit 1; }
unzip -tq "$package" >/dev/null || { echo "The .tendies package is not a valid ZIP archive."; exit 1; }
grep -q "\"id\": \"$id\"" catalog.json && { echo "A theme with ID $id already exists."; exit 1; }

git pull --quiet --ff-only
sha=$(shasum -a 256 "$package" | cut -d' ' -f1)
owner_repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
base="https://github.com/$owner_repo/releases/download/$id"

# Upload files with fixed names to keep their URLs predictable.
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
cp "$package" "$staging/$id.tendies"
cp "$preview" "$staging/$id-preview.$preview_ext"

echo "Uploading $name to release $id…"
gh release create "$id" "$staging/$id.tendies" "$staging/$id-preview.$preview_ext" \
  --title "$name" --notes "Coconut theme · $author · SHA-256 $sha"

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
git commit --quiet -m "Add theme $name"
git push --quiet
echo "Done: $name is now in the catalog. It will appear in the app in a few minutes."
