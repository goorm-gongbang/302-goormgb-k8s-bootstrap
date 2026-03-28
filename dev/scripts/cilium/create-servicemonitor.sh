#!/usr/bin/env bash
set -euo pipefail

# Cilium Agent ServiceMonitor 생성
# Helm chart에서 자동 생성 안 되는 경우 수동 생성

echo "=== Creating Cilium Agent ServiceMonitor ==="

# Service 생성 (metrics endpoint 노출)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: cilium-agent
  namespace: kube-system
  labels:
    k8s-app: cilium
spec:
  selector:
    k8s-app: cilium
  ports:
    - name: metrics
      port: 9964
      targetPort: 9964
  clusterIP: None
EOF

# ServiceMonitor 생성
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: cilium-agent
  namespace: kube-system
  labels:
    release: prom
spec:
  selector:
    matchLabels:
      k8s-app: cilium
  namespaceSelector:
    matchNames:
      - kube-system
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
EOF

echo ""
echo "=== ServiceMonitor Created ==="
kubectl get servicemonitor -n kube-system | grep cilium
echo ""
echo "Prometheus will start scraping Cilium metrics within 30 seconds."
