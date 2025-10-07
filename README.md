# 🩺 hc-pinger

[![Build & Release](https://github.com/iNoels/hc-pinger/actions/workflows/release.yml/badge.svg)](https://github.com/iNoels/hc-pinger/actions/workflows/release.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/inoels/hc-pinger.svg)](https://hub.docker.com/r/inoels/hc-pinger)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**hc-pinger** ist ein leichtgewichtiger Docker-Sidecar, der automatisch den Health-Status laufender Container überwacht  
und deren Status an [healthchecks.io](https://healthchecks.io) sendet – ohne Anpassung an den Ziel-Containern selbst.

---

## 🚀 Features

- 🔍 Liest alle laufenden Container mit Label `hc.uuid`
- ✅ Meldet `healthy` → `https://hc-ping.com/<UUID>`
- ❌ Meldet `unhealthy` → `https://hc-ping.com/<UUID>/fail`
- 🧩 Kein Eingriff in bestehende Services nötig
- 🔄 Kompatibel mit jedem Docker-Setup (Compose, Swarm, lokal, remote)
- 🔒 Nur read-only Zugriff auf Docker-Socket erforderlich
- ⚙️ Konfigurierbar per Environment-Variablen

---

## 🧰 Einsatzszenario

Ideal, wenn du mehrere Container (z. B. Webapps, Dienste, Cronjobs) betreibst  
und deren Zustand **zentral über healthchecks.io** überwachen möchtest.

---

## 🏗️ Installation

### 1️⃣ Mit Docker Compose

```yaml
version: "3.8"

services:
  app:
    image: my-app:latest
    restart: unless-stopped
    labels:
      - hc.uuid=${HC_UUID_APP}
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 5s
      retries: 3

  hc-pinger:
    image: <USERNAME>/hc-pinger:latest
    restart: unless-stopped
    environment:
      - HC_INTERVAL=60
      - HC_LABEL=hc.uuid
      - HC_FAIL_ON_UNHEALTH=true
      - HC_LOG_LEVEL=info
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro