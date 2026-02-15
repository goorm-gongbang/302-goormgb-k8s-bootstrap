#!/usr/bin/env bash
set -euo pipefail

# k3s 클러스터 완전 초기화 (삭제 후 재설치)
# Usage: ./scripts/k3s/reset.sh

echo "=== k3s Reset ==="
echo ""
echo "This will COMPLETELY RESET the k3s cluster:"
echo "  - Uninstall k3s (all data lost)"
echo "  - Reinstall k3s"
echo "  - Reconfigure kubeconfig"
echo ""
read -rp "Are you sure? [y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
  echo "Aborted."
  exit 0
fi

echo ""
echo "--- Uninstalling k3s ---"
if [[ -f /usr/local/bin/k3s-uninstall.sh ]]; then
  /usr/local/bin/k3s-uninstall.sh
else
  echo "k3s not installed, skipping uninstall"
fi

echo ""
echo "--- Installing k3s ---"
curl -sfL https://get.k3s.io | sh -

echo ""
echo "--- Waiting for k3s to be ready ---"
sleep 5
until kubectl get nodes &>/dev/null; do
  echo "  Waiting for k3s..."
  sleep 2
done

echo ""
echo "--- Configuring kubeconfig ---"
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

echo ""
echo "=== k3s Reset Complete ==="
echo ""
kubectl get nodes
echo ""
echo "Next: make install-all"
