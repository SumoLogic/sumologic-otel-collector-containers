# For FIPS binary, there are some debian runtime dependencies
FROM debian:12.6 AS otelcol
ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG COLLECTOR_BIN=otelcol-sumo
ARG CONFIG_BIN=otelcol-config

RUN echo "I am running on ${BUILDPLATFORM}, building for ${TARGETPLATFORM}"

COPY artifacts/$TARGETPLATFORM/$COLLECTOR_BIN /otelcol-sumo
COPY artifacts/$TARGETPLATFORM/$CONFIG_BIN /otelcol-config

# This shouldn't be necessary but sometimes we end up with execution bit not set.
# ref: https://github.com/open-telemetry/opentelemetry-collector/issues/1317
RUN chmod 755 /otelcol-sumo
RUN chmod 755 /otelcol-config

# NOTE: otelcol-sumo must be statically compiled
# hadolint ignore=DL4006,SC2046
RUN tar czhf otelcol.tar.gz /otelcol-sumo $(ldd /otelcol-sumo | grep -oP '\/.*? ')
RUN tar czhf otelcol-config.tar.gz /otelcol-config $(ldd /otelcol-config | grep -oP '\/.*? ')

# extract package to /output so it can be taken as base for scratch image
# we do not copy archive into scratch image, as it doesn't have tar executable
# however, we can copy full directory as root (/) to be base file structure for scratch image
RUN mkdir -p /output \
    && tar xf /otelcol.tar.gz --directory /output \
    && tar xf /otelcol-config.tar.gz --directory /output

RUN microdnf update -y \
    && microdnf install -y curl \
    && microdnf clean all


FROM alpine:3.20.2 AS certs

# hadolint ignore=DL3018
RUN apk add --no-cache ca-certificates

FROM alpine:3.20.2 AS directories
RUN mkdir /etc/otel/

FROM debian:12.6 AS systemd

# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcap-ng0 \
    systemd

# prepare package with journald and it's dependencies keeping original paths
# h stands for dereference of symbolic links
# hadolint ignore=DL4006,SC2046
RUN tar czhf journalctl.tar.gz /bin/journalctl $(ldd /bin/journalctl | grep -oP '\/.*? ')

# extract package to /output so it can be taken as base for scratch image
# we do not copy archive into scratch image, as it doesn't have tar executable
# however, we can copy full directory as root (/) to be base file structure for scratch image
RUN mkdir /output && tar xf /journalctl.tar.gz --directory /output

FROM scratch
ARG BUILD_TAG=latest
ENV TAG=$BUILD_TAG
ENV HOME=/etc/otel/
ENV REMOTELY_MANAGED=false

# copy journalctl and it's dependencies as base structure
COPY --from=systemd /output/ /
COPY --from=certs /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=otelcol /output/ /
COPY --from=directories --chown=${USER_UID}:${USER_UID} /etc/otel/ /etc/otel/
COPY /output/otelcol-config /usr/local/bin/


RUN mkdir -p /var/cache/otelcol-sumo /etc/otel && \
    chmod 775 /var/cache/otelcol-sumo /etc/otel
RUN mkdir -p $HOME \
    && curl -sLo $HOME/install.sh \
       https://raw.githubusercontent.com/SumoLogic/sumologic-otel-collector-packaging/main/install-script/install.sh \
    && chmod +x $HOME/install.sh

ENTRYPOINT ["bash", "-c", "\
set -e; \
\
echo 'Running install.sh as root'; \
/etc/otel/install.sh --config-only \"$@\"; \
\
# Use REMOTELY_MANAGED env instead of --remote argument \
if [ \"$REMOTELY_MANAGED\" = 'true' ]; then \
    echo 'Starting collector with remote config'; \
    exec /otelcol-sumo --remote-config opamp:/etc/otelcol-sumo/sumologic-remote.yaml; \
else \
    echo 'Starting collector with local config'; \
    exec /otelcol-sumo --config /etc/otel/config.yaml; \
fi \
", "--"]
    