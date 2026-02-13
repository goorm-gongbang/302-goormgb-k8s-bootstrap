#!/usr/bin/env bash
set -euo pipefail

# k3s에서 Traefik 비활성화
# Istio IngressGateway가 80/443을 담당하도록 전환
#
# Traefik이 80/443을 점유하면 Istio IngressGateway에 EXTERNAL-IP가 할당 안됨
# 이 스크립트는 k3s server 노드에서 실행해야 함 (sudo 필요)

echo "=== Disable Traefik on k3s ==="
echo ""
echo "This will:"
echo "  1. Add 'disable: traefik' to k3s config"
echo "  2. Remove Traefik HelmChart/pods"
echo "  3. Istio IngressGateway takes over 80/443"
echo ""
read -rp "Continue? [y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
  echo "Aborted."
  exit 0
fi

CONFIG_FILE="/etc/rancher/k3s/config.yaml"

# config.yaml 생성 또는 업데이트 (멱등성 보장)
if [ -f "$CONFIG_FILE" ]; then
  # traefik이 이미 비활성화되어 있는지 확인
  if grep -qE "^\s*-\s*traefik\s*$" "$CONFIG_FILE"; then
    echo "Traefik already disabled in $CONFIG_FILE"
  elif grep -q "^disable:" "$CONFIG_FILE"; then
    # disable: 섹션 존재, traefik 추가
    sudo sed -i '/^disable:/a\  - traefik' "$CONFIG_FILE"
    echo "Added traefik to existing disable list"
  else
    # disable: 섹션 없음, 추가
    echo "" | sudo tee -a "$CONFIG_FILE" > /dev/null
    echo "disable:" | sudo tee -a "$CONFIG_FILE" > /dev/null
    echo "  - traefik" | sudo tee -a "$CONFIG_FILE" > /dev/null
    echo "Added disable section with traefik"
  fi
else
  sudo mkdir -p /etc/rancher/k3s
  cat <<EOF | sudo tee "$CONFIG_FILE" > /dev/null
disable:
  - traefik
EOF
  echo "Created $CONFIG_FILE with traefik disabled"
fi

echo "Updated $CONFIG_FILE"

# Traefik 리소스 제거
echo "Removing Traefik resources..."
kubectl delete helmchart traefik traefik-crd -n kube-system --ignore-not-found
kubectl delete deploy traefik -n kube-system --ignore-not-found
kubectl delete svc traefik -n kube-system --ignore-not-found

# k3s 재시작
echo "Restarting k3s..."
sudo systemctl restart k3s

echo ""
echo "Waiting for k3s to come back..."
sleep 5
kubectl wait --for=condition=Ready node --all --timeout=120s

echo ""
echo "=== Traefik disabled ==="
echo ""
echo "Verify Istio IngressGateway gets EXTERNAL-IP:"
echo "  kubectl get svc -n istio-system istio-ingressgateway"
