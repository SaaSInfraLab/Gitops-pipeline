# Monitoring Stack

Complete monitoring solution using Prometheus, Grafana, and Alertmanager via the `kube-prometheus-stack` Helm chart.

## Components

- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Alertmanager**: Alert routing and notification
- **Node Exporter**: Node-level metrics (CPU, memory, disk, network)
- **kube-state-metrics**: Kubernetes object metrics

## Popular Dashboards Included

The following Grafana dashboards are automatically imported:

1. **Node Exporter Full** (ID: 1860)
   - Comprehensive node metrics (CPU, memory, disk, network)
   - Most popular Kubernetes monitoring dashboard

2. **Kubernetes Cluster Monitoring** (ID: 6417)
   - Cluster overview, pod status, resource usage
   - Great for overall cluster health

3. **Kubernetes Pod Monitoring** (ID: 6418)
   - Individual pod metrics and resource usage

4. **Kubernetes Deployment Statefulset Daemonset** (ID: 8588)
   - Deployment and workload metrics

## Accessing Grafana

### Get LoadBalancer URL

```bash
kubectl get svc -n monitoring grafana
```

The `EXTERNAL-IP` column shows the LoadBalancer DNS name.

### Get Admin Password

```bash
kubectl get secret -n monitoring grafana -o jsonpath='{.data.admin-password}' | base64 -d && echo
```

Default username: `admin`

### Access Grafana

Open your browser and navigate to:
```
http://<loadbalancer-dns>
```

Login with:
- Username: `admin`
- Password: (from command above)

## Accessing Prometheus

### Port Forward (for testing)

```bash
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
```

Then access at: `http://localhost:9090`

## Monitoring RDS/PostgreSQL

### Option 1: AWS CloudWatch (Recommended)

1. In Grafana, go to **Configuration → Data Sources**
2. Add **CloudWatch** data source
3. Configure AWS credentials (IRSA recommended)
4. Import AWS RDS PostgreSQL dashboard (ID: 12498)

### Option 2: PostgreSQL Exporter

If you want more detailed PostgreSQL metrics:

1. Deploy `postgres_exporter` as a sidecar or separate deployment
2. Create a ServiceMonitor to scrape PostgreSQL metrics
3. Import PostgreSQL dashboard (ID: 9628)

## Application Metrics

ServiceMonitor resources are configured for:
- `sample-saas-app-backend`: Scrapes `/metrics` endpoint from backend pods
- `sample-saas-app-frontend`: Scrapes `/metrics` endpoint from frontend pods

**Note**: Your application needs to expose Prometheus metrics at `/metrics` endpoint for this to work.

### Adding Metrics to Your Application

For Node.js backend, use `prom-client`:

```javascript
const promClient = require('prom-client');

// Create metrics registry
const register = new promClient.Registry();

// Add default metrics (CPU, memory, etc.)
promClient.collectDefaultMetrics({ register });

// Create custom metrics
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

// Expose metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});
```

## Configuration

### Helm Chart Values

Configuration is in `apps/monitoring-stack/values.yaml`:

- **Grafana**: LoadBalancer service, 10Gi storage, popular dashboards
- **Prometheus**: 15-day retention, 20Gi storage, 30s scrape interval
- **Alertmanager**: 5Gi storage, basic resource limits

### Customizing

Edit `apps/monitoring-stack/values.yaml` and ArgoCD will automatically sync the changes.

## Resource Usage

Approximate resource usage:

- **Prometheus**: 1-2 CPU, 2-4Gi memory
- **Grafana**: 250-500m CPU, 256-512Mi memory
- **Alertmanager**: 100-200m CPU, 128-256Mi memory
- **Node Exporter**: Minimal (runs on each node)
- **kube-state-metrics**: 100-200m CPU, 128-256Mi memory

## Troubleshooting

### Grafana Not Accessible

```bash
# Check service
kubectl get svc -n monitoring grafana

# Check pods
kubectl get pods -n monitoring | grep grafana

# Check logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
```

### Prometheus Not Scraping Metrics

```bash
# Check ServiceMonitors
kubectl get servicemonitor -A

# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# Then visit http://localhost:9090/targets
```

### Dashboards Not Showing

1. Check if dashboards are imported:
   ```bash
   kubectl get configmap -n monitoring | grep grafana
   ```

2. Verify dashboard IDs in `values.yaml` are correct

3. Check Grafana logs for import errors

## Additional Resources

- [kube-prometheus-stack Documentation](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Grafana Dashboard Library](https://grafana.com/grafana/dashboards/)
- [Prometheus Documentation](https://prometheus.io/docs/)

