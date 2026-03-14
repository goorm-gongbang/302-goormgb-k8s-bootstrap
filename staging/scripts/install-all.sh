#!/usr/bin/env bash
set -euo pipefail

# Staging EKS Bootstrap Script
# EKS 클러스터에 ArgoCD + External Secrets 설치
#
# 사전 조건:
# 1. kubectl이 staging EKS 클러스터에 연결되어 있어야 함
# 2. IRSA가 terraform으로 설정되어 있어야 함 (external-secrets-irsa)
#
# Usage:
#   ./staging/scripts/install-all.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGING_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 환경변수 (필요시 오버라이드)
ARGOCD_URL="${ARGOCD_URL:-https://argocd.staging.playball.one}"
AWS_REGION="${AWS_REGION:-ap-northeast-2}"

echo "=================================================="
echo "  Staging EKS Bootstrap"
echo "=================================================="
echo ""
echo "ArgoCD URL: $ARGOCD_URL"
echo ""

# kubectl 연결 확인
echo "=== Checking kubectl connection ==="
if ! kubectl cluster-info &>/dev/null; then
  echo "ERROR: kubectl not connected to cluster"
  echo "  Run: aws eks update-kubeconfig --name <cluster-name> --profile <profile>"
  exit 1
fi
kubectl get nodes
echo ""

#############################################
# 1. External Secrets Operator (ESO)
#############################################
echo "=== Installing External Secrets Operator ==="

# helm repo
helm repo add external-secrets https://charts.external-secrets.io 2>/dev/null || true
helm repo update

# namespace
kubectl create namespace external-secrets --dry-run=client -o yaml | kubectl apply -f -

# ESO IRSA role ARN (환경변수 또는 자동 감지)
ESO_IRSA_ROLE_ARN="${ESO_IRSA_ROLE_ARN:-}"

if [[ -z "$ESO_IRSA_ROLE_ARN" ]]; then
  echo "NOTE: ESO_IRSA_ROLE_ARN not set."
  echo "  Set it manually or run: export ESO_IRSA_ROLE_ARN=\$(terraform output -raw external_secrets_irsa_role_arn)"
  echo "  Continuing without IRSA - ClusterSecretStore may fail"
fi

# ESO 설치 (IRSA 사용)
HELM_ARGS=(
  upgrade --install external-secrets
  external-secrets/external-secrets
  -n external-secrets
  --set installCRDs=true
  --set serviceAccount.create=true
  --set serviceAccount.name=external-secrets
)

if [[ -n "$ESO_IRSA_ROLE_ARN" ]]; then
  echo "Using IRSA: $ESO_IRSA_ROLE_ARN"
  HELM_ARGS+=(--set "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=$ESO_IRSA_ROLE_ARN")
fi

helm "${HELM_ARGS[@]}" --wait --timeout=5m

# CRD 대기
echo "Waiting for CRDs..."
kubectl wait --for condition=established --timeout=60s \
  crd/clustersecretstores.external-secrets.io \
  crd/externalsecrets.external-secrets.io

echo "ESO installed."
echo ""

#############################################
# 2. ClusterSecretStore (IRSA 기반)
#############################################
echo "=== Creating ClusterSecretStore ==="

# IRSA 사용시 serviceAccountRef로 설정
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: ${AWS_REGION}
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets
            namespace: external-secrets
EOF

