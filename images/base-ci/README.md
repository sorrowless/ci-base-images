# CI base images (DinD + Ansible tooling)
#
# Published as:
#   lyricistmarbling/base-ci-image           (target: base)
#   lyricistmarbling/base-ci-image-ansible   (target: base-ansible)
#
# Both images share one VERSION file and are released together when this
# directory changes.
#
# The base image is Docker-in-Docker based on cruizba/ubuntu-dind and runs as
# root by design (dockerd requires privileged access in CI).
#
# Build locally:
#   docker build --target base -t base-ci-image:local images/base-ci
#   docker build --target base-ansible -t base-ci-image-ansible:local images/base-ci
#
# Former Hub name `lyricistmarbling/ansible-ci-image` is deprecated; use
# `base-ci-image-ansible` instead.
