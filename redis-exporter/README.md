# Redis/Valkey exporter

Prometheus exporter for Valkey metrics (Redis-compatible).
Supports Valkey 7.x, 8.x, 9.x (and Redis) from [oliver006/redis_exporter](https://github.com/oliver006/redis_exporter)

## Run via Docker

You can run it like this:

```bash
docker run -d --name redis_exporter -p 9121:9121 redis_exporter
```

The latest docker image contains only the exporter binary. If e.g. for debugging purposes, you need the exporter running in an image that has a shell then you can run the alpine image:

```bash
docker run -d --name redis_exporter -p 9121:9121 redis_exporter:alpine
```

If you try to access a Redis instance running on the host node, you'll need to add --network host so the redis_exporter container can access it:

```bash
docker run -d --name redis_exporter --network host redis_exporter
```

## Environments

All variable you can firnd here
[redis_exporter Variable and Command-lines](https://github.com/oliver006/redis_exporter?tab=readme-ov-file#command-line-flags)
