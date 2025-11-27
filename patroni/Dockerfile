FROM postgres:18.0
RUN usermod -u 70 postgres

RUN apt update && \
    apt install -y g++ python3 python3-dev python3-pip libffi-dev libpq-dev openssl vim patroni python3-consul
COPY ./patroni.yml /patroni.yml
ENTRYPOINT ["patroni", "patroni.yml"]
