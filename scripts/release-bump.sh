#!/usr/bin/env bash
# Bump VERSION, build, and push images to Docker Hub; then commit + tag.
# Usage:
#   release-bump.sh [--images name1,name2] [--force NAME|all] [--dry-run] [--skip-push] [--skip-git]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck source=scripts/lib/env.sh
source "$ROOT/scripts/lib/env.sh"

IMAGES_CSV=""
FORCE=""
DRY_RUN="${DRY_RUN:-0}"
SKIP_PUSH="${SKIP_PUSH:-0}"
SKIP_GIT="${SKIP_GIT:-0}"
GIT_REMOTE="${GIT_REMOTE:-origin}"

while [ $# -gt 0 ]; do
  case "$1" in
    --images) IMAGES_CSV="$2"; shift 2 ;;
    --force) FORCE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --skip-push) SKIP_PUSH=1; shift ;;
    --skip-git) SKIP_GIT=1; shift ;;
    -h|--help)
      echo "Usage: $0 [--images a,b] [--force NAME|all] [--dry-run] [--skip-push] [--skip-git]"
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

export RELEASE_IMAGES_CSV="$IMAGES_CSV"
export RELEASE_FORCE="$FORCE"
export RELEASE_DRY_RUN="$DRY_RUN"
export RELEASE_SKIP_PUSH="$SKIP_PUSH"
export RELEASE_SKIP_GIT="$SKIP_GIT"
export RELEASE_GIT_REMOTE="$GIT_REMOTE"
export RELEASE_ROOT="$ROOT"
export RELEASE_CATALOG="${ROOT}/images.yaml"

repo_python - <<'PY'
import json, os, re, subprocess, sys, urllib.request
from collections import defaultdict

import yaml
from packaging.version import Version

root = os.environ["RELEASE_ROOT"]
catalog_path = os.environ["RELEASE_CATALOG"]
dry_run = os.environ.get("RELEASE_DRY_RUN", "0") == "1"
skip_push = os.environ.get("RELEASE_SKIP_PUSH", "0") == "1"
skip_git = os.environ.get("RELEASE_SKIP_GIT", "0") == "1"
git_remote = os.environ.get("RELEASE_GIT_REMOTE", "origin")
force = os.environ.get("RELEASE_FORCE") or ""
images_csv = os.environ.get("RELEASE_IMAGES_CSV") or ""

def die(msg):
    print(f"release-bump: {msg}", file=sys.stderr)
    sys.exit(1)

def run(cmd, check=True, capture=False):
    print("+", " ".join(cmd))
    if dry_run and cmd[0] in ("docker", "git") and cmd[1] in ("build", "push", "commit", "tag", "add"):
        return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")
    kwargs = {}
    if capture:
        kwargs["capture_output"] = True
        kwargs["text"] = True
    return subprocess.run(cmd, cwd=root, check=check, **kwargs)

with open(catalog_path) as f:
    data = yaml.safe_load(f)

ns = os.environ.get("DOCKER_NAMESPACE") or data.get("namespace", "lyricistmarbling")
by_name = {img["name"]: img for img in data["images"]}

# Resolve image list
if force:
    r = run(["bash", "scripts/detect-changed-images.sh", "--force", force, "--format", "names"], capture=True)
    image_list = [ln for ln in (r.stdout or "").splitlines() if ln]
elif images_csv:
    image_list = [x.strip() for x in images_csv.split(",") if x.strip()]
else:
    r = run(["bash", "scripts/detect-changed-images.sh", "--format", "names"], capture=True)
    image_list = [ln for ln in (r.stdout or "").splitlines() if ln]

if not image_list:
    print("release-bump: no images to release")
    sys.exit(0)

for name in image_list:
    if name not in by_name:
        die(f"unknown image: {name}")

if not skip_git and not dry_run:
    dirty = run(["git", "diff", "--quiet"], check=False).returncode != 0
    dirty_staged = run(["git", "diff", "--cached", "--quiet"], check=False).returncode != 0
    if dirty or dirty_staged:
        die("working tree is not clean; commit or stash changes before release")
    run(["git", "fetch", git_remote, "--tags"], check=False)

short_sha = run(["git", "rev-parse", "--short", "HEAD"], capture=True).stdout.strip()

def normalize(v: str) -> str:
    return v[1:] if v.startswith("v") else v

def file_version(path: str) -> str:
    if not os.path.isfile(path):
        return "0.0.0"
    with open(path) as f:
        return f.read().strip() or "0.0.0"

