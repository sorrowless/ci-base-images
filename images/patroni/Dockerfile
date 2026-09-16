FROM postgres:18.0

RUN usermod -u 70 postgres

# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3 \
        patroni \
        python3-consul \
        libpq5 \
        openssl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

USER postgres

EXPOSE 5432 8008

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD python3 -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8008/health')" || exit 1

# Config is supplied at runtime via volume mount or PATRONI_* env vars.
# Example: docker run -v /path/to/patroni.yml:/patroni.yml lyricistmarbling/patroni /patroni.yml
ENTRYPOINT ["patroni"]
CMD ["/patroni.yml"]
