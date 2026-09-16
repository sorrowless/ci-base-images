#!/usr/bin/env bash
# Version helpers for release-bump.sh (source, do not execute directly).

set -euo pipefail

_VS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/env.sh
source "${_VS_LIB_DIR}/env.sh"

GIT_REMOTE="${GIT_REMOTE:-origin}"

normalize_version() {
  local v="${1#v}"
  echo "$v"
}

file_version() {
  local path="$1"
  if [ ! -f "$path" ]; then
    echo "0.0.0"
    return
  fi
  tr -d '[:space:]' < "$path"
}

# Latest git tag for an image: {image}-vX.Y.Z → X.Y.Z
git_latest_tag_version() {
  local image="$1"
  local tag
  tag="$(git for-each-ref --sort=-v:refname --format='%(refname:short)' "refs/tags/${image}-v*" 2>/dev/null | head -1 || true)"
  if [ -z "$tag" ]; then
    echo "0.0.0"
    return
  fi
  normalize_version "${tag#${image}-v}"
}

# Latest semver tag on Docker Hub for namespace/image
hub_latest_version() {
  local namespace="$1" image="$2"
  local url="https://hub.docker.com/v2/repositories/${namespace}/${image}/tags?page_size=100&ordering=last_updated"
  local version
  if ! version="$(curl -fsSL --max-time 30 "$url" 2>/dev/null | repo_python -c "
import json, re, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print('0.0.0')
    sys.exit(0)
tags = [t.get('name', '') for t in data.get('results', [])]
semver = [t for t in tags if re.fullmatch(r'\d+\.\d+\.\d+', t)]
if not semver:
    print('0.0.0')
else:
    from packaging.version import Version
    print(str(sorted(semver, key=Version)[-1]))
" 2>/dev/null)"; then
    echo "0.0.0"
    return
  fi
  echo "$version"
}

semver_max() {
  printf '%s\n' "$@" | sort -V | tail -1
}

semver_patch_bump() {
  repo_python -c "
from packaging.version import Version
v = Version('$1')
parts = v.release
if len(parts) >= 3:
    print(f'{parts[0]}.{parts[1]}.{parts[2] + 1}')
elif len(parts) == 2:
    print(f'{parts[0]}.{parts[1]}.1')
else:
    print(f'{parts[0]}.0.1')
"
}

tag_for_image_version() {
  local image="$1" ver="$2"
  echo "${image}-v$(normalize_version "$ver")"
}

remote_tag_exists() {
  local tag="$1"
  git ls-remote --exit-code "$GIT_REMOTE" "refs/tags/${tag}" >/dev/null 2>&1
}

remote_tag_commit() {
  local tag="$1"
  git ls-remote "$GIT_REMOTE" "refs/tags/${tag}" | awk '{print $1}' | head -1
}

fetch_remote_tags() {
  git fetch "$GIT_REMOTE" --tags --force 2>/dev/null || git fetch "$GIT_REMOTE" --tags 2>/dev/null || true
}
