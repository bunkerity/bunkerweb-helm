# BunkerWeb Helm Chart - Deployment Examples

Complete deployment guide for BunkerWeb Helm chart with ready-to-use configurations for different environments.

This directory contains example configurations for common BunkerWeb deployment scenarios.

## Available Examples

### Basic Configurations

- [`bunkerweb-settings-secret.yaml`](bunkerweb-settings-secret.yaml) - Secret with all sensitive variables example
- [`all-in-one.yaml`](all-in-one.yaml) - Full stack configuration for testing
- [`production.yaml`](production.yaml) - Production-ready setup with persistence and external services

## Future Examples to come and open to contribution

- [`high-availability.yaml`](high-availability.yaml) - HA setup with multiple replicas
- [`external-database.yaml`](external-database.yaml) - Using external MariaDB and Redis
- [`security-hardened.yaml`](security-hardened.yaml) - Security-focused configuration
- [`multi-tenant.yaml`](multi-tenant.yaml) - Multi-tenant setup with namespace isolation
- [`edge-deployment.yaml`](edge-deployment.yaml) - Edge/CDN-style deployment

## Available Configurations

### All-in-One Test Configuration
**File:** `examples/all-in-one.yaml`

Complete **test environment** configuration including:
- All integrated components (MariaDB, Redis, Grafana, Prometheus)
- Enhanced security features enabled
- Monitoring and observability stack
- Ready to deploy immediately

**Deployment:**
```bash
helm install bunkerweb-aio ./charts/bunkerweb -f examples/all-in-one.yaml
```

**Access:**
- BunkerWeb UI: `http://localhost:7000` (port-forward required)
- Grafana: `http://localhost:3000` (admin/admin)
- Prometheus: `http://localhost:9090`

---

### Production Configuration (External Services)
**File:** `examples/production.yaml`

**Production-ready** configuration using external services:
- External database (RDS, Cloud SQL, etc.)
- External Redis (ElastiCache, etc.)
- External monitoring (Grafana Cloud, DataDog, etc.)
- SSL/TLS with external certificates
- Maximum security configuration

**Deployment:**
```bash
helm install bunkerweb ./charts/bunkerweb -f examples/production.yaml
```

---

## Configurable Security Features

### Web Application Firewall
- ModSecurity with OWASP CRS
- Security plugins
- Custom rules
- Rule exclusions

### Anti-DDoS Protection
- Request rate limiting per IP/URL
- Connection limiting
- Bad behavior detection
- Automatic IP banning

### IP/Geographic Filtering
- Community blacklists
- Custom whitelists
- Country-based blocking
- Real-time threat intelligence

### SSL/TLS Security
- Automatic Let's Encrypt
- Custom certificates
- Modern protocols only
- Perfect Forward Secrecy

### Monitoring & Analytics
- Prometheus metrics
- Grafana dashboards
- Centralized logging
- Security alerts

---

## Quick Start Guide

### 1. Local Testing
```bash
# Clone the repository
git clone https://github.com/bunkerity/bunkerweb-helm.git
cd bunkerweb-helm

# Deploy test environment
helm install bunkerweb-aio ./charts/bunkerweb -f examples/all-in-one.yaml

# Verify deployment
kubectl get pods -l app.kubernetes.io/instance=bunkerweb-aio

# Check BunkerWeb status
kubectl logs -l bunkerweb.io/component=bunkerweb -f
```

### 2. Production Deployment
```bash
# Copy and customize production config
cp examples/production.yaml my-production-config.yaml

# Edit configuration with your settings
nano my-production-config.yaml

# Deploy to production
helm install bunkerweb ./charts/bunkerweb -f my-production-config.yaml

# Monitor rollout
kubectl rollout status deployment/bunkerweb
```

---

## Template Validation & Testing

### Validate Configuration
```bash
# Dry-run validation
helm template test ./charts/bunkerweb -f examples/all-in-one-test.yaml --dry-run

# Check for syntax errors
helm lint ./charts/bunkerweb

# Validate with Kubernetes
helm template test ./charts/bunkerweb -f examples/all-in-one.yaml | kubectl apply --dry-run=client -f -
```

### Environment Variables Verification
```bash
# Check scheduler environment variables
helm template test ./charts/bunkerweb -f examples/all-in-one.yaml | \
  grep -A 50 "name: scheduler" | grep -E "^\s+- name:|^\s+value:"
```

---

## Configuration Customization

### Common Customizations
```yaml
# Custom resource limits
bunkerweb:
  resources:
    requests:
      cpu: "500m"
      memory: "512Mi"
    limits:
      cpu: "2"
      memory: "2Gi"

# Custom security settings
scheduler:
  features:
    modsecurity:
      useModsecurity: "yes"
      modsecurityCrsVersion: "4"
    rateLimit:
      useLimitReq: "yes"
      limitReqRate: "10r/s"
```

### External Database Configuration
```yaml
# Use external database
mariadb:
  enabled: false

settings:
  databaseUri: "mariadb+pymysql://user:pass@external-db:3306/bunkerweb"
```

### LoadBalancer Configuration
```yaml
# External LoadBalancer
service:
  type: LoadBalancer
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
```

---

## Additional Documentation

- **Values Reference:** [`docs/values.md`](values.md) - Complete configuration reference
- **Examples README:** [`examples/README.md`](../examples/README.md) - Example configurations guide

---

## Use Cases & Scenarios

| Scenario | Configuration File | Description | Best For |
|----------|-------------------|-------------|----------|
| **Testing/Staging** | `examples/all-in-one.yaml` | Complete integrated environment | CI/CD pipelines, QA testing |
| **Production** | `examples/production-external.yaml` | External services + maximum security | Production workloads |

---

## Next Steps

1. **Choose your configuration** based on your environment
2. **Customize values** according to your requirements  
3. **Deploy BunkerWeb** using Helm
4. **Monitor and tune** security settings
5. **Scale as needed** for your traffic patterns

Your BunkerWeb deployment is now **ready for any environment**! 