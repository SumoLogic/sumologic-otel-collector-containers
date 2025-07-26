FROM mcr.microsoft.com/windows/nanoserver:ltsc2022
ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG COLLECTOR_BIN="otelcol-sumo"

# netapi32.dll is not included in nanoserver:ltsc2022 and older. It is necessary
# for Go applications to run. Fortunately, we can copy netapi32.dll from the
# larger servercore image. This allows us to keep our image size small while
# still providing the necessary functionality for our Go application.
COPY /netapi32.dll /windows/system32/netapi32.dll

RUN echo "I am running on ${BUILDPLATFORM}, building for ${TARGETPLATFORM}"

COPY /artifacts/$TARGETPLATFORM/$COLLECTOR_BIN.exe /otelcol-sumo.exe
ENTRYPOINT ["/otelcol-sumo.exe"]
CMD ["--config", "/etc/otel/config.yaml"]
