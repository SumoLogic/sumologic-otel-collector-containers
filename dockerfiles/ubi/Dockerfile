# Build RedHat compliant image
FROM registry.access.redhat.com/ubi8/ubi-minimal:8.10
ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG COLLECTOR_BIN=otelcol-sumo
ARG CONFIG_BIN=otelcol-config
ENV REMOTELY_MANAGED=false

ENV SUMMARY="UBI based sumologic-otel-collector" \
    DESCRIPTION="Sumo Logic Distribution for OpenTelemetry Collector is a Sumo Logic-supported distribution of the OpenTelemetry Collector. It is a single agent to send logs, metrics and traces to Sumo Logic."

LABEL name="sumologic-otel-collector" \
    vendor="Sumo Logic" \
    release="0" \
    summary="$SUMMARY" \
    description="$DESCRIPTION" \
    io.k8s.description="$DESCRIPTION" \
    maintainer="collection@sumologic.com"

RUN echo "I am running on ${BUILDPLATFORM}, building for ${TARGETPLATFORM}"

COPY artifacts/$TARGETPLATFORM/$COLLECTOR_BIN /otelcol-sumo
COPY artifacts/$TARGETPLATFORM/$CONFIG_BIN /usr/local/bin/otelcol-config

# This shouldn't be necessary but sometimes we end up with execution bit not set.
# ref: https://github.com/open-telemetry/opentelemetry-collector/issues/1317
RUN chmod 755 /otelcol-sumo
RUN chmod 755 /usr/local/bin/otelcol-config

ADD https://raw.githubusercontent.com/SumoLogic/sumologic-otel-collector/main/LICENSE \
    /licenses/LICENSE

# hadolint ignore=DL3041
RUN microdnf update && microdnf install -y \
    systemd \
    hostname \
    findutils \
    curl \
    && microdnf clean all

RUN mkdir -p /var/cache/otelcol-sumo /etc/otel && \
    chmod 775 /var/cache/otelcol-sumo /etc/otel
ENV HOME=/etc/otel

RUN mkdir -p $HOME \
    && curl -sLo $HOME/install.sh \
       https://raw.githubusercontent.com/SumoLogic/sumologic-otel-collector-packaging/main/install-script/install.sh \
    && chmod +x $HOME/install.sh

# ---- INLINE ENTRYPOINT ----
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
