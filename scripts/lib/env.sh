#!/usr/bin/env bash
# Shared env: repo root, uv-managed .venv, and PATH for tooling.
# Source from other scripts; do not execute directly.

set -euo pipefail

# When sourced from scripts/*.sh, BASH_SOURCE[0] is this file.
_ENV_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${ROOT:-$(cd "${_ENV_LIB_DIR}/../.." && pwd)}"
VENV="${VENV:-${ROOT}/.venv}"
BIN_DIR="${BIN_DIR:-${ROOT}/.bin}"
PYTHON="${PYTHON:-${VENV}/bin/python}"
UV="${UV:-uv}"

export ROOT VENV BIN_DIR PYTHON UV
export PATH="${BIN_DIR}:${VENV}/bin:${HOME}/.local/bin:${PATH}"

repo_python() {
  if [ -x "${VENV}/bin/python" ]; then
    "${VENV}/bin/python" "$@"
  else
    echo "repo_python: ${VENV} missing; run 'make prepare' first" >&2
    return 1
  fi
}
