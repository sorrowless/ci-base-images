# Patroni image

PostgreSQL + Patroni image for [ansible_patroni_cluster](https://github.com/sorrowless/ansible_patroni_cluster).

**Hub:** `lyricistmarbling/patroni` (also tagged with PostgreSQL major.minor, e.g. `18.0`)

> **Migration:** previously published as `ageres210784/patroni:18.0`. Update pull references to `lyricistmarbling/patroni:18.0` (or a semver tag).

## Security note

An earlier revision of this repository committed real passwords and LAN IPs in `patroni.yml`. Those credentials must be considered **compromised** — rotate them everywhere they were used. The image no longer bakes in a config file.

## Usage

Supply config at runtime:

```bash
docker run --rm -v "$PWD/patroni.yml:/patroni.yml:ro" lyricistmarbling/patroni:latest
```

Or use `PATRONI_*` environment variables (see Patroni docs). An example config without secrets is in [`patroni.yml.example`](patroni.yml.example).

Local lab compose (single-node Consul):

```bash
cd images/patroni && docker compose up --build
```

Edit `patroni.yml.example` placeholders before anything beyond a local smoke test.
