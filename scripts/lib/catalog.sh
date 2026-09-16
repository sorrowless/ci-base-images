#!/usr/bin/env bash
# Catalog helpers for images.yaml (source, do not execute directly).

set -euo pipefail

_CATALOG_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/env.sh
source "${_CATALOG_LIB_DIR}/env.sh"

CATALOG="${CATALOG:-${ROOT}/images.yaml}"

# Dump one image entry as JSON object to stdout.
# Usage: catalog_image_json <name>
catalog_image_json() {
  local name="$1"
  repo_python - "$CATALOG" "$name" <<'PY'
import json, sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
want = sys.argv[2]
for img in data.get("images", []):
    if img["name"] == want:
        print(json.dumps(img))
        sys.exit(0)
sys.exit(f"image not found in catalog: {want}")
PY
}

# Print namespace from catalog.
catalog_namespace() {
  repo_python - "$CATALOG" <<'PY'
import sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
print(data.get("namespace", "lyricistmarbling"))
PY
}

# Print all image names, one per line.
catalog_image_names() {
  repo_python - "$CATALOG" <<'PY'
import sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
for img in data.get("images", []):
    print(img["name"])
PY
}

# Print field from image JSON.
# Usage: catalog_image_field <name> <field> [default]
catalog_image_field() {
  local name="$1" field="$2" default="${3:-}"
  repo_python - "$CATALOG" "$name" "$field" "$default" <<'PY'
import json, sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
want, field, default = sys.argv[2], sys.argv[3], sys.argv[4]
for img in data.get("images", []):
    if img["name"] == want:
        val = img.get(field, default)
        if val is None:
            print(default)
        elif isinstance(val, (list, dict)):
            print(json.dumps(val))
        else:
            print(val)
        sys.exit(0)
sys.exit(f"image not found: {want}")
PY
}

# Emit GitHub Actions matrix JSON for a list of image names.
# Usage: catalog_matrix_json name1 name2 ...
catalog_matrix_json() {
  local names=("$@")
  repo_python - "$CATALOG" "${names[@]}" <<'PY'
import json, sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
by_name = {img["name"]: img for img in data.get("images", [])}
ns = data.get("namespace", "lyricistmarbling")
wanted = sys.argv[2:]
include = []
for name in wanted:
    img = by_name.get(name)
    if not img:
        raise SystemExit(f"unknown image: {name}")
    entry = {
        "name": name,
        "context": img["context"],
        "dockerfile": img.get("dockerfile", "Dockerfile"),
        "version_file": img["version_file"],
        "full_name": f"{ns}/{name}",
        "target": img.get("target") or "",
        "build_args": " ".join(f"{k}={v}" for k, v in (img.get("build_args") or {}).items()),
        "extra_tags": ",".join(str(t) for t in (img.get("extra_tags") or [])),
    }
    include.append(entry)
print(json.dumps({"include": include}))
PY
}
