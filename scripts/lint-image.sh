#!/usr/bin/env bash
# Lint a single catalog image: hadolint + trivy config.
# Usage: lint-image.sh <image-name>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck source=scripts/lib/env.sh
source "$ROOT/scripts/lib/env.sh"
# shellcheck source=scripts/lib/catalog.sh
source "$ROOT/scripts/lib/catalog.sh"

NAME="${1:-}"
[ -n "$NAME" ] || { echo "usage: $0 <image-name>" >&2; exit 1; }

context="$(catalog_image_field "$NAME" context)"
dockerfile="$(catalog_image_field "$NAME" dockerfile Dockerfile)"
path="${context}/${dockerfile}"

echo "==> hadolint ${path}"
hadolint --ignore DL3008 "$path"

echo "==> trivy config ${path}"
# Prefer per-image .trivyignore (e.g. DS-0002 for intentional root DinD).
ignore_file="${context}/.trivyignore"
if [ -f "$ignore_file" ]; then
  trivy config --exit-code 1 --severity HIGH,CRITICAL --ignorefile "$ignore_file" "$path"
else
  trivy config --exit-code 1 --severity HIGH,CRITICAL "$path"
fi

echo "lint-image: ${NAME} OK"
