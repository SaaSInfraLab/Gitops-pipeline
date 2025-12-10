# Monitoring Stack Application

## Overview

The `monitoring-stack` Argo CD application deploys Prometheus, Grafana, and Alertmanager for cluster and application monitoring.

## What It Deploys

The monitoring stack includes:

### 1. Prometheus Operator
- Manages Prometheus, Alertmanager, and ServiceMonitor CRDs
- Handles configuration and lifecycle management

### 2. Prometheus
- Metrics collection and storage
- Scrapes metrics from pods, services, and ServiceMonitors
- Stores time-series data

### 3. Grafana
- Visualization dashboards
- Pre-configured dashboards for:
  - Kubernetes cluster metrics
  - Node metrics
  - Pod metrics
  - Sample SaaS application metrics
  - Multi-tenant SaaS metrics

### 4. Alertmanager
- Alert routing and notification
- Handles alerts from Prometheus
- Sends notifications via email, Slack, PagerDuty, etc.

## Architecture

```
Monitoring-stack/
├── kustomize/
│   ├── base/
│   │   ├── namespace.yaml
│   │   ├── prometheus-operator.yaml
│   │   ├── prometheus.yaml
│   │   ├── grafana.yaml
│   │   ├── alertmanager.yaml
│   │   └── kustomization.yaml
│   └── overlays/
│       └── dev/
│           └── kustomization.yaml  # Dev environment overlay
└── ...
```

## Deployment

The monitoring stack is managed by Argo CD:

```bash
# View application status
kubectl get application monitoring-stack -n argocd

# Check monitoring pods
kubectl get pods -n monitoring

# Access Grafana (port-forward)
kubectl port-forward svc/dev-grafana -n monitoring 3000:80

# Access Prometheus (port-forward)
kubectl port-forward svc/dev-prometheus -n monitoring 9090:9090
```

## Accessing Dashboards

### Grafana

1. Port-forward the Grafana service:
```bash
kubectl port-forward svc/dev-grafana -n monitoring 3000:80
```

2. Open browser: http://localhost:3000

3. Default credentials:
   - Username: `admin`
   - Password: Check Grafana secret:
   ```bash
   kubectl get secret dev-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d
   ```

### Prometheus

1. Port-forward the Prometheus service:
```bash
kubectl port-forward svc/dev-prometheus -n monitoring 9090:9090
```

2. Open browser: http://localhost:9090

## Pre-configured Dashboards

The monitoring stack includes dashboards in `Monitoring-stack/dashboards/`:
- **kubernetes-cluster.json** - Cluster-wide metrics
- **kubernetes-nodes.json** - Node resource usage
- **kubernetes-pods.json** - Pod metrics
- **sample-saas-app.json** - Application-specific metrics
- **multi-tenant-saas.json** - Multi-tenant metrics

## Alerts

Pre-configured alerts in `Monitoring-stack/alerts/`:
- **cluster-alerts.yaml** - Cluster health alerts
- **node-alerts.yaml** - Node resource alerts
- **pod-alerts.yaml** - Pod failure alerts
- **application-alerts.yaml** - Application-specific alerts

## Service Monitors

ServiceMonitors tell Prometheus which services to scrape:
- **eks-metrics.yaml** - EKS cluster metrics
- **sample-saas-app.yaml** - Application metrics

## Customization

### Add Custom Dashboards

1. Create dashboard JSON in `Monitoring-stack/dashboards/`
2. Import via Grafana UI or use the import script:
```bash
cd Monitoring-stack/scripts
./import-dashboards.sh
```

### Add Custom Alerts

1. Create alert rule YAML in `Monitoring-stack/alerts/`
2. Reference in Prometheus configuration
3. Commit and push - Argo CD will sync

### Configure Alertmanager

Edit `Monitoring-stack/kustomize/base/alertmanager.yaml` to configure:
- Notification receivers (email, Slack, etc.)
- Routing rules
- Grouping and inhibition rules

## Troubleshooting

### Prometheus Not Scraping

1. Check ServiceMonitor resources:
```bash
kubectl get servicemonitors -n monitoring
kubectl describe servicemonitor <name> -n monitoring
```

2. Check Prometheus targets:
   - Access Prometheus UI
   - Go to Status → Targets
   - Check for scrape errors

### Grafana Not Accessible

1. Check Grafana pod status:
```bash
kubectl get pods -n monitoring | grep grafana
kubectl logs -n monitoring <grafana-pod-name>
```

2. Check service:
```bash
kubectl get svc -n monitoring | grep grafana
```

### Alerts Not Firing

1. Check Alertmanager configuration:
```bash
kubectl get secret alertmanager-main -n monitoring -o yaml
```

2. Check Prometheus alert rules:
   - Access Prometheus UI
   - Go to Alerts
   - Check alert status

## Integration with Applications

Applications can expose metrics that Prometheus will scrape:

1. Expose metrics endpoint (e.g., `/metrics`)
2. Create ServiceMonitor resource:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  namespace: platform
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
  - port: http
    path: /metrics
```

3. Prometheus will automatically discover and scrape

## Next Steps

- [ ] Configure Alertmanager notifications (email, Slack)
- [ ] Import custom dashboards
- [ ] Set up ServiceMonitors for your applications
- [ ] Configure alert rules for your use case
- [ ] Set up persistent storage for Prometheus (if needed)

