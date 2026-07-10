# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BunkerWeb Helm chart — deploys BunkerWeb (open-source WAF/reverse proxy) on Kubernetes. Chart version 1.0.23, app version 1.6.12. Helm 3, API v2.

## Repository Layout

- `charts/bunkerweb/` — the Helm chart (Chart.yaml, values.yaml, templates/)
- `scripts/` — `validate-chart.sh` (chart validation + lint + template rendering tests), `generate-docs.py` (auto-generate docs from values.yaml)
- `examples/` — example values files (all-in-one, minimal, high-availability, logging, secrets)
- `docs/` — user documentation (`values.md` is auto-generated from values.yaml by `generate-docs.py` — never hand-edit it; `README.md` is hand-maintained)

## Common Commands

```bash
# Validate chart (runs helm lint + template rendering with 20+ scenarios)
./scripts/validate-chart.sh

# Lint only
helm lint charts/bunkerweb/

# Render templates with default values
helm template test charts/bunkerweb/

# Render with a specific values file
helm template test charts/bunkerweb/ -f examples/all-in-one.yaml

# Render with value overrides (useful for testing specific template paths)
helm template test charts/bunkerweb/ --set bunkerweb.kind=DaemonSet
helm template test charts/bunkerweb/ --set bunkerweb.kind=StatefulSet
helm template test charts/bunkerweb/ --set bunkerweb.hpa.enabled=true
helm template test charts/bunkerweb/ --set controller.enabled=true

# Generate documentation from values.yaml
python3 scripts/generate-docs.py
```

## Architecture

BunkerWeb deploys as a multi-component system:

- **BunkerWeb** (`bunkerweb-*.yaml`) — the core WAF/reverse proxy. Supports three deployment kinds: Deployment (default), DaemonSet, or StatefulSet. Has both an external service (user traffic) and internal service (inter-component communication).
- **Scheduler** (`scheduler-deployment.yaml`) — manages configuration distribution and coordination across BunkerWeb instances.
- **Controller** (`controller-deployment.yaml`) — watches Kubernetes Ingress and Gateway API resources, translates them to BunkerWeb config. Optional, enabled via `controller.enabled`.
- **UI** (`ui-*.yaml`) — web management interface with syslog sidecar for log collection. Optional, enabled via `ui.enabled`.
- **API** (`api-*.yaml`) — external REST API. Optional, enabled via `api.enabled`.
- **MariaDB/Redis/Prometheus/Grafana** — optional infrastructure components, each with their own deployment + service + PVC templates.

## Key Template Patterns

**`_helpers.tpl`** (829 lines) contains critical helper functions:
- `bunkerweb.databaseUri` — builds the database connection string dynamically (internal MariaDB vs external)
- `bunkerweb.featureEnvs` — generates environment variables from the large `scheduler.features` section in values.yaml. This is the most complex helper and maps feature config to BunkerWeb env vars.
- `bunkerweb.redisEnv` — generates Redis connection env vars with auth support
- `bunkerweb.syslogAddress` — resolves syslog address for UI log forwarding

**Conditional rendering**: Most components are gated by `.Values.<component>.enabled`. BunkerWeb kind selection uses three separate template files (`bunkerweb-deployment.yaml`, `bunkerweb-daemonset.yaml`, `bunkerweb-statefulset.yaml`) each guarded by `if eq .Values.bunkerweb.kind "<Kind>"`.

**Secret management**: The chart supports an `existingSecret` pattern — users reference a pre-created Kubernetes Secret rather than putting credentials in values.yaml. Sensitive values (DB URI, Redis password, admin creds, API keys) are injected via `secretKeyRef`.

## Values Structure

`values.yaml` (1,521 lines) has these major sections:
- **`settings`** — BunkerWeb configuration: `kubernetes` (namespace, ingressClass), `misc` (databaseUri, DNS), `redis`, `ui`, `api`, `scheduler.features` (800+ lines of WAF feature toggles like ModSecurity, antibot, rate limiting, geo-blocking, etc.)
- **`service`** — Kubernetes Service config (type, externalTrafficPolicy)
- **`bunkerweb`** — core component config (kind, replicas, HPA, PDB, resources, probes, volumes, affinity)
- **`scheduler`**, `controller`, `ui`, `api` — per-component deployment config
- **`mariadb`**, `redis`, `prometheus`, `grafana` — optional infrastructure
- **`ingressClass`**, `gatewayClass`** — Kubernetes integration resources
- **`networkPolicy`** — network segmentation (disabled by default)

## CI/CD

Two GitHub Actions workflows:
- `.github/workflows/dev.yml` — on push to `dev` branch (charts/** changes): validate → package → upload to dev Helm repo via SSH
- `.github/workflows/prod.yml` — on push to `main` branch: same pipeline but uploads to production Helm repo

## Development Notes

- Gateway API support is experimental (disabled by default via `gatewayClass.enabled: false`)
- The `KUBERNETES_REVERSE_PROXY_SUFFIX_START` env var is set to `"0"` (string) on the controller to avoid issues with UI/API templates
- When adding new BunkerWeb features, update both `values.yaml` (under `scheduler.features`) and the `bunkerweb.featureEnvs` helper in `_helpers.tpl`
- Always run `./scripts/validate-chart.sh` before committing — it tests template rendering across many configuration combinations