# ClusterSecretStore Ready 대기
echo "Waiting for ClusterSecretStore to be ready..."
for i in {1..30}; do
  status=$(kubectl get clustersecretstore aws-secrets-manager -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
  if [[ "$status" == "True" ]]; then
    echo "  ClusterSecretStore ready"
    break
  fi
  reason=$(kubectl get clustersecretstore aws-secrets-manager -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null || echo "Unknown")
  echo "  Waiting... ($i/30) [reason: $reason]"
  sleep 2
done

echo ""

#############################################
# 3. Karpenter (Node Auto Provisioning)
#############################################
echo "=== Installing Karpenter ==="

# namespace
kubectl create namespace karpenter --dry-run=client -o yaml | kubectl apply -f -

# Karpenter 설정 (환경변수로 오버라이드 가능)
KARPENTER_VERSION="${KARPENTER_VERSION:-1.0.8}"
CLUSTER_NAME="${CLUSTER_NAME:-$(kubectl config current-context | cut -d'/' -f2)}"
KARPENTER_ROLE_ARN="${KARPENTER_ROLE_ARN:-}"
KARPENTER_QUEUE_NAME="${KARPENTER_QUEUE_NAME:-}"

# terraform output에서 값 가져오기 시도
if [[ -z "$KARPENTER_ROLE_ARN" ]]; then
  echo "NOTE: KARPENTER_ROLE_ARN not set."
  echo "  Set it manually or run: export KARPENTER_ROLE_ARN=\$(terraform output -raw karpenter_irsa_role_arn)"
fi

if [[ -z "$KARPENTER_QUEUE_NAME" ]]; then
  echo "NOTE: KARPENTER_QUEUE_NAME not set."
  echo "  Set it manually or run: export KARPENTER_QUEUE_NAME=\$(terraform output -raw karpenter_queue_name)"
fi

# Karpenter 설치 (OCI registry, IRSA 사용)
if [[ -n "$KARPENTER_ROLE_ARN" && -n "$KARPENTER_QUEUE_NAME" ]]; then
  helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
    -n karpenter \
    --version "$KARPENTER_VERSION" \
    --set "settings.clusterName=$CLUSTER_NAME" \
    --set "settings.interruptionQueue=$KARPENTER_QUEUE_NAME" \
    --set "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=$KARPENTER_ROLE_ARN" \
    --set controller.resources.requests.cpu=100m \
    --set controller.resources.requests.memory=256Mi \
    --set controller.resources.limits.cpu=500m \
    --set controller.resources.limits.memory=512Mi \
    --wait --timeout=5m

  echo "Karpenter installed."

  # Karpenter CRD 대기
  echo "Waiting for Karpenter CRDs..."
  kubectl wait --for condition=established --timeout=60s \
    crd/nodepools.karpenter.sh \
    crd/ec2nodeclasses.karpenter.k8s.aws 2>/dev/null || true

  # NodePool 및 EC2NodeClass 배포
  KARPENTER_NODE_ROLE="${KARPENTER_NODE_ROLE:-}"
  if [[ -z "$KARPENTER_NODE_ROLE" ]]; then
    echo "NOTE: KARPENTER_NODE_ROLE not set."
    echo "  Set it manually or run: export KARPENTER_NODE_ROLE=\$(terraform output -raw karpenter_node_role_name)"
  fi

  if [[ -f "$STAGING_DIR/karpenter/nodepool.yaml" && -n "$KARPENTER_NODE_ROLE" ]]; then
    echo "Deploying Karpenter NodePool and EC2NodeClass..."
    # 환경변수 치환 후 적용
    export CLUSTER_NAME KARPENTER_NODE_ROLE
    for f in "$STAGING_DIR/karpenter/"*.yaml; do
      envsubst < "$f" | kubectl apply -f -
    done
    echo "Karpenter NodePool deployed."
  else
    echo "NOTE: Karpenter manifests not deployed."
    echo "  Missing: KARPENTER_NODE_ROLE or manifests at $STAGING_DIR/karpenter/"
  fi
else
  echo "SKIPPING Karpenter installation - missing required environment variables"
  echo "  Required: KARPENTER_ROLE_ARN, KARPENTER_QUEUE_NAME"
fi

echo ""

#############################################
# 4. ArgoCD
#############################################
echo "=== Installing ArgoCD ==="

# helm repo
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update

# namespace
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Webhook secret (optional)
WEBHOOK_SECRET=""
if command -v aws &>/dev/null; then
  WEBHOOK_SECRET=$(aws secretsmanager get-secret-value \
    --secret-id staging/argocd/webhook-github \
    --query 'SecretString' --output text 2>/dev/null || echo "")
fi

# ArgoCD 설치
HELM_ARGS=(
  upgrade --install argocd argo/argo-cd
  -n argocd
  --create-namespace
  --set 'server.extraArgs={--insecure}'
  --set "configs.cm.url=$ARGOCD_URL"
)

if [[ -n "$WEBHOOK_SECRET" ]]; then
  echo "GitHub webhook secret found"
  HELM_ARGS+=(--set "configs.secret.extra.webhook\.github\.secret=$WEBHOOK_SECRET")
fi

helm "${HELM_ARGS[@]}" --wait --timeout=5m

# ArgoCD CRD 대기
echo "Waiting for ArgoCD CRDs..."
kubectl wait --for=condition=Established crd/applications.argoproj.io --timeout=60s

echo "ArgoCD installed."
echo ""

#############################################
# 5. GitHub SSH Key (ExternalSecret)
#############################################
echo "=== Setting up GitHub SSH Key ==="

kubectl apply -f "$STAGING_DIR/argo-init/external-secret-github.yaml"

# Secret 생성 대기
echo "Waiting for repo-goormgb-helm secret..."
for i in {1..30}; do
  if kubectl get secret repo-goormgb-helm -n argocd &>/dev/null; then
    if kubectl get secret repo-goormgb-helm -n argocd -o jsonpath='{.data.sshPrivateKey}' 2>/dev/null | grep -q "."; then
      echo "  GitHub SSH secret ready"
      break
    fi
  fi
  es_status=$(kubectl get externalsecret repo-goormgb-helm -n argocd -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null || echo "")
  echo "  Waiting... ($i/30) [status: $es_status]"
  sleep 2
done

if ! kubectl get secret repo-goormgb-helm -n argocd &>/dev/null; then
  echo ""
  echo "ERROR: GitHub SSH secret not created!"
  echo ""
  echo "Debug:"
  kubectl get clustersecretstore aws-secrets-manager -o yaml 2>/dev/null | grep -A10 "status:" || true
  kubectl get externalsecret repo-goormgb-helm -n argocd -o yaml 2>/dev/null | grep -A10 "status:" || true
  echo ""
  echo "Check:"
  echo "  aws secretsmanager get-secret-value --secret-id staging/argocd/github-ssh --profile ktcloud-team4"
  exit 1
fi

echo ""

#############################################
# 6. Root Application
#############################################
echo "=== Deploying Root Application ==="

kubectl apply -f "$STAGING_DIR/argo-init/root-application.yaml"

echo "Waiting for root-staging app..."
sleep 5

# Refresh trigger
kubectl annotate application root-staging -n argocd argocd.argoproj.io/refresh=normal --overwrite 2>/dev/null || true

# App 상태 확인
for i in {1..12}; do
  health=$(kubectl get application root-staging -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "")
  sync=$(kubectl get application root-staging -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "")
  echo "  Checking... ($i/12) [sync=$sync, health=$health]"
  if [[ "$sync" == "Synced" ]]; then
    break
  fi
  sleep 10
done

echo ""

#############################################
# Done
#############################################
echo "=================================================="
echo "  Bootstrap Complete!"
echo "=================================================="
echo ""
echo "ArgoCD UI: $ARGOCD_URL"
echo ""
echo "Admin password:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"
echo ""
echo "Applications:"
kubectl get app -n argocd 2>/dev/null || echo "  (none yet, wait for sync)"
echo ""
