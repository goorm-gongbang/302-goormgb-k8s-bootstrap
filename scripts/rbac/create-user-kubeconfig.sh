#!/usr/bin/env bash
set -euo pipefail

# 팀원용 kubeconfig 생성 스크립트
# k3s server 노드에서 실행 (sudo 필요)
#
# Usage: ./create-user-kubeconfig.sh <username>
# Example: ./create-user-kubeconfig.sh grgb-wonny
#
# 결과: ./<username>.kubeconfig 파일 생성

USERNAME="${1:-}"

if [[ -z "$USERNAME" ]]; then
  echo "Usage: $0 <username>"
  echo "Example: $0 grgb-wonny"
  exit 1
fi

# k3s CA 위치
# server-ca: API 서버 인증서 검증용 (kubeconfig의 certificate-authority-data)
# client-ca: 클라이언트 인증서 서명용
K3S_SERVER_CA="/var/lib/rancher/k3s/server/tls/server-ca.crt"
K3S_CLIENT_CA_KEY="/var/lib/rancher/k3s/server/tls/client-ca.key"
K3S_CLIENT_CA_CERT="/var/lib/rancher/k3s/server/tls/client-ca.crt"

# CP 노드 실제 IP 가져오기 (VPN 접속용)
# 127.0.0.1이 아닌 실제 내부 IP 사용
CP_IP=$(hostname -I | awk '{print $1}')
K3S_SERVER_URL="https://${CP_IP}:6443"

echo "Using server: $K3S_SERVER_URL"

WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

echo "=== Creating kubeconfig for: $USERNAME ==="

# 1. 개인 키 생성
openssl genrsa -out "$WORK_DIR/${USERNAME}.key" 2048

# 2. CSR 생성 (CN = username)
openssl req -new \
  -key "$WORK_DIR/${USERNAME}.key" \
  -out "$WORK_DIR/${USERNAME}.csr" \
  -subj "/CN=${USERNAME}/O=team-viewer"

# 3. client-ca로 서명 (30일 유효)
sudo openssl x509 -req \
  -in "$WORK_DIR/${USERNAME}.csr" \
  -CA "$K3S_CLIENT_CA_CERT" \
  -CAkey "$K3S_CLIENT_CA_KEY" \
  -CAcreateserial \
  -out "$WORK_DIR/${USERNAME}.crt" \
  -days 30

# 4. kubeconfig 생성
cat > "${USERNAME}.kubeconfig" <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $(sudo cat "$K3S_SERVER_CA" | base64 | tr -d '\n')
    server: ${K3S_SERVER_URL}
  name: k3s
contexts:
- context:
    cluster: k3s
    user: ${USERNAME}
  name: ${USERNAME}@k3s
current-context: ${USERNAME}@k3s
users:
- name: ${USERNAME}
  user:
    client-certificate-data: $(cat "$WORK_DIR/${USERNAME}.crt" | base64 | tr -d '\n')
    client-key-data: $(cat "$WORK_DIR/${USERNAME}.key" | base64 | tr -d '\n')
EOF

echo ""
echo "=== Created: ${USERNAME}.kubeconfig ==="
echo ""
echo "팀원에게 전달:"
echo "  1. ${USERNAME}.kubeconfig 파일 전송"
echo "  2. 팀원 PC에서: export KUBECONFIG=~/${USERNAME}.kubeconfig"
echo "  3. 또는: cp ${USERNAME}.kubeconfig ~/.kube/config"
echo ""
echo "유효기간: 30일 (갱신 필요)"
