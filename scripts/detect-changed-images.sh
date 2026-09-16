#!/usr/bin/env bash
# Detect which catalog images changed between two git refs.
# Usage:
#   detect-changed-images.sh [--base REF] [--head REF] [--force NAME|all] [--format names|matrix|json]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck source=scripts/lib/env.sh
source "$ROOT/scripts/lib/env.sh"

BASE_REF="${DETECT_BASE:-origin/master}"
HEAD_REF="${DETECT_HEAD:-HEAD}"
FORCE=""
FORMAT="names"

while [ $# -gt 0 ]; do
  case "$1" in
    --base) BASE_REF="$2"; shift 2 ;;
    --head) HEAD_REF="$2"; shift 2 ;;
    --force) FORCE="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--base REF] [--head REF] [--force NAME|all] [--format names|matrix|json]"
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

export DETECT_BASE_REF="$BASE_REF"
export DETECT_HEAD_REF="$HEAD_REF"
export DETECT_FORCE="$FORCE"
export DETECT_FORMAT="$FORMAT"
export DETECT_CATALOG="${ROOT}/images.yaml"
export DETECT_ROOT="$ROOT"

repo_python - <<'PY'
import fnmatch, json, os, subprocess, sys
import yaml

root = os.environ["DETECT_ROOT"]
catalog_path = os.environ["DETECT_CATALOG"]
base = os.environ["DETECT_BASE_REF"]
head = os.environ["DETECT_HEAD_REF"]
force = os.environ.get("DETECT_FORCE") or ""
fmt = os.environ["DETECT_FORMAT"]

with open(catalog_path) as f:
    data = yaml.safe_load(f)

images = data.get("images", [])
ns = data.get("namespace", "lyricistmarbling")
by_name = {img["name"]: img for img in images}

def ref_exists(ref: str) -> bool:
    r = subprocess.run(["git", "rev-parse", "--verify", ref],
                       cwd=root, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return r.returncode == 0

def changed_files() -> list[str]:
    if not ref_exists(base):
        print(f"detect-changed-images: base ref {base} missing; marking all", file=sys.stderr)
        return ["*ALL*"]
    r = subprocess.run(
        ["git", "diff", "--name-only", f"{base}...{head}"],
        cwd=root, capture_output=True, text=True,
    )
    if r.returncode != 0:
        r = subprocess.run(
            ["git", "diff", "--name-only", base, head],
            cwd=root, capture_output=True, text=True, check=True,
        )
    files = [ln for ln in r.stdout.splitlines() if ln]
    return files

def matches(path: str, patterns: list) -> bool:
    for p in patterns:
        if fnmatch.fnmatch(path, p):
            return True
        if p.endswith("/**"):
            prefix = p[:-3]
            if path == prefix.rstrip("/") or path.startswith(prefix):
                return True
    return False

if force:
    if force == "all":
        names = [img["name"] for img in images]
    else:
        if force not in by_name:
            sys.exit(f"unknown image: {force}")
        names = [force]
else:
    files = changed_files()
    if files == ["*ALL*"]:
        names = [img["name"] for img in images]
    else:
        names = []
        for img in images:
            watch = img.get("watch") or []
            if any(matches(f, watch) for f in files):
                names.append(img["name"])

# dedupe preserve order
seen = set()
uniq = []
for n in names:
    if n not in seen:
        seen.add(n)
        uniq.append(n)

def matrix(names_list):
    include = []
    for name in names_list:
        img = by_name[name]
        ba = img.get("build_args") or {}
        entry = {
            "name": name,
            "context": img["context"],
            "dockerfile": img.get("dockerfile", "Dockerfile"),
            "version_file": img["version_file"],
            "full_name": f"{ns}/{name}",
            "target": img.get("target") or "",
            "build_args": " ".join(f"{k}={v}" for k, v in ba.items()),
            "extra_tags": ",".join(str(t) for t in (img.get("extra_tags") or [])),
        }
        include.append(entry)
    return {"include": include}

if fmt == "names":
    print("\n".join(uniq))
elif fmt == "matrix":
    print(json.dumps(matrix(uniq)))
elif fmt == "json":
    print(json.dumps({"any_changed": bool(uniq), "images": uniq}))
else:
    sys.exit(f"unknown format: {fmt}")
PY
