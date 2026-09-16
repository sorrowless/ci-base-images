# ci-base-images

Base Docker images used in CI and ops tooling. Images are built from this monorepo and published to Docker Hub under **`lyricistmarbling/*`**.

## Images

| Image | Path | Description |
|-------|------|-------------|
| `lyricistmarbling/base-ci-image` | [`images/base-ci`](images/base-ci) | Ubuntu DinD CI runner |
| `lyricistmarbling/base-ci-image-ansible` | [`images/base-ci`](images/base-ci) | DinD + Ansible / hadolint toolchain |
| `lyricistmarbling/patroni` | [`images/patroni`](images/patroni) | PostgreSQL 18 + Patroni |
| `lyricistmarbling/redis-exporter` | [`images/redis-exporter`](images/redis-exporter) | Re-tag of `oliver006/redis_exporter` |

Catalog (names, build args, watch paths): [`images.yaml`](images.yaml).

Deprecated Hub name: `lyricistmarbling/ansible-ci-image` → use `base-ci-image-ansible`.

## Layout

```
images.yaml                 # catalog (source of truth for CI)
images/<name>/Dockerfile
images/<name>/VERSION       # per-image (or shared) semver
scripts/                    # detect / lint / release helpers
.github/workflows/ci.yml    # PR: lint + build changed images only
.github/workflows/release.yml
```

## CI flow

1. **Pull request** → detect changed images via `git diff` against the base branch → hadolint, Trivy config, `docker build` (no push). Unchanged images are skipped.
2. **Merge to `master`** → detect changes vs previous commit → patch-bump `VERSION` (max of git tag / Docker Hub / file) → build & push `:X.Y.Z`, `:latest`, `:sha-<short>` → commit + annotated tag `{image}-vX.Y.Z` → push tags.
3. **Manual** → Actions → Release → `workflow_dispatch` with image name or `all`.

Versioning follows the same idea as [backup-reporter](https://github.com/sorrowless/backup-reporter) (three-way sync + patch bump), adapted for Docker Hub and per-image tags.

Commits starting with `Bump version` do not re-trigger release (loop guard).

### Required secrets

- `DOCKER_USERNAME` / `DOCKER_PASSWORD` — Docker Hub credentials for the `lyricistmarbling` namespace

## Local commands

```bash
make prepare                 # uv venv + pyyaml/packaging, hadolint, trivy, jq
make changed                 # list images changed vs origin/master
make lint                    # lint changed images
make build IMAGE=patroni     # force release one image (needs Hub login)
make build IMAGE=all         # release everything
DRY_RUN=1 SKIP_PUSH=1 make build IMAGE=redis-exporter
make push-release            # after a local release-bump
```

`make prepare` installs [uv](https://github.com/astral-sh/uv) if needed, creates `.venv` (default Python 3.12), and never touches the system Python (avoids `externally-managed-environment`).

## Automatic commit messages

```bash
git add -p
git commit          # prints "analyzing commit contents…", then opens nvim
SKIP_AI_COMMIT=1 git commit   # bypass
```

## License

Apache-2.0 — see [LICENSE](LICENSE).
