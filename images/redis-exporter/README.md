# Redis / Valkey exporter

Thin re-tag of the official [oliver006/redis_exporter](https://github.com/oliver006/redis_exporter) image.

**Hub:** `lyricistmarbling/redis-exporter`

Upstream tag is controlled by `UPSTREAM_TAG` build-arg (see [`images.yaml`](../../images.yaml)).

## Run

```bash
docker run -d --name redis_exporter -p 9121:9121 \
  lyricistmarbling/redis-exporter:latest
```

Alpine-style debugging is available from upstream (`oliver006/redis_exporter:alpine`); this wrapper tracks the default scratch-based release.

Flags and environment variables: [upstream docs](https://github.com/oliver006/redis_exporter?tab=readme-ov-file#command-line-flags).
