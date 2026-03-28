#!/usr/bin/env bash
set -euo pipefail

# Cilium CNI 설치 (eBPF 모드, kube-proxy 대체)
# - Hubble 관측성 포함
# - Istio 통합 설정

CILIUM_VERSION="${CILIUM_VERSION:-1.17.3}"
POD_CIDR="${POD_CIDR:-10.244.0.0/16}"
API_SERVER_HOST="${API_SERVER_HOST:-192.168.45.10}"
API_SERVER_PORT="${API_SERVER_PORT:-6443}"
TIMEOUT="${TIMEOUT:-300}"
CP_NODE="${CP_NODE:-mini-gmk}"

echo "=== Installing Cilium CNI (eBPF) ==="
echo "  Version: $CILIUM_VERSION"
echo "  Pod CIDR: $POD_CIDR"
echo "  API Server: $API_SERVER_HOST:$API_SERVER_PORT"
echo "  CP Node: $CP_NODE"
echo "  Timeout: ${TIMEOUT}s"
echo ""

# 이미 Cilium이 정상 동작 중인지 확인
if kubectl get daemonset -n kube-system cilium &>/dev/null; then
  READY=$(kubectl get daemonset -n kube-system cilium -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
  DESIRED=$(kubectl get daemonset -n kube-system cilium -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")
  if [[ "$READY" == "$DESIRED" && "$READY" != "0" ]]; then
    echo "Cilium already installed and healthy ($READY/$DESIRED nodes ready)"
    echo "Skipping installation."
    kubectl -n kube-system exec -it ds/cilium -- cilium status --brief 2>/dev/null || true
    exit 0
  fi
fi

# Calico가 설치되어 있는지 확인
if kubectl get daemonset -n calico-system calico-node &>/dev/null; then
  echo "⚠️  Calico is still installed!"
  echo "Please run uninstall-calico.sh first."
  echo ""
  exit 1
fi

# kube-proxy가 있는지 확인
if kubectl get daemonset -n kube-system kube-proxy &>/dev/null; then
  echo "⚠️  kube-proxy is still running!"
  echo "Cilium will replace kube-proxy. Please run:"
  echo "  kubectl -n kube-system delete ds kube-proxy"
  echo "  kubectl -n kube-system delete cm kube-proxy"
  echo ""
  read -p "Delete kube-proxy now? (y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl -n kube-system delete ds kube-proxy || true
    kubectl -n kube-system delete cm kube-proxy || true
    echo "kube-proxy deleted."
  else
    echo "Continuing without deleting kube-proxy..."
  fi
fi

# Helm repo 추가
echo "=== Adding Cilium Helm repo ==="
helm repo add cilium https://helm.cilium.io 2>/dev/null || true
helm repo update cilium

# Helm으로 Cilium 설치
echo ""
echo "=== Installing Cilium via Helm ==="

helm upgrade --install cilium cilium/cilium \
  --namespace kube-system \
  --version "$CILIUM_VERSION" \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost="$API_SERVER_HOST" \
  --set k8sServicePort="$API_SERVER_PORT" \
  --set bpf.masquerade=true \
  --set bpf.clockProbe=true \
  --set bpf.preallocateMaps=true \
  --set bpf.tproxy=true \
  --set ipam.mode=kubernetes \
  --set ipam.operator.clusterPoolIPv4PodCIDRList="{$POD_CIDR}" \
  --set socketLB.hostNamespaceOnly=true \
  --set cni.exclusive=true \
  --set cni.install=true \
  --set hubble.enabled=true \
  --set hubble.relay.enabled=true \
  --set hubble.relay.replicas=1 \
  --set hubble.ui.enabled=true \
  --set hubble.ui.replicas=1 \
  --set hubble.metrics.enabled="{dns,drop,tcp,flow,icmp,http}" \
  --set hubble.metrics.serviceMonitor.enabled=true \
  --set hubble.metrics.serviceMonitor.labels.release=prometheus-stack \
  --set prometheus.enabled=true \
  --set prometheus.serviceMonitor.enabled=true \
  --set prometheus.serviceMonitor.labels.release=prometheus-stack \
  --set operator.replicas=1 \
  --set operator.nodeSelector."kubernetes\.io/hostname"="$CP_NODE" \
  --set operator.prometheus.enabled=true \
  --set operator.prometheus.serviceMonitor.enabled=true \
  --set operator.prometheus.serviceMonitor.labels.release=prometheus-stack \
  --set tolerations[0].operator=Exists \
  --wait \
  --timeout "${TIMEOUT}s"

# Cilium 상태 확인
echo ""
echo "=== Waiting for Cilium to be ready ==="
kubectl rollout status daemonset/cilium -n kube-system --timeout=${TIMEOUT}s || {
  echo ""
  echo "⚠️  Cilium not fully ready yet."
  echo ""
  echo "Current status:"
  kubectl get pods -n kube-system -l app.kubernetes.io/name=cilium
  echo ""
  echo "Check logs if needed:"
  echo "  kubectl logs -n kube-system -l app.kubernetes.io/name=cilium --tail=50"
}

# Cilium 상태 출력
echo ""
echo "=== Cilium Installation Complete ==="
echo ""
kubectl -n kube-system exec -it ds/cilium -- cilium status --brief 2>/dev/null || {
  echo "Cilium CLI not ready yet. Try manually:"
  echo "  kubectl -n kube-system exec -it ds/cilium -- cilium status"
}

echo ""
echo "Cilium Pods:"
kubectl get pods -n kube-system -l app.kubernetes.io/part-of=cilium

echo ""
echo "Hubble UI:"
kubectl get pods -n kube-system -l app.kubernetes.io/name=hubble-ui

echo ""
echo "=== Next Steps ==="
echo "1. Restart all workload pods to use Cilium CNI:"
echo "   kubectl get deploy -A --no-headers | awk '{print \$1, \$2}' | while read ns name; do"
echo "     kubectl rollout restart deploy/\$name -n \$ns"
echo "   done"
echo ""
echo "2. Test connectivity:"
echo "   kubectl -n kube-system exec -it ds/cilium -- cilium connectivity test"
echo ""
echo "3. Access Hubble UI:"
echo "   kubectl port-forward -n kube-system svc/hubble-ui 12000:80"
echo "   Open http://localhost:12000"
