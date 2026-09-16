ARG DOCKER_VERSION=noble-28.0.1
FROM cruizba/ubuntu-dind:${DOCKER_VERSION} AS base

# DinD CI runner — runs as root by design (docker daemon needs privileged access).

FROM base AS base-ansible
ARG HADOLINT_VERSION=v2.13.1
# hadolint-linux-x86_64 v2.13.1
ARG HADOLINT_SHA256=f8b05e4c724cdeb84c0dca07e40936c3d875c0af5d120a27c94026a0f370b2cf

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /

# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash git curl wget ca-certificates \
        pipx python3-pip python3-dev \
        libffi-dev libssl-dev gcc libc-dev cargo make jq \
        python3-requests python3-urllib3 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN wget -q -O /bin/hadolint \
        "https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-linux-x86_64" && \
    echo "${HADOLINT_SHA256}  /bin/hadolint" | sha256sum -c - && \
    chmod +x /bin/hadolint

COPY requirements.txt requirements_extra.txt ./
RUN pip3 install --break-system-packages \
        -r requirements.txt -r requirements_extra.txt \
        --no-cache-dir

CMD ["/bin/bash"]
