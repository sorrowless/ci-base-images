ARG UPSTREAM_TAG=v1.82.0
FROM oliver006/redis_exporter:${UPSTREAM_TAG}

# Match upstream non-root UID (scratch image already runs as 59000; restate for scanners).
USER 59000:59000

LABEL org.opencontainers.image.source="https://github.com/sorrowless/ci-base-images" \
      org.opencontainers.image.description="Redis/Valkey Prometheus exporter (re-tag of oliver006/redis_exporter)" \
      org.opencontainers.image.base.name="oliver006/redis_exporter"
