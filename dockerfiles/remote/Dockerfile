FROM alpine:3.20.2
ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG COLLECTOR_BIN=otelcol-sumo
ARG CONFIG_BIN=otelcol-config
ARG USER_UID=10001

ENV SUMMARY="Alpine based sumologic-otel-collector" \
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

RUN apk add --no-cache bash curl coreutils

RUN mkdir -p /var/cache/otelcol-sumo /etc/otel && \
    chmod 775 /var/cache/otelcol-sumo /etc/otel && \
    chown -R ${USER_UID}:${USER_UID} /var/cache/otelcol-sumo /etc/otel

RUN mkdir -p \
        /etc/otelcol-sumo \
        /etc/otelcol-sumo/conf.d \
        /etc/otelcol-sumo/env \
        /etc/otelcol-sumo/opamp.d \
        /var/lib/otelcol-sumo \
        /var/lib/otelcol-sumo/file_storage && \
    chmod 770 \
        /etc/otelcol-sumo \
        /var/cache/otelcol-sumo \
        /etc/otelcol-sumo/conf.d \
        /etc/otelcol-sumo/env \
        /etc/otelcol-sumo/opamp.d \
        /var/lib/otelcol-sumo \
        /var/lib/otelcol-sumo/file_storage && \
    chown -R ${USER_UID}:${USER_UID} \
        /etc/otelcol-sumo \
        /etc/otelcol-sumo/conf.d \
        /etc/otelcol-sumo/env \
        /etc/otelcol-sumo/opamp.d \
        /var/lib/otelcol-sumo \
        /var/lib/otelcol-sumo/file_storage

USER ${USER_UID}
ENV HOME=/etc/otel

RUN mkdir -p $HOME \
    && curl -sLo $HOME/install.sh \
       https://raw.githubusercontent.com/SumoLogic/sumologic-otel-collector-packaging/main/install-script/install.sh \
    && chmod +x $HOME/install.sh

# ---- INLINE ENTRYPOINT ----
ENTRYPOINT ["/bin/bash", "-c", "\
set -e; \
\
echo 'Running install.sh'; \
/etc/otel/install.sh --config-only \"$@\"; \
\
echo 'Starting collector with remote config'; \
exec /otelcol-sumo --remote-config opamp:/etc/otelcol-sumo/sumologic-remote.yaml; \
", "--"]