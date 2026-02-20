#!/usr/bin/env bash
set -euo pipefail

# etcd 메트릭 스크래핑용 TLS 인증서 Secret 생성
# Prometheus가 etcd 메트릭을 수집하기 위해 필요

NAMESPACE="monitoring"
SECRET_NAME="etcd-client-cert"

echo "=== Creating etcd client certificate secret ==="

# 네임스페이스 확인/생성
kubectl get ns "$NAMESPACE" &>/dev/null || kubectl create ns "$NAMESPACE"

# 기존 secret 있으면 삭제
kubectl delete secret "$SECRET_NAME" -n "$NAMESPACE" 2>/dev/null || true

# etcd 인증서 파일 확인
ETCD_CA="/etc/kubernetes/pki/etcd/ca.crt"
ETCD_CERT="/etc/kubernetes/pki/etcd/healthcheck-client.crt"
ETCD_KEY="/etc/kubernetes/pki/etcd/healthcheck-client.key"

if [[ ! -f "$ETCD_CA" ]] || [[ ! -f "$ETCD_CERT" ]] || [[ ! -f "$ETCD_KEY" ]]; then
  echo "ERROR: etcd certificate files not found!"
  echo "  Expected:"
  echo "    - $ETCD_CA"
  echo "    - $ETCD_CERT"
  echo "    - $ETCD_KEY"
  echo ""
  echo "This script must be run on the control-plane node."
  exit 1
fi

# Secret 생성
kubectl create secret generic "$SECRET_NAME" -n "$NAMESPACE" \
  --from-file=ca.crt="$ETCD_CA" \
  --from-file=client.crt="$ETCD_CERT" \
  --from-file=client.key="$ETCD_KEY"

echo "  Secret '$SECRET_NAME' created in namespace '$NAMESPACE'"

# etcd Endpoints 생성 (Prometheus가 etcd 메트릭을 스크래핑하기 위해 필요)
echo ""
echo "=== Creating etcd endpoints for Prometheus ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$SCRIPT_DIR/etcd-endpoints.yaml"

echo "  Endpoints 'prom-kube-etcd' created in namespace 'kube-system'"
echo ""
echo "=== Done ==="
