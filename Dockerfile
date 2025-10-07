FROM alpine:3.20

# Pakete: curl für HTTP-Pings, docker-cli fürs Inspect, bash für robustes Scripting
RUN apk add --no-cache curl=8.14.1-r2 docker-cli=26.1.5-r0 bash=5.2.26-r0

# Env-Defaults (können über Compose/.env überschrieben werden)
ENV HC_INTERVAL=60 \
    HC_TIMEOUT=10 \
    HC_RETRY=2 \
    HC_FAIL_ON_UNHEALTH=true \
    HC_LABEL=hc.uuid \
    HC_LOG_LEVEL=info

WORKDIR /
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
