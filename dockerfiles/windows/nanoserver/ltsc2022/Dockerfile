FROM mcr.microsoft.com/windows/nanoserver:ltsc2022
ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG COLLECTOR_BIN="otelcol-sumo"
ARG DOCKERFILE_DIR="/dockerfiles/windows/nanoserver/ltsc2022"

# netapi32.dll is not included in nanoserver:ltsc2022 and older. It is necessary
# for Go applications to run. Fortunately, the servercore images include
# netapi32.dll. To minimize build times we commit this file to this repo.
COPY $DOCKERFILE_DIR/netapi32.dll /windows/system32/netapi32.dll

# TODO: This appears to be failing intermittently, perhaps as buildkit is still
# buggy on Windows. Attempt to remove this sometime in the future.
#RUN echo "I am running on ${BUILDPLATFORM}, building for ${TARGETPLATFORM}"

COPY /artifacts/$TARGETPLATFORM/$COLLECTOR_BIN.exe /otelcol-sumo.exe
ENTRYPOINT ["/otelcol-sumo.exe"]
CMD ["--config", "/etc/otel/config.yaml"]
