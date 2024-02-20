# Provider Kubernetes Scalability

1. Create a fresh k8s cluster
2. Setup the test environment

```bash
just setup
```

3. Create k8s objects.

For example, to create 1000 objects:

```bash
just create_x_objects 1 1000
```

4. Launch the monitoring dashboards

```bash
just help_launch_grafana
# in another terminal
just help_launch_prometheus
```

5. Import the grafana-dashboard.json to the grafana dashboard.