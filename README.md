# BunkerWeb Kubernetes Helm Chart

![Version](https://img.shields.io/badge/version-1.0.2-blue)
![AppVersion](https://img.shields.io/badge/app%20version-1.6.4-green)

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
**[Values Reference](docs/values-reference.md)** - Quick technical reference  
**[values.yaml](charts/bunkerweb/values.yaml)** - Source configuration file

### Security Settings

```yaml
settings:
  misc:
    # Custom DNS resolvers
    dnsResolvers: "1.1.1.1 8.8.8.8"
    # API whitelist for internal access
    apiWhitelistIp: "127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16"
```

### Kubernetes Integration

**Controller selection**: The controller runs as either a `GatewayController` or an `IngressController`, never both. If both are configured, `GatewayController` takes priority.

```yaml
settings:
  kubernetes:
    # Namespaces to monitor (empty = all)
    namespaces: "default,production"
    # Custom ingress class
    ingressClass: "bunkerweb"
    # Cluster domain
    domainName: "cluster.local"
```

### High Availability Setup

```yaml
bunkerweb:
  kind: DaemonSet  # or "Deployment"
  replicas: 3      # Only for Deployment mode
  pdb:
    create: true
    minAvailable: 1

service:
  type: LoadBalancer
  externalTrafficPolicy: Local
```

### MCP Server (AI Assistant Integration)

The MCP (Model Context Protocol) server enables AI assistants like Claude Code to manage BunkerWeb configuration.

```yaml
mcp:
  enabled: true
  # API credentials (must match settings.api configuration)
  secrets:
    bunkerwebApiToken: "your-api-token"

  # Expose via Ingress (legacy)
  ingress:
    enabled: true
    serverName: "mcp.example.com"
    annotations:
      bunkerweb.io/USE_WHITELIST: "yes"
      bunkerweb.io/WHITELIST_IP: "YOUR_IP/32"

  # Or expose via Gateway API (modern)
  httpRoutes:
    enabled: true
    serverName: "mcp.example.com"
    extraAnnotations:
      bunkerweb.io/USE_WHITELIST: "yes"
      bunkerweb.io/WHITELIST_IP: "YOUR_IP/32"
```

> **Security Warning**: The MCP server has no built-in authentication for the `/mcp` endpoint. Always use IP whitelisting or network policies to restrict access.

### Secret Management

```yaml
settings:
  # Use existing secret for sensitive values
  existingSecret: "bunkerweb-secrets"
  # Or configure inline (less secure)
  ui:
    adminUsername: "admin"
    adminPassword: "secure-password"
```

## Persistence

### Storage Requirements

| Component | Default Size | Purpose |
|-----------|-------------|---------|
| MariaDB | 5Gi | Configuration and logs |
| Redis | 1Gi | Cache and banned IPs |
| UI Logs | 5Gi | Access and error logs |
| Prometheus | 8Gi | Metrics storage |
| Grafana | 5Gi | Dashboards and config |

### Custom Storage Classes

```yaml
mariadb:
  persistence:
    storageClass: "fast-ssd"
    size: 20Gi

redis:
  persistence:
    storageClass: "standard"
    size: 5Gi
```

## Monitoring and Observability

### Enable Monitoring Stack

```yaml
scheduler:
  proLicenceKey: your-bunkerweb-licence-key
  usePrometheusExporter: true

prometheus:
  enabled: true
  persistence:
    enabled: true
    size: 20Gi

grafana:
  enabled: true
  adminUser: admin
  adminPassword: "your-secure-password"
  ingress:
    enabled: true
    hosts:
      - host: grafana.example.com
```

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
