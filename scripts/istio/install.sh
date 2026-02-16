#!/usr/bin/env bash
set -euo pipefail

# Istio 설치 (istioctl 사용)
# Usage: ./scripts/istio/install.sh
#
# kubeadm 클러스터용:
# - externalIPs로 외부 접근 설정 (LoadBalancer 없음)
# - 기본 EXTERNAL_IP=192.168.45.154 (mini-might, worker node)

ISTIO_VERSION="${ISTIO_VERSION:-1.24.2}"

# 80/443 포트 충돌 해결 함수
fix_port_conflict() {
  echo "=== Checking port 80/443 conflicts ==="

  local conflicts=false
  for port in 80 443; do
    local pid
    pid=$(sudo ss -tlnp "sport = :${port}" 2>/dev/null | grep -oP 'pid=\K[0-9]+' | head -1 || true)

    if [[ -n "$pid" ]]; then
      local proc_name
      proc_name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")

      # svclb (k3s servicelb)는 정상이므로 스킵
      if [[ "$proc_name" == *"svclb"* ]] || [[ "$proc_name" == "lb-port-"* ]]; then
        echo "Port ${port}: OK (k3s servicelb)"
        continue
      fi

      echo "WARNING: Port ${port} is occupied by ${proc_name} (PID: ${pid})"
      echo "Killing process..."
      sudo kill -9 "$pid" 2>/dev/null || true
      conflicts=true
    fi
  done

  if [[ "$conflicts" == "true" ]]; then
    echo "Port conflicts resolved. Restarting svclb pods..."
    kubectl delete pod -n kube-system -l svccontroller.k3s.cattle.io/svcname=istio-ingressgateway 2>/dev/null || true
    sleep 5
  fi

  echo "Port check complete."
}

echo "=== Istio ${ISTIO_VERSION} Install ==="

# istioctl 설치 확인
if ! command -v istioctl &>/dev/null; then
  echo "Installing istioctl..."
  curl -L https://istio.io/downloadIstio | ISTIO_VERSION="$ISTIO_VERSION" sh -
  export PATH="$PWD/istio-${ISTIO_VERSION}/bin:$PATH"
  echo ""
  echo "NOTE: Add to your PATH permanently:"
  echo "  export PATH=\$PATH:$PWD/istio-${ISTIO_VERSION}/bin"
  echo ""
fi

# pre-check
istioctl x precheck

# Istio 설치 (default profile + externalIPs for kubeadm)
EXTERNAL_IP="${EXTERNAL_IP:-192.168.45.154}"  # mini-might (worker node)

# IstioOperator 매니페스트로 설치 (CLI 플래그 버그 회피)
cat <<EOF | istioctl install -y -f -
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: default
  components:
    ingressGateways:
      - name: istio-ingressgateway
        enabled: true
        k8s:
          service:
            externalIPs:
              - ${EXTERNAL_IP}
          hpaSpec:
            minReplicas: 1
            maxReplicas: 3
  values:
    gateways:
      istio-ingressgateway:
        serviceAnnotations:
          metallb.universe.tf/allow-shared-ip: default
EOF

echo "IngressGateway externalIP: ${EXTERNAL_IP}"

# namespace label 설정
kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true

# staging namespace에만 sidecar injection 활성화
kubectl label namespace staging istio-injection=enabled --overwrite 2>/dev/null || true

# dev namespace는 sidecar injection 비활성화
kubectl label namespace dev istio-injection=disabled --overwrite 2>/dev/null || true

# 포트 충돌 확인 (선택사항)
# fix_port_conflict

echo ""
echo "=== Istio Install Complete ==="
echo ""
echo "Verify:"
echo "  istioctl verify-install"
echo "  kubectl get pods -n istio-system"
echo "  sudo ss -tlnp | grep -E ':80|:443'  # port binding check"
echo ""
echo "Istio 설정(Gateway, VirtualService)은 ArgoCD가 helm repo에서 배포합니다."
