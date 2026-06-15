# Changelog

All notable changes to the BunkerWeb Helm chart are documented here. Versions refer to the
**chart version** (`version` in `charts/bunkerweb/Chart.yaml`); the bundled BunkerWeb app version
is noted per entry. Entries are tagged `[SECURITY]`, `[BUGFIX]`, `[FEATURE]`, `[DEPS]`, `[DOCS]`,
or `[CI]`.

> When cutting a release: bump `version` (and `appVersion` if the app changed) in `Chart.yaml`,
> add a `## vX.Y.Z - YYYY/MM/DD` block here with today's date, then merge to `main`. CI opens a
> draft GitHub release whose notes are extracted from this file; publishing the draft creates the
> `vX.Y.Z` git tag. Entries before `v0.0.5` are folded into an initial-development note because
> those `0.0.x` numbers were reused across the `1.6.0-rc` rollbacks.

## v1.0.21 - 2026/06/15

App version: `1.6.11`.

- [DEPS] upgrade to BunkerWeb 1.6.11.
- [FEATURE] `redis`: native Redis Sentinel support. New `settings.redis` keys `redisSentinelHosts`, `redisSentinelMaster`, `redisSentinelUsername`, `redisSentinelPassword`, plus `redisPort`, `redisDatabase`, `redisSsl`, `redisSslVerify`, and `redisTimeout`. These previously required `extraEnvs`, and on Kubernetes had to be set on `scheduler.extraEnvs` specifically (the scheduler is what configures the BunkerWeb instances) — a common source of confusion (reported via [bunkerity/bunkerweb#3639](https://github.com/bunkerity/bunkerweb/issues/3639)). `REDIS_HOST` is now omitted automatically when Sentinel hosts are set.
- [FEATURE] `existingSecret`: support the new `redis-sentinel-username` and `redis-sentinel-password` keys for Sentinel authentication.
- [DOCS] document Redis Sentinel configuration and the new `settings.redis` keys, and add a Redis Sentinel example (`examples/redis-sentinel.yaml`).
- [CI] add Dependabot configuration for GitHub Actions and pin workflow actions to commit SHAs.

## v1.0.20 - 2026/05/22

App version: `1.6.10`.

- [SECURITY] `api`: gate the ingress and HTTPRoute on `api.enabled`.
- [BUGFIX] `clusterrole`: add the missing `nodes` resource required by instance discovery.
- [BUGFIX] `mariadb`: use `mariadb.resources` instead of `ui.resources`.
- [FEATURE] `controller`: add the `BUNKERWEB_NAMESPACE` environment variable so it can run outside the default `bunkerweb` namespace.
- [DOCS] document the `existingSecret` auth pattern, scope Redis/API upgrade notices to upgrades, fix `generate-docs.py` binding keys, and clarify that monitored namespaces are space-separated.
- [CI] add CodeRabbit integration configuration.
- [CONTRIBUTION] Thank you [anthosz](https://github.com/anthosz) for adding the missing `nodes` ClusterRole resource. (#71)
- [CONTRIBUTION] Thank you [vunguyen-it](https://github.com/vunguyen-it) for fixing the MariaDB deployment to use `mariadb.resources`. (#68)
- [CONTRIBUTION] Thank you [scs-zke](https://github.com/scs-zke) for the namespace documentation fix. (#72)

## v1.0.19 - 2026/05/22

App version: `1.6.10`.

- [SECURITY] `api`: disabled by default and guarded against unauthenticated startup.

## v1.0.18 - 2026/05/22

App version: `1.6.10`.

- [FEATURE] `controller`: add volume support so `sslCaCert` can mount a CA bundle.
- [FEATURE] `redis`: align defaults to 1.6.10 best practices (`volatile-lru` eviction, `redis:8-alpine` image).

## v1.0.17 - 2026/05/21

App version: `1.6.10`.

- [DEPS] upgrade to BunkerWeb 1.6.10: session lifetimes, additional Kubernetes controller knobs, per-backend reverse-proxy controls, request-body limits, and LRU bounds.

## v1.0.16 - 2026/03/23

App version: `1.6.9`.

- [BUGFIX] `mcp`: disable MCP by default and fix the API URL and version handling.
- [FEATURE] `redis`: enable `useConfig`.

## v1.0.15 - 2026/03/13

App version: `1.6.9`.

- [DEPS] upgrade to BunkerWeb 1.6.9: gRPC, database connection pool, NGINX timeouts, ZeroSSL, stream mode, and RBAC support.
- [FEATURE] add experimental MCP support.
- [BUGFIX] make NodePorts adjustable and allow specifying the service used for IP discovery.
- [CONTRIBUTION] Thank you [setiseta](https://github.com/setiseta) for making NodePorts adjustable and letting the IP-discovery service be specified. (#62)

## v1.0.14 - 2026/02/25

App version: `1.6.8`.

- [FEATURE] set `KUBERNETES_REVERSE_PROXY_SUFFIX_START` on the controller to avoid UI/API template clashes.
- [BUGFIX] update readiness/liveness probes.

## v1.0.13 - 2026/02/04

App version: `1.6.8`.

- [DEPS] upgrade to BunkerWeb 1.6.8.
- [FEATURE] experimental Gateway API implementation (disabled by default).
- [FEATURE] add a logrotate cronjob and apply Redis settings directly to BunkerWeb.
- [CONTRIBUTION] Thank you [rayshoo](https://github.com/rayshoo) for the logrotate cronjob, log-cleanup script, and service-logging examples. (#57)

## v1.0.12 - 2026/01/12

App version: `1.6.7`.

- [DEPS] upgrade to BunkerWeb 1.6.7.
- [FEATURE] add the external API component and expose the BunkerWeb API from the StatefulSet.
- [BUGFIX] update image names to comply with Kubernetes v1.34 short-name enforcement.

## v1.0.11 - 2025/12/01

App version: `1.6.6`.

- [FEATURE] add an integrated log-forwarding system with a syslog sidecar.

## v1.0.10 - 2025/11/26

App version: `1.6.6`.

- [DEPS] upgrade to BunkerWeb 1.6.6.

## v1.0.9 - 2025/11/18

App version: `1.6.5`.

- [BUGFIX] fix a wrong condition on the BunkerWeb `enabled` parameter.

## v1.0.8 - 2025/11/18

App version: `1.6.5`.

- [FEATURE] add an enable/disable toggle for BunkerWeb to support sidecar use cases.
- [CONTRIBUTION] Thank you [fca44](https://github.com/fca44) for fixing the missing mapping for the controller `extraEnvs` variable. (#39)

## v1.0.7 - 2025/10/28

App version: `1.6.5`.

- [FEATURE] add HorizontalPodAutoscaler scaling behavior and Kubernetes ignore annotations.

## v1.0.6 - 2025/10/10

App version: `1.6.5`.

- [FEATURE] add HorizontalPodAutoscaler support, a headless service option, and MariaDB custom args.
- [CONTRIBUTION] Thank you [hkraal](https://github.com/hkraal) for exposing port 5000 for the BunkerWeb API. (#37)

## v1.0.5 - 2025/10/07

App version: `1.6.5`.

- [DEPS] upgrade to BunkerWeb 1.6.5.
- [FEATURE] add a Grafana ingress.

## v1.0.4 - 2025/09/09

App version: `1.6.4`.

- [FEATURE] allow mounting custom volumes in BunkerWeb.
- [BUGFIX] fix the PodDisruptionBudget.
- [CI] add the chart validation script and CI.

## v1.0.3 - 2025/09/03

App version: `1.6.4`.

- [FEATURE] add RBAC ingress/status rights and namespace/external-service environment variables for the controller.
- [FEATURE] make Redis persistent and connect using the service's full domain name.
- [CONTRIBUTION] Thank you [OLED1](https://github.com/OLED1) for making Redis persistent and connecting via the service's full domain name. (#29)
- [CONTRIBUTION] Thank you [fca44](https://github.com/fca44) for the controller RBAC ingress/status rights and namespace/external-service environment variables. (#32)
- [CONTRIBUTION] Thank you [makavity](https://github.com/makavity) for fixing the scheduler liveness/readiness probes. (#31)
- [CONTRIBUTION] Thank you [cjprinse](https://github.com/cjprinse) for the MariaDB indentation fix. (#27)

## v1.0.2 - 2025/09/02

App version: `1.6.4`.

- [DEPS] upgrade to BunkerWeb 1.6.4.
- [FEATURE] refine the intra-namespace network policy.

## v1.0.1 - 2025/07/15

App version: `1.6.2`.

- [BUGFIX] fix scheduler probes and Redis host resolution.

## v1.0.0 - 2025/07/04

App version: `1.6.2`.

- [FEATURE] first `1.0.x` chart release.
- [FEATURE] add the StatefulSet kind for BunkerWeb (Deployment and DaemonSet already supported).
- [FEATURE] add liveness/readiness probes and a network policy.

## v0.1.0 - 2025/06/06

App version: `1.6.1`.

- [FEATURE] add the Prometheus + Grafana monitoring stack with Loki/Promtail log aggregation.
- [FEATURE] add the Deployment kind option, optional controller, and custom `BUNKERWEB_INSTANCES`.
- [FEATURE] add optional Redis configuration, topology spread constraints, and per-component resources.

## v0.0.7 - 2025/03/13

App version: `1.6.1`.

- [DEPS] upgrade to BunkerWeb 1.6.1.
- [FEATURE] add custom args to MariaDB.

## v0.0.6 - 2025/03/11

App version: `1.6.0`.

- [BUGFIX] only set `externalTrafficPolicy` when the service is `NodePort` or `LoadBalancer`.

## v0.0.5 - 2025/02/13

App version: `1.6.0`.

- [FEATURE] first stable release: DaemonSet deployment of BunkerWeb with scheduler, controller, UI, MariaDB, and Redis.
- [FEATURE] `existingSecret` support for sensitive values; optional ingress for the web UI.
- [CI] dev/prod pipelines that package the chart and publish it to the BunkerWeb Helm repository.

## v0.0.1 - 2025/01/27

App version: `1.6.0-rc`.

- [FEATURE] initial development releases (`0.0.1`–`0.0.4`, iterating on the BunkerWeb `1.6.0-rc` series): core chart templates, BunkerWeb/scheduler/controller/UI/MariaDB/Redis components, and the groundwork for `existingSecret`-based credentials.
