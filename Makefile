.PHONY: help prepare changed lint build publish push-release hooks

export PATH := $(CURDIR)/.bin:$(CURDIR)/.venv/bin:$(HOME)/.local/bin:$(PATH)

GIT_REMOTE ?= origin
IMAGE ?=
BASE ?= origin/master
HEAD ?= HEAD
PYTHON_VERSION ?= 3.12

help:
	@echo 'Targets:'
	@echo '  make prepare              - uv venv + pyyaml/packaging, hadolint, trivy, jq'
	@echo '  make changed              - list images changed vs BASE (default origin/master)'
	@echo '  make lint                 - hadolint + trivy config for changed (or IMAGE=)'
	@echo '  make build                - bump VERSION, build and push changed images'
	@echo '  make publish              - alias for build (Docker Hub push included)'
	@echo '  make push-release         - push release commit and tags to origin'
	@echo '  make hooks                - enable repo .githooks (AI prepare-commit-msg)'
	@echo ''
	@echo 'Variables:'
	@echo '  IMAGE=name|all            - force a single image or all'
	@echo '  BASE=ref HEAD=ref         - git range for change detection'
	@echo '  PYTHON_VERSION=3.12       - Python for uv venv'
	@echo '  DRY_RUN=1 SKIP_PUSH=1 SKIP_GIT=1'

prepare:
	@PYTHON_VERSION="$(PYTHON_VERSION)" bash scripts/prepare.sh

changed: prepare
ifeq ($(IMAGE),)
	@bash scripts/detect-changed-images.sh --base "$(BASE)" --head "$(HEAD)" --format names
else
	@bash scripts/detect-changed-images.sh --force "$(IMAGE)" --format names
endif

lint: prepare
ifeq ($(IMAGE),)
	@names="$$(bash scripts/detect-changed-images.sh --base "$(BASE)" --head "$(HEAD)" --format names)"; \
	if [ -z "$$names" ]; then echo "lint: nothing changed"; exit 0; fi; \
	for n in $$names; do bash scripts/lint-image.sh "$$n"; done
else
	@bash scripts/lint-image.sh "$(IMAGE)"
endif

build: prepare
ifeq ($(IMAGE),)
	@bash scripts/release-bump.sh
else
	@bash scripts/release-bump.sh --force "$(IMAGE)"
endif

publish: build

push-release:
	git push $(GIT_REMOTE) HEAD
	git push $(GIT_REMOTE) --tags

hooks:
	@git config core.hooksPath .githooks
	@echo "hooks: core.hooksPath=.githooks     # (prepare-commit-msg -> something, like an ai agent)"
	@echo "hooks: SKIP_AI_COMMIT=1             # bypass generating commits automatically"
	@echo "hooks: note — global hooksPath may override; check: git config --show-origin core.hooksPath"
