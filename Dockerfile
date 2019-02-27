FROM erlang:20.3 AS build-env

WORKDIR /vernemq-build

ARG VERNEMQ_GIT_REF=1.7.0
ARG TARGET=rel
ARG VERNEMQ_REPO=https://github.com/vernemq/vernemq.git

# Defaults
ENV DOCKER_VERNEMQ_KUBERNETES_APP_LABEL vernemq
ENV DOCKER_VERNEMQ_LOG__CONSOLE console

RUN \
    apt-get update \
    && apt-get -y install build-essential git libssl-dev  \
    && git clone -b $VERNEMQ_GIT_REF --single-branch --depth 1 $VERNEMQ_REPO .

ADD bin/build.sh build.sh

RUN ./build.sh $TARGET


FROM debian:stretch-slim

RUN apt-get update && \
    apt-get -y install bash procps openssl iproute2 curl jq && \
    rm -rf /var/lib/apt/lists/* && \
    addgroup --gid 10000 vernemq && \
    adduser --uid 10000 --system --ingroup vernemq --home /vernemq --disabled-password vernemq

WORKDIR /vernemq

# Defaults
ENV DOCKER_VERNEMQ_KUBERNETES_LABEL_SELECTOR="app=vernemq" \
    DOCKER_VERNEMQ_LOG__CONSOLE=console \
    PATH="/vernemq/bin:$PATH" \
    VERNEMQ_VERSION="1.10.0"

COPY --chown=10000:10000 bin/vernemq.sh /usr/sbin/start_vernemq
COPY --chown=10000:10000 files/vm.args /vernemq/etc/vm.args
ADD https://github.com/vernemq/vernemq/releases/download/$VERNEMQ_VERSION/vernemq-$VERNEMQ_VERSION.stretch.tar.gz /tmp

RUN tar -xzvf /tmp/vernemq-$VERNEMQ_VERSION.stretch.tar.gz && \
    rm /tmp/vernemq-$VERNEMQ_VERSION.stretch.tar.gz && \
    chown -R 10000:10000 /vernemq && \
##### Begin additions for TechnoCore
RUN apt-get update && apt-get install -y expect mosquitto-clients 

# Add dogfish
COPY dogfish/ /usr/share/dogfish
RUN ln -s /usr/share/dogfish/dogfish /usr/bin/dogfish
COPY shell-migrations/ /usr/share/dogfish/shell-migrations
COPY dogfish/shell-migrations-shared/ /usr/share/dogfish/shell-migrations-shared

# Create log file.
RUN touch /vernemq/etc/migrations.log

# Symlink log file.
RUN mkdir /var/lib/dogfish
RUN ln -s /vernemq/etc/migrations.log /var/lib/dogfish/migrations.log 

COPY vernemq.conf /vernemq/vernemq.conf
WORKDIR /vernemq/etc

# Set up the CMD as well as the pre and post hooks.
COPY go-init /bin/go-init
COPY entrypoint.sh /usr/bin/entrypoint.sh
COPY exitpoint.sh /usr/bin/exitpoint.sh

COPY mqtt-scripts/ /usr/share/mqtt-scripts
RUN chmod +x /usr/share/mqtt-scripts/*

##### End additions for TechnoCore

RUN addgroup vernemq && \
    adduser --system --ingroup vernemq --home /vernemq --disabled-password vernemq && \
    chown -R vernemq:vernemq /vernemq && \
    ln -s /vernemq/etc /etc/vernemq && \
    ln -s /vernemq/data /var/lib/vernemq && \
    ln -s /vernemq/log /var/log/vernemq

# Ports
# 1883  MQTT
# 8883  MQTT/SSL
# 8080  MQTT WebSockets
# 44053 VerneMQ Message Distribution
# 4369  EPMD - Erlang Port Mapper Daemon
# 8888  Prometheus Metrics
# 9100 9101 9102 9103 9104 9105 9106 9107 9108 9109  Specific Distributed Erlang Port Range

EXPOSE 1883 8883 8080 44053 4369 8888 \
       9100 9101 9102 9103 9104 9105 9106 9107 9108 9109


VOLUME ["/vernemq/log", "/vernemq/data", "/vernemq/etc"]

HEALTHCHECK CMD vernemq ping | grep -q pong

USER vernemq

CMD ["start_vernemq"]
FROM erlio/docker-vernemq 
FROM erlio/docker-vernemq:1.6.1
RUN apt-get update && apt-get install -y expect mosquitto-clients 

# Add dogfish
COPY dogfish/ /usr/share/dogfish
RUN ln -s /usr/share/dogfish/dogfish /usr/bin/dogfish
COPY shell-migrations/ /usr/share/dogfish/shell-migrations
COPY dogfish/shell-migrations-shared/ /usr/share/dogfish/shell-migrations-shared

# Create log file.
RUN touch /etc/vernemq/migrations.log

# Symlink log file.
RUN mkdir /var/lib/dogfish
RUN ln -s /etc/vernemq/migrations.log /var/lib/dogfish/migrations.log 

COPY vernemq.conf /etc/vernemq.conf
WORKDIR /etc/vernemq

# Set up the CMD as well as the pre and post hooks.
COPY go-init /bin/go-init
COPY entrypoint.sh /usr/bin/entrypoint.sh
COPY exitpoint.sh /usr/bin/exitpoint.sh
ENTRYPOINT ["go-init"]
CMD ["-pre", "entrypoint.sh", "-main", "start_vernemq", "-post", "exitpoint.sh"]

COPY mqtt-scripts/ /usr/share/mqtt-scripts
RUN chmod +x /usr/share/mqtt-scripts/*
##### Begin additions for TechnoCore
ENTRYPOINT ["go-init"]
CMD ["-pre", "entrypoint.sh", "-main", "start_vernemq", "-post", "exitpoint.sh"]
##### End additions for TechnoCore