def git_latest_tag_version(image: str) -> str:
    r = run(
        ["git", "for-each-ref", "--sort=-v:refname", "--format=%(refname:short)", f"refs/tags/{image}-v*"],
        capture=True, check=False,
    )
    lines = [ln for ln in (r.stdout or "").splitlines() if ln]
    if not lines:
        return "0.0.0"
    tag = lines[0]
    prefix = f"{image}-v"
    return normalize(tag[len(prefix):] if tag.startswith(prefix) else tag)

def hub_latest_version(image: str) -> str:
    url = f"https://hub.docker.com/v2/repositories/{ns}/{image}/tags?page_size=100&ordering=last_updated"
    try:
        with urllib.request.urlopen(url, timeout=30) as resp:
            payload = json.load(resp)
    except Exception:
        return "0.0.0"
    tags = [t.get("name", "") for t in payload.get("results", [])]
    semver = [t for t in tags if re.fullmatch(r"\d+\.\d+\.\d+", t)]
    if not semver:
        return "0.0.0"
    return str(sorted(semver, key=lambda v: Version(v))[-1])

def semver_max(*versions: str) -> str:
    return str(max((Version(normalize(v)) for v in versions), default=Version("0.0.0")))

def patch_bump(base: str) -> str:
    v = Version(normalize(base))
    parts = list(v.release) + [0] * (3 - len(v.release))
    return f"{parts[0]}.{parts[1]}.{parts[2] + 1}"

# Group by version_file
groups = defaultdict(list)
for name in image_list:
    groups[by_name[name]["version_file"]].append(name)

vf_new = {}
for vf, names in groups.items():
    file_ver = file_version(os.path.join(root, vf) if not os.path.isabs(vf) else vf)
    git_ver = "0.0.0"
    hub_ver = "0.0.0"
    for n in names:
        git_ver = semver_max(git_ver, git_latest_tag_version(n))
        hub_ver = semver_max(hub_ver, hub_latest_version(n))
    base = semver_max(git_ver, hub_ver, file_ver)
    new = patch_bump(base)
    vf_new[vf] = new
    print(f"release-bump: {vf}: file={file_ver} git={git_ver} hub={hub_ver} -> {new}")

# Write VERSION files
for vf, new in vf_new.items():
    path = os.path.join(root, vf)
    if dry_run:
        print(f"dry-run: would write {new} to {path}")
    else:
        with open(path, "w") as f:
            f.write(new + "\n")

def build_and_push(name: str, version: str):
    img = by_name[name]
    context = img["context"]
    dockerfile = img.get("dockerfile", "Dockerfile")
    target = img.get("target")
    build_args = img.get("build_args") or {}
    extra_tags = [str(t) for t in (img.get("extra_tags") or [])]
    full = f"{ns}/{name}"

    cmd = ["docker", "build", "-f", f"{context}/{dockerfile}"]
    if target:
        cmd += ["--target", target]
    for k, v in build_args.items():
        cmd += ["--build-arg", f"{k}={v}"]
    tags = [f"{full}:{version}", f"{full}:latest", f"{full}:sha-{short_sha}"] + [f"{full}:{t}" for t in extra_tags]
    for t in tags:
        cmd += ["-t", t]
    cmd.append(context)

    print(f"release-bump: building {full}:{version}")
    run(cmd)

    if skip_push:
        print(f"release-bump: skip push for {full}")
        return
    for t in tags:
        run(["docker", "push", t])

for name in image_list:
    vf = by_name[name]["version_file"]
    build_and_push(name, vf_new[vf])

if skip_git or dry_run:
    print("release-bump: done (skip git)")
    sys.exit(0)

# Commit + tags
vf_paths = list(vf_new.keys())
run(["git", "add", *vf_paths])
body_lines = [f"- {name} -> {vf_new[by_name[name]['version_file']]}" for name in image_list]
msg = "Bump version for released images\n\n" + "\n".join(body_lines) + "\n"
run(["git", "commit", "-m", msg])

for name in image_list:
    new = vf_new[by_name[name]["version_file"]]
    new_tag = f"{name}-v{new}"
    # check remote tag collision
    r = run(["git", "ls-remote", git_remote, f"refs/tags/{new_tag}"], capture=True, check=False)
    remote_line = (r.stdout or "").strip()
    if remote_line:
        remote_commit = remote_line.split()[0]
        head = run(["git", "rev-parse", "HEAD"], capture=True).stdout.strip()
        if remote_commit and remote_commit != head:
            die(f"tag {new_tag} already exists on {git_remote} at a different commit")
    run(["git", "tag", "-a", new_tag, "-m", f"Release {name} {new}"])
    print(f"release-bump: tagged {new_tag}")

print("release-bump: complete; run make push-release to push commit and tags")
PY
