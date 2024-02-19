#!/usr/bin/env -S just --justfile
set export

set shell := ["bash", "-uc"]

# OS specific variables          
copy                             := if os() == "linux" { "xsel -ib"} else { "pbcopy" }
browse                           := if os() == "linux" { "xdg-open "} else { "open" }

# Other variables
provider_kubernetes_manifest := justfile_directory() + "/provider-kubernetes.yaml"
providerconfig_manifest := justfile_directory() + "/providerconfig.yaml"
crossplane_monitoring_manifest := justfile_directory() + "/prom-pod-monitors.yaml"

sync_helm_repos:
  @helm repo add crossplane-stable https://charts.crossplane.io/stable
  @helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  @helm repo update

install_crossplane: sync_helm_repos
  @helm upgrade --install crossplane crossplane-stable/crossplane -n crossplane-system \
  --set metrics.enabled=true \
  --create-namespace --wait

install_provider_kubernetes:
  @kubectl apply -f {{provider_kubernetes_manifest}}
  @kubectl wait provider.pkg provider-kubernetes --for condition=healthy --timeout 2m
  @kubectl apply -f {{providerconfig_manifest}}

setup_crossplane_monitoring:
  @kubectl apply -f {{crossplane_monitoring_manifest}}

# deploy observability
setup_monitoring: sync_helm_repos
  @helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n prometheus \
   --set namespaceOverride=prometheus \
   --set grafana.namespaceOverride=prometheus \
   --set grafana.defaultDashboardsEnabled=true \
   --set kube-state-metrics.namespaceOverride=prometheus \
   --set prometheus-node-exporter.namespaceOverride=prometheus \
   --create-namespace --wait
  just _enable_prometheus_admin_api

setup:
  just setup_monitoring
  just install_crossplane
  just install_provider_kubernetes
  just setup_crossplane_monitoring

create_x_objects start='1' end='3':
  #!/usr/bin/env bash
  echo "Creating objects from $start to $end"
  for ((i=$start; i<=$end; i++)); do
  cat <<EOF | kubectl apply -f -
    apiVersion: kubernetes.crossplane.io/v1alpha2
    kind: Object
    metadata:
      name: object-$i
    spec:
      forProvider:
        manifest:
          apiVersion: v1
          kind: ConfigMap
          metadata:
            namespace: default
            labels:
              example: "true"
          data:
            key: "value-$i"
  EOF
  done

# HELPER RECEPIES {{{
# enable prometheus admin api
_enable_prometheus_admin_api:
  @kubectl -n prometheus patch prometheus kube-prometheus-stack-prometheus --type merge --patch '{"spec":{"enableAdminAPI":true}}'

# port forward grafana, user: admin, pw: prom-operator
help_launch_grafana:
  nohup {{browse}} http://localhost:3001 >/dev/null 2>&1
  kubectl port-forward -n prometheus svc/kube-prometheus-stack-grafana 3001:80

# port forward prometheus
help_launch_prometheus:
  nohup {{browse}} http://localhost:9090 >/dev/null 2>&1
  kubectl port-forward -n prometheus svc/kube-prometheus-stack-prometheus 9090:9090