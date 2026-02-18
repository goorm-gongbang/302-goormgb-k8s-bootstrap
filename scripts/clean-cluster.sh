#!/usr/bin/env bash
set -euo pipefail

# kubeadm 클러스터 초기화 (리셋)
# Usage: ./scripts/k3s/clean-cluster.sh
# Note: 스크립트 위치는 k3s 폴더지만 kubeadm용으로 변경됨

echo "=== kubeadm Reset ==="
echo ""
echo "This will COMPLETELY RESET the kubeadm cluster:"
echo "  - kubeadm reset (all data lost)"
echo "  - Remove CNI configs"
echo "  - Clean iptables"
echo ""
read -rp "Are you sure? [y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
  echo "Aborted."
  exit 0
fi

echo ""
echo "--- Running kubeadm reset ---"
sudo kubeadm reset -f

echo ""
echo "--- Cleaning up CNI ---"
sudo rm -rf /etc/cni/net.d
sudo rm -rf /var/lib/cni/

echo ""
echo "--- Removing kubeconfig ---"
rm -f $HOME/.kube/config

echo ""
echo "=== WARNING: iptables 정리는 수동으로 하세요 ==="
echo "원격 접속 중이라면 SSH가 끊길 수 있습니다!"
echo "물리적 접근이 가능할 때만 아래 명령어를 실행하세요:"
echo ""
echo "  sudo iptables -F"
echo "  sudo iptables -t nat -F"
echo "  sudo iptables -t mangle -F"
echo "  sudo iptables -X"
echo ""

echo ""
echo "=== kubeadm Reset Complete ==="
echo ""
echo "To reinitialize:"
echo "  sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=<NODE_IP>"
echo ""
echo "Then install CNI (Calico):"
echo "  kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.3/manifests/tigera-operator.yaml"
echo "  kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.3/manifests/custom-resources.yaml"
