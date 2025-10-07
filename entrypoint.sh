#!/usr/bin/env bash
set -euo pipefail

log() {
  local level="$1"; shift
  # Levels: debug < info < warn < error
  declare -A rank=( ["debug"]=0 ["info"]=1 ["warn"]=2 ["error"]=3 )
  local want="${rank[${HC_LOG_LEVEL:-info}]:-1}"
  local have="${rank[$level]:-1}"
  if (( have >= want )); then
    echo "$(date -Iseconds) [$level] $*"
  fi
}

INTERVAL="${HC_INTERVAL:-60}"
TIMEOUT="${HC_TIMEOUT:-10}"
RETRY="${HC_RETRY:-2}"
FAIL_ON_UNHEALTH="${HC_FAIL_ON_UNHEALTH:-true}"
LABEL_KEY="${HC_LABEL:-hc.uuid}"

log info "hc-pinger startet (INTERVAL=${INTERVAL}s, LABEL=${LABEL_KEY}, FAIL_ON_UNHEALTH=${FAIL_ON_UNHEALTH})"

# Prüfen, ob Docker-Socket vorhanden ist
if [ ! -S /var/run/docker.sock ]; then
  log error "Docker-Socket /var/run/docker.sock nicht vorhanden. Bitte mounten: -v /var/run/docker.sock:/var/run/docker.sock:ro"
  exit 1
fi

# Einfacher Status-Cache, um z.B. Transitionen zu erkennen (optional nutzbar)
STATE_DIR="/tmp/hc-state"
mkdir -p "$STATE_DIR"

while true; do
  # Alle laufenden Container mit dem Label finden
  mapfile -t IDS < <(docker ps --format '{{.ID}}' --filter "label=${LABEL_KEY}")
  if [ "${#IDS[@]}" -eq 0 ]; then
    log debug "Keine Container mit Label ${LABEL_KEY} gefunden."
    sleep "$INTERVAL"
    continue
  fi

  for ID in "${IDS[@]}"; do
    # Health-Status und UUID auslesen
    STATUS="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$ID" 2>/dev/null || echo "none")"
    UUID="$(docker inspect --format '{{ index .Config.Labels "'"$LABEL_KEY"'" }}' "$ID" 2>/dev/null || true)"
    NAME="$(docker inspect --format '{{.Name}}' "$ID" 2>/dev/null | sed 's#^/##' || echo "$ID")"

    if [ -z "${UUID:-}" ]; then
      log warn "Container $NAME hat kein Label ${LABEL_KEY}; wird uebersprungen."
      continue
    fi

    # Healthchecks.io URL bauen
    URL="https://hc-ping.com/${UUID}"

    # Pingen je nach Status
    if [ "$STATUS" = "healthy" ]; then
      if curl -fsS -m "$TIMEOUT" --retry "$RETRY" "$URL" >/dev/null 2>&1; then
        log info "OK   -> $NAME (healthy)"
      else
        log warn "Ping-Fehler -> $NAME (healthy) an $URL"
      fi
    else
      if [ "${FAIL_ON_UNHEALTH,,}" = "true" ]; then
        if curl -fsS -m "$TIMEOUT" --retry "$RETRY" "$URL/fail" >/dev/null 2>&1; then
          log warn "FAIL -> $NAME (status=$STATUS)"
        else
          log warn "Fail-Ping-Fehler -> $NAME (status=$STATUS) an $URL/fail"
        fi
      else
        log debug "SKIP -> $NAME (status=$STATUS), FAIL_ON_UNHEALTH=false"
      fi
    fi
  done

  sleep "$INTERVAL"
done
