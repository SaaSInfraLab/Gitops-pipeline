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

## Sample App Dashboard

A custom dashboard designed for monitoring the sample SaaS application and cluster resources. This dashboard provides a comprehensive overview of:

- **Namespace-level resource usage** (CPU and Memory)
- **Pod counts per namespace**
- **Node-level metrics** (CPU and Memory)

### Dashboard Panels

#### 1. Memory Usage by Namespace
- **Type:** Bar Gauge
- **Query:**
  ```promql
  sum(container_memory_working_set_bytes{container!="POD",container!=""}) by (namespace) / 1024 / 1024 / 1024
  ```
- **Unit:** GBs
- **Purpose:** Shows total memory consumption per namespace
- **Thresholds:** Green (< 80GB), Red (≥ 80GB)

#### 2. CPU Usage by Namespace
- **Type:** Time Series
- **Query:**
  ```promql
  sum(rate(container_cpu_usage_seconds_total{container!="POD",container!=""}[5m])) by (namespace)
  ```
- **Purpose:** Displays CPU usage trends over time, grouped by namespace
- **Visualization:** Line chart showing historical CPU consumption

#### 3. Pods per Namespace
- **Type:** Gauge
- **Query:**
  ```promql
  count(kube_pod_info) by (namespace)
  ```
- **Purpose:** Shows the number of pods running in each namespace
- **Thresholds:** 
  - Green (< 70%)
  - Orange (70-85%)
  - Red (> 85%)

#### 4. Node CPU Usage
- **Type:** Gauge
- **Query:**
  ```promql
  100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
  ```
- **Purpose:** Displays average CPU usage across all cluster nodes
- **Thresholds:**
  - Green (< 70%)
  - Orange (70-85%)
  - Red (> 85%)

#### 5. Node Memory Usage
- **Type:** Bar Gauge
- **Query:**
  ```promql
  avg((1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100)
  ```
- **Unit:** Percent
- **Purpose:** Shows average memory usage across all cluster nodes
- **Thresholds:** Green (< 80%), Red (≥ 80%)

### Importing the Dashboard

To import this dashboard into Grafana:

1. **Via Grafana UI:**
   - Go to **Dashboards** → **Import**
   - Click **Upload JSON file** and select `sample-app-dashboard.json`
   - Or copy the JSON from the file and paste into the import dialog
   - Select **Prometheus** as the data source
   - Click **Import**

2. **Dashboard File:**
   - Location: `apps/monitoring-stack/sample-app-dashboard.json`
   - Dashboard UID: `af6uxtjticp34d`
   - Dashboard ID: `28`

### Dashboard Features

- **Real-time monitoring:** Updates automatically with 30-minute default time range
- **Color-coded thresholds:** Visual indicators for resource usage levels
- **Namespace grouping:** Easy identification of resource consumption by namespace
- **Multi-metric view:** CPU, memory, and pod counts in a single view
- **Browser timezone:** Automatically adjusts to your local timezone

### Customization

To customize this dashboard:

1. Open the dashboard in Grafana
2. Click the **⚙️ (Settings)** icon
3. Select **JSON Model** to edit the full configuration
4. Or edit individual panels by clicking **Edit** on each panel

You can customize panels directly in Grafana or modify the JSON file and re-import.

## Accessing Grafana

### Get LoadBalancer URL

**Bash/Git Bash:**
```bash
kubectl get svc -n monitoring monitoring-stack-grafana
```

**PowerShell:**
```powershell
kubectl get svc -n monitoring monitoring-stack-grafana
```

The `EXTERNAL-IP` column shows the LoadBalancer DNS name. If it shows `<pending>`, wait a few minutes for AWS to provision the LoadBalancer.

### Get Admin Password

**Bash/Git Bash:**
```bash
kubectl get secret -n monitoring monitoring-stack-grafana -o jsonpath='{.data.admin-password}' | base64 -d && echo
```

**PowerShell:**
```powershell
kubectl get secret -n monitoring monitoring-stack-grafana -o jsonpath='{.data.admin-password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

**Alternative (works in both):**
```bash
kubectl get secret -n monitoring monitoring-stack-grafana -o jsonpath='{.data.admin-password}' | base64 --decode
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

**Bash/Git Bash:**
```bash
# Check service
kubectl get svc -n monitoring monitoring-stack-grafana

# Check pods
kubectl get pods -n monitoring | grep grafana

# Check logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
```

**PowerShell:**
```powershell
# Check service
kubectl get svc -n monitoring monitoring-stack-grafana

# Check pods
kubectl get pods -n monitoring | Select-String "grafana"

# Check logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
```

**If LoadBalancer is not ready, use port-forward:**
```bash
kubectl port-forward -n monitoring svc/monitoring-stack-grafana 3000:80
```
Then access at `http://localhost:3000`

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
   **Bash/Git Bash:**
   ```bash
   kubectl get configmap -n monitoring | grep grafana
   ```
   **PowerShell:**
   ```powershell
   kubectl get configmap -n monitoring | Select-String "grafana"
   ```

2. Verify dashboard IDs in `values.yaml` are correct

3. Check Grafana logs for import errors:
   ```bash
   kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
   ```

## Additional Resources

- [kube-prometheus-stack Documentation](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Grafana Dashboard Library](https://grafana.com/grafana/dashboards/)
- [Prometheus Documentation](https://prometheus.io/docs/)

