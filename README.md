# BunkerWeb Kubernetes Helm Chart

![Version](https://img.shields.io/badge/version-1.0.24-blue)
![AppVersion](https://img.shields.io/badge/app%20version-1.6.13-green)

Official [Helm chart](https://helm.sh/docs/) to deploy [BunkerWeb](https://www.bunkerweb.io/?utm_campaign=self&utm_source=github) on Kubernetes - A next-generation, open-source **web application firewall (WAF)** and reverse proxy.

## Features

- **Security First**: Advanced threat protection with automatic rule updates
- **High Availability**: Support for DaemonSet and Deployment modes
- **Monitoring**: Built-in Prometheus metrics and Grafana dashboards
- **Management UI**: Web interface for configuration and monitoring
- **AI Integration**: MCP server for AI assistants (Claude Code, etc.)
- **Auto-scaling**: Kubernetes-native scaling capabilities
- **Secret Management**: Integration with Kubernetes secrets

## Prerequisites

- Kubernetes 1.19+
- Helm 3.8+
- PV provisioner support in the underlying infrastructure (for persistence)
- Kubernetes Gateway API CRDs installed (required for Gateway API support, see the [Gateway API install guide](https://gateway-api.sigs.k8s.io/guides/getting-started/#installing-gateway-api))

**Important**: Please first refer to the [BunkerWeb documentation](https://docs.bunkerweb.io/latest/?utm_campaign=self&utm_source=github), particularly the [Kubernetes integration](https://docs.bunkerweb.io/latest/integrations/?utm_campaign=self&utm_source=bunkerwebio#kubernetes) section.

## Installation

### Add Helm Repository

```bash
helm repo add bunkerweb https://repo.bunkerweb.io/charts
helm repo update
```

### Install Chart

```bash
# Install with default values
helm install mybunkerweb bunkerweb/bunkerweb

# Install with custom values
helm install mybunkerweb bunkerweb/bunkerweb -f myvalues.yaml

# Install in specific namespace
helm install mybunkerweb bunkerweb/bunkerweb -n bunkerweb --create-namespace
```

> **Need help with configuration?** Check out our [Configuration Guide](docs/values.md) for detailed examples and best practices.

## Architecture Components

| Component | Description | Default State |
|-----------|-------------|---------------|
| **BunkerWeb** | Main WAF/reverse proxy | Required |
| **Scheduler** | Configuration management | Required |
| **Controller** | Kubernetes integration | Enabled |
| **UI** | Web management interface | Enabled |
| **API** | External REST API for automation | Enabled |
| **MCP** | Model Context Protocol server for AI assistants | Enabled |
| **MariaDB** | Database backend | Enabled |
| **Redis** | Caching and persistence | Enabled |
| **Prometheus** | Metrics collection | Disabled |
| **Grafana** | Monitoring dashboards | Disabled |

## Configuration 

For detailed configuration options, see our comprehensive documentation:

**[Values Guide](docs/values.md)** - Complete user guide  
**[Values Reference](docs/values.md)** - Quick technical reference  
**[values.yaml](charts/bunkerweb/values.yaml)** - Source configuration file

**Controller selection**: The controller runs as either a `GatewayController` or an `IngressController`, never both. If both are configured, `GatewayController` takes priority.

### Configuration Topics

| Topic | Example | Reference |
|-------|---------|-----------|
| Security settings | [`examples/all-in-one.yaml`](examples/all-in-one.yaml) | [docs/values.md#settings](docs/values.md#settings) |
| Kubernetes integration | [`examples/all-in-one.yaml`](examples/all-in-one.yaml) | [docs/values.md#settings](docs/values.md#settings) |
| High availability | [`examples/high-availability.yaml`](examples/high-availability.yaml) | [docs/values.md#bunkerweb](docs/values.md#bunkerweb), [#service](docs/values.md#service) |
| MCP server | [`examples/mcp-integration.yaml`](examples/mcp-integration.yaml) | [docs/values.md#mcp](docs/values.md#mcp) |
| Secret management | [`examples/bunkerweb-secret.yaml`](examples/bunkerweb-secret.yaml) | [docs/values.md#settings](docs/values.md#settings) |
| Persistence | [`examples/high-availability.yaml`](examples/high-availability.yaml) | [docs/values.md#mariadb](docs/values.md#mariadb), [#redis](docs/values.md#redis), [#grafana](docs/values.md#grafana), [#prometheus](docs/values.md#prometheus), [#ui](docs/values.md#ui) |
| Monitoring | [`examples/all-in-one.yaml`](examples/all-in-one.yaml) | [docs/values.md#prometheus](docs/values.md#prometheus), [#grafana](docs/values.md#grafana) |

> **Security note**: The MCP server has no built-in authentication for the `/mcp` endpoint. Always use IP whitelisting or network policies to restrict access.

## Monitoring and Observability

### Custom Dashboards

The chart includes pre-configured Grafana dashboards for:
- BunkerWeb metrics and performance
- Request analytics and threat detection
- System health and resource usage

## Security Considerations

1. **Change Default Passwords**: Always set custom passwords for UI and database
2. **Use Secrets**: Store sensitive data in Kubernetes secrets
3. **Network Policies**: Enable network policies for production environments
4. **Resource Limits**: Set appropriate CPU/memory limits
5. **Pod Security**: Review and adjust security contexts
6. **MCP Access Control**: Always configure IP whitelisting when exposing the MCP server

## Troubleshooting

### Common Issues

**BunkerWeb pods not starting:**
```bash
kubectl logs -l app.kubernetes.io/name=bunkerweb -n bunkerweb
```

**Database connection issues:**
```bash
kubectl get pods -n bunkerweb
kubectl describe pod mariadb-<pod-name> -n bunkerweb
```

**Ingress not working:**
```bash
kubectl get ingress -n bunkerweb
kubectl describe ingressclass bunkerweb
```

### Health Checks

All components include health checks:
- Liveness probes for automatic restart
- Readiness probes for traffic routing
- Custom healthcheck scripts

## Upgrading

```bash
# Update repository
helm repo update bunkerweb

# Check available versions
helm search repo bunkerweb/bunkerweb --versions

# Upgrade to latest version
helm upgrade mybunkerweb bunkerweb/bunkerweb

# Upgrade with new values
helm upgrade mybunkerweb bunkerweb/bunkerweb -f new-values.yaml
```

### Version-specific notes

- **> 1.0.24**: When `settings.existingSecret` is set, the BunkerWeb Pro license should be provided via the secret's `pro-license-key` key (a plain `scheduler.proLicenseKey` value is ignored). The same now applies to the optional feature secrets (`zerossl-api-key`, `custom-ssl-key`, `sessions-secret`, `auth-basic-password`, `darkvisitors-token`, `crowdsec-api-key`).
  - **Upgrade note:** these secret keys are `optional`, and when `settings.existingSecret` is set it takes precedence over the matching plaintext values (`scheduler.features.sessions.sessionsSecret`, `scheduler.features.authBasic.authBasicPassword`, etc.). If you previously combined `settings.existingSecret` (for the database/Redis) with **plaintext** feature values, those plaintext values are now ignored — add the corresponding keys to your existing secret, or the feature will lose its credential silently.

## Uninstallation

```bash
# Uninstall release
helm uninstall mybunkerweb -n bunkerweb

# Remove namespace (optional)
kubectl delete namespace bunkerweb
```

**Note**: PVCs are not automatically deleted and must be removed manually if needed.


### Key Configuration Areas

- **Global Settings**: Common configuration across all components
- **BunkerWeb**: Main reverse proxy configuration
- **UI**: Web interface settings
- **API**: External REST API for automation and integrations
- **MCP**: AI assistant integration (Claude Code, etc.)
- **Database**: MariaDB configuration
- **Monitoring**: Prometheus and Grafana setup
- **Security**: Network policies and access control

### Quick Configuration Examples

See [`examples/`](examples/) directory for complete configuration examples.

## Support

- [Documentation](https://docs.bunkerweb.io/)
- [GitHub Issues](https://github.com/bunkerity/bunkerweb/issues)
- [Community Forum](https://github.com/bunkerity/bunkerweb/discussions)

## License

This Helm chart is licensed under the same terms as BunkerWeb itself.
