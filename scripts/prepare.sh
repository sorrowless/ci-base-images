#!/usr/bin/env bash
# Bootstrap local/CI tooling via uv: .venv + pyyaml/packaging, jq, hadolint, trivy.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck source=scripts/lib/env.sh
source "$ROOT/scripts/lib/env.sh"

PYTHON_VERSION="${PYTHON_VERSION:-3.12}"
HADOLINT_VERSION="${HADOLINT_VERSION:-v2.13.1}"
# SHA256 of hadolint-linux-x86_64 from the v2.13.1 release
HADOLINT_SHA256="${HADOLINT_SHA256:-f8b05e4c724cdeb84c0dca07e40936c3d875c0af5d120a27c94026a0f370b2cf}"
TRIVY_VERSION="${TRIVY_VERSION:-0.74.0}"

mkdir -p "$BIN_DIR"

die() { echo "prepare: $*" >&2; exit 1; }

ensure_uv() {
  if command -v "$UV" >/dev/null 2>&1; then
    return
  fi
  echo "prepare: installing uv..."
  curl -fsSL https://astral.sh/uv/install.sh | sh
  export PATH="${HOME}/.local/bin:${PATH}"
  command -v "$UV" >/dev/null 2>&1 || die "uv install failed; ensure ${HOME}/.local/bin is on PATH"
}

ensure_venv() {
  ensure_uv
  if [ ! -x "${VENV}/bin/python" ]; then
    echo "prepare: creating virtualenv in ${VENV} (Python ${PYTHON_VERSION})..."
    if "$UV" python install "${PYTHON_VERSION}" 2>/dev/null; then
      "$UV" venv "${VENV}" --python "${PYTHON_VERSION}"
    else
      "$UV" venv "${VENV}" --python python3
    fi
  fi
  echo "prepare: syncing Python deps into ${VENV}..."
  "$UV" pip install --python "${VENV}/bin/python" -r "${ROOT}/requirements-dev.txt"
}

ensure_jq() {
  if command -v jq >/dev/null 2>&1; then
    return
  fi
  case "$(uname -s)" in
    Darwin)
      if command -v brew >/dev/null 2>&1; then
        brew install jq
      else
        die "jq not found; install via brew"
      fi
      ;;
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -qq
        sudo apt-get install -y jq
      else
        die "jq not found"
      fi
      ;;
    *) die "unsupported OS for jq install" ;;
  esac
}

ensure_hadolint() {
  if command -v hadolint >/dev/null 2>&1; then
    return
  fi
  local dest="${BIN_DIR}/hadolint"
  local asset=""
  case "$(uname -s)-$(uname -m)" in
    Darwin-arm64|Darwin-aarch64) asset="hadolint-macos-arm64" ;;
    Darwin-x86_64) asset="hadolint-macos-x86_64" ;;
    Linux-x86_64|Linux-amd64) asset="hadolint-linux-x86_64" ;;
    Linux-aarch64|Linux-arm64) asset="hadolint-linux-arm64" ;;
    *) die "unsupported platform for hadolint" ;;
  esac
  local url="https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/${asset}"
  echo "prepare: installing hadolint ${HADOLINT_VERSION} (${asset})"
  curl -fsSL -o "$dest" "$url"
  if [ "$asset" = "hadolint-linux-x86_64" ]; then
    echo "${HADOLINT_SHA256}  ${dest}" | sha256sum -c -
  fi
  chmod +x "$dest"
}

ensure_trivy() {
  if command -v trivy >/dev/null 2>&1; then
    return
  fi
  local dest="${BIN_DIR}/trivy"
  local os arch tarball
  os="$(uname -s)"
  arch="$(uname -m)"
  case "$arch" in
    x86_64) arch=64bit ;;
    aarch64|arm64) arch=ARM64 ;;
    *) die "unsupported arch: $arch" ;;
  esac
  case "$os" in
    Linux) tarball="trivy_${TRIVY_VERSION}_Linux-${arch}.tar.gz" ;;
    Darwin) tarball="trivy_${TRIVY_VERSION}_macOS-${arch}.tar.gz" ;;
    *) die "unsupported OS: $os" ;;
  esac
  local url="https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/${tarball}"
  echo "prepare: installing trivy ${TRIVY_VERSION}"
  curl -fsSL "$url" | tar -xz -C "$BIN_DIR" trivy
  chmod +x "$dest"
}

ensure_docker() {
  command -v docker >/dev/null 2>&1 || echo "prepare: warning: docker not found (needed for build/publish)"
}

ensure_venv
ensure_jq
ensure_hadolint
ensure_trivy
ensure_docker

echo "prepare: ready"
echo "  uv=$("$UV" --version 2>&1)"
echo "  python=$(repo_python --version 2>&1) [${VENV}]"
echo "  jq=$(jq --version 2>&1)"
echo "  hadolint=$(hadolint --version 2>&1 || true)"
echo "  trivy=$(trivy --version 2>&1 | head -1 || true)"
