#!/usr/bin/env bash
set -euo pipefail

# kubeseal + yq 설치 (없으면 skip)

ARCH=$(dpkg --print-architecture 2>/dev/null || echo "arm64")

if ! command -v kubeseal &>/dev/null; then
  echo "Installing kubeseal..."
  KUBESEAL_VERSION="0.29.0"
  wget -q "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-${ARCH}.tar.gz" -O /tmp/kubeseal.tar.gz
  tar xzf /tmp/kubeseal.tar.gz -C /tmp kubeseal
  sudo install /tmp/kubeseal /usr/local/bin/kubeseal
  rm -f /tmp/kubeseal.tar.gz /tmp/kubeseal
  echo "  kubeseal $(kubeseal --version) installed"
else
  echo "  kubeseal already installed: $(kubeseal --version)"
fi

if ! command -v yq &>/dev/null; then
  echo "Installing yq..."
  sudo wget -q "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${ARCH}" -O /usr/local/bin/yq
  sudo chmod +x /usr/local/bin/yq
  echo "  yq $(yq --version) installed"
else
  echo "  yq already installed: $(yq --version)"
fi
