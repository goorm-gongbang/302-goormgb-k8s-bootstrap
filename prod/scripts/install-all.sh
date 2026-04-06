#!/usr/bin/env bash
set -euo pipefail

# Prod EKS Bootstrap Script
# EKS 클러스터에 ArgoCD + External Secrets 설치
#
# 사전 조건:
# 1. kubectl이 prod EKS 클러스터에 연결되어 있어야 함
# 2. IRSA가 terraform으로 설정되어 있어야 함 (external-secrets-irsa)
#
# Usage:
#   ./prod/scripts/install-all.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGING_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 환경변수 (필요시 오버라이드)
ARGOCD_URL="${ARGOCD_URL:-https://argocd.playball.one}"
AWS_REGION="${AWS_REGION:-ap-northeast-2}"

echo "=================================================="
echo "  Prod EKS Bootstrap"
echo "=================================================="
echo ""
echo "ArgoCD URL: $ARGOCD_URL"
echo ""

# kubectl 연결 확인
echo "=== kubectl 연결 확인 중 ==="
if ! kubectl cluster-info &>/dev/null; then
  echo "오류: kubectl이 클러스터에 연결되어 있지 않습니다"
  echo "  실행: aws eks update-kubeconfig --name <clulster-name> --profile <profile>"
  exit 1
fi
kubectl get nodes
echo ""

#############################################
# 1. External Secrets Operator (ESO)
#############################################
echo "=== External Secrets Operator 설치 중 ==="

# helm repo
helm repo add external-secrets https://charts.external-secrets.io 2>/dev/null || true
helm repo update

# namespace
kubectl create namespace external-secrets --dry-run=client -o yaml | kubectl apply -f -

# ESO IRSA role ARN (환경변수 또는 terraform에서 자동 감지)
ESO_IRSA_ROLE_ARN="${ESO_IRSA_ROLE_ARN:-}"
TERRAFORM_DIR="${TERRAFORM_DIR:-$HOME/01_KDT/301-goormgb-terraform/environments/prod}"

if [[ -z "$ESO_IRSA_ROLE_ARN" ]] && [[ -d "$TERRAFORM_DIR" ]]; then
  echo "terraform에서 ESO IRSA role ARN을 감지하는 중..."
  ESO_IRSA_ROLE_ARN=$(cd "$TERRAFORM_DIR" && terraform output -raw eks_external_secrets_irsa_role_arn 2>/dev/null || echo "")
fi

if [[ -z "$ESO_IRSA_ROLE_ARN" ]]; then
  echo "경고: ESO_IRSA_ROLE_ARN이 설정되지 않았으며 자동 감지할 수 없습니다."
  echo "  수동으로 설정하세요: export ESO_IRSA_ROLE_ARN=<role-arn>"
  echo "  IRSA 없이 계속 진행합니다 - ClusterSecretStore가 실패할 수 있습니다"
fi

# ESO 설치 (IRSA 사용)
# ArgoCD가 이미 external-secrets를 관리 중인 경우 helm upgrade는 SSA 충돌이 발생하므로 건너뜀
if helm status external-secrets -n external-secrets &>/dev/null; then
  echo "  external-secrets가 이미 설치되어 있습니다 (재설치 건너뜀)"
  echo "  ※ 설정 변경이 필요하면 ArgoCD에서 external-secrets 앱을 Sync하세요"
else
  HELM_ARGS=(
    upgrade --install external-secrets
    external-secrets/external-secrets
    -n external-secrets
    --set installCRDs=true
    --set serviceAccount.create=true
    --set serviceAccount.name=external-secrets
  )

  if [[ -n "$ESO_IRSA_ROLE_ARN" ]]; then
    echo "IRSA 사용 중: $ESO_IRSA_ROLE_ARN"
    HELM_ARGS+=(--set "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=$ESO_IRSA_ROLE_ARN")
  fi

  helm "${HELM_ARGS[@]}" --wait --timeout=5m
fi

# CRD 대기
echo "CRD 생성 대기 중..."
kubectl wait --for condition=established --timeout=60s \
  crd/clustersecretstores.external-secrets.io \
  crd/externalsecrets.external-secrets.io

echo "ESO installed."
echo ""

#############################################
# 2. ClusterSecretStore (IRSA 기반)
#############################################
echo "=== ClusterSecretStore 생성 중 ==="

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
echo "ClusterSecretStore 준비 대기 중..."
for i in {1..30}; do
  status=$(kubectl get clustersecretstore aws-secrets-manager -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
  if [[ "$status" == "True" ]]; then
    echo "  ClusterSecretStore 준비 완료"
    break
  fi
  reason=$(kubectl get clustersecretstore aws-secrets-manager -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null || echo "Unknown")
  echo "  대기 중... ($i/30) [reason: $reason]"
  sleep 2
done

echo ""

#############################################
# 3. Karpenter (Node Auto Provisioning)
#############################################
echo "=== Karpenter 설치 중 ==="

# namespace
kubectl create namespace karpenter --dry-run=client -o yaml | kubectl apply -f -

# Karpenter 설정 (환경변수로 오버라이드 가능)
KARPENTER_VERSION="${KARPENTER_VERSION:-1.10.0}"
CLUSTER_NAME="${CLUSTER_NAME:-$(kubectl config current-context | cut -d'/' -f2)}"
KARPENTER_ROLE_ARN="${KARPENTER_ROLE_ARN:-}"
KARPENTER_QUEUE_NAME="${KARPENTER_QUEUE_NAME:-}"

# terraform output에서 값 가져오기 시도
if [[ -z "$KARPENTER_ROLE_ARN" ]]; then
  echo "참고: KARPENTER_ROLE_ARN이 설정되지 않았습니다."
  echo "  Set it manually or run: export KARPENTER_ROLE_ARN=\$(terraform output -raw karpenter_irsa_role_arn)"
fi

if [[ -z "$KARPENTER_QUEUE_NAME" ]]; then
  echo "참고: KARPENTER_QUEUE_NAME이 설정되지 않았습니다."
  echo "  Set it manually or run: export KARPENTER_QUEUE_NAME=\$(terraform output -raw karpenter_queue_name)"
fi

# Karpenter 설치 (Public ECR 사용)
if [[ -n "$KARPENTER_ROLE_ARN" && -n "$KARPENTER_QUEUE_NAME" ]]; then
  # Public ECR 로그인
  aws ecr-public get-login-password --region us-east-1 | \
    helm registry login --username AWS --password-stdin public.ecr.aws

  helm upgrade --install karpenter "oci://public.ecr.aws/karpenter/karpenter" \
    -n karpenter \
    --version "$KARPENTER_VERSION" \
    --set "settings.clusterName=$CLUSTER_NAME" \
    --set "settings.interruptionQueue=$KARPENTER_QUEUE_NAME" \
    --set "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=$KARPENTER_ROLE_ARN" \
    --set replicas=1 \
    --set controller.resources.requests.cpu=100m \
    --set controller.resources.requests.memory=256Mi \
    --set controller.resources.limits.cpu=500m \
    --set controller.resources.limits.memory=512Mi \
    --wait --timeout=5m

  echo "Karpenter 컨트롤러 설치 완료."
  echo "NodePool/EC2NodeClass는 ArgoCD에 의해 배포됩니다."
else
  echo "필수 환경변수 누락으로 Karpenter 설치를 건너뜁니다"
  echo "  필수: KARPENTER_ROLE_ARN, KARPENTER_QUEUE_NAME"
fi

echo ""

#############################################
# 4. ArgoCD
#############################################
echo "=== ArgoCD 설치 중 ==="

# helm repo
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update

# namespace
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Values 파일 다운로드 (303-goormgb-k8s-helm 레포, private)
# GitHub 토큰은 AWS Secrets Manager에서 가져옴: prod/github/helm-repo-token
# raw.githubusercontent.com은 private repo에서 Bearer 인증이 불안정 → GitHub API 사용
GITHUB_API_URL="https://api.github.com/repos/goorm-gongbang/303-goormgb-k8s-helm/contents/prod/values/core/values-argocd-install.yaml?ref=prod/ash"
ARGOCD_VALUES_FILE="/tmp/argocd-values.yaml"

# AWS Secrets Manager에서 GitHub 토큰 조회
echo "AWS Secrets Manager에서 GitHub 토큰을 가져오는 중..."
GITHUB_TOKEN=""
if command -v aws &>/dev/null; then
  _secret_raw=$(aws secretsmanager get-secret-value \
    --secret-id "prod/github/helm-repo-token" \
    --query 'SecretString' \
    --output text \
    --region "$AWS_REGION" 2>&1) && \
  GITHUB_TOKEN=$(echo "$_secret_raw" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))" 2>/dev/null) || {
    echo "  경고: GitHub 토큰 조회 실패 — 원인: $_secret_raw"
  }
fi

if [[ -n "$GITHUB_TOKEN" ]]; then
  echo "  GitHub 토큰 로드 완료"
fi

# 토큰 유무에 따라 다운로드 시도 (GitHub Contents API)
DOWNLOAD_SUCCESS=false
echo "Helm 저장소에서 ArgoCD values를 다운로드하는 중..."
if [[ -n "$GITHUB_TOKEN" ]]; then
  if curl -sSfL \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.raw+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$GITHUB_API_URL" -o "$ARGOCD_VALUES_FILE" 2>/dev/null; then
    echo "  Values 파일 다운로드 완료 (GitHub API 사용)"
    DOWNLOAD_SUCCESS=true
  else
    echo "  경고: 토큰이 있으나 다운로드 실패 (레포/브랜치/경로 확인 필요)"
    echo "  테스트: curl -H \"Authorization: Bearer \$TOKEN\" -H \"Accept: application/vnd.github.raw+json\" \"$GITHUB_API_URL\""
  fi
else
  echo "  경고: GitHub 토큰 없음 (prod/github/helm-repo-token 시크릿 확인)"
fi

# 다운로드 실패 시 fallback 기본값 사용
if [[ "$DOWNLOAD_SUCCESS" == "false" ]]; then
  echo "  기본값으로 설치합니다 (Ingress 미포함 — 나중에 argocd-config 앱으로 적용됩니다)"
  cat > "$ARGOCD_VALUES_FILE" << 'VALUESEOF'
server:
  extraArgs:
    - --insecure
  service:
    type: ClusterIP
configs:
  cm:
    url: https://argocd.prod.playball.one
VALUESEOF
fi

# Webhook secret (optional)
WEBHOOK_SECRET=""
if command -v aws &>/dev/null; then
  WEBHOOK_SECRET=$(aws secretsmanager get-secret-value \
    --secret-id prod/argocd/webhook-github \
    --query 'SecretString' --output text 2>/dev/null || echo "")
fi

# ArgoCD 설치 (values 파일 사용)
# ESO와 동일하게 이미 설치된 경우 helm upgrade SSA 충돌 방지를 위해 건너뜀
if helm status argocd -n argocd &>/dev/null; then
  echo "  argocd가 이미 설치되어 있습니다 (재설치 건너뜀)"
  echo "  ※ ArgoCD 설정 변경은 ArgoCD에서 argocd-config 앱을 Sync하세요"
else
  HELM_ARGS=(
    upgrade --install argocd argo/argo-cd
    -n argocd
    --create-namespace
    -f "$ARGOCD_VALUES_FILE"
  )

  if [[ -n "$WEBHOOK_SECRET" ]]; then
    echo "GitHub webhook 시크릿을 찾음"
    HELM_ARGS+=(--set "configs.secret.extra.webhook\.github\.secret=$WEBHOOK_SECRET")
  fi

  helm "${HELM_ARGS[@]}" --wait --timeout=5m
fi

rm -f "$ARGOCD_VALUES_FILE"

# ArgoCD CRD 대기
echo "ArgoCD CRD 대기 중..."
kubectl wait --for=condition=Established crd/applications.argoproj.io --timeout=60s

echo "ArgoCD 설치 완료."
echo ""

#############################################
# 5. GitHub SSH Key (ExternalSecret)
#############################################
echo "=== GitHub SSH Key 설정 중 ==="

kubectl apply -f "$STAGING_DIR/argo-init/external-secret-github.yaml"

# Secret 생성 대기
echo "repo-goormgb-helm 시크릿 대기 중..."
for i in {1..30}; do
  if kubectl get secret repo-goormgb-helm -n argocd &>/dev/null; then
    if kubectl get secret repo-goormgb-helm -n argocd -o jsonpath='{.data.sshPrivateKey}' 2>/dev/null | grep -q "."; then
      echo "  GitHub SSH 시크릿 준비 완료"
      break
    fi
  fi
  es_status=$(kubectl get externalsecret repo-goormgb-helm -n argocd -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null || echo "")
  echo "  대기 중... ($i/30) [status: $es_status]"
  sleep 2
done

if ! kubectl get secret repo-goormgb-helm -n argocd &>/dev/null; then
  echo ""
  echo "오류: GitHub SSH 시크릿이 생성되지 않았습니다!"
  echo ""
  echo "디버그:"
  kubectl get clustersecretstore aws-secrets-manager -o yaml 2>/dev/null | grep -A10 "status:" || true
  kubectl get externalsecret repo-goormgb-helm -n argocd -o yaml 2>/dev/null | grep -A10 "status:" || true
  echo ""
  echo "확인:"
  echo "  aws secretsmanager get-secret-value --secret-id prod/argocd/github-ssh"
  exit 1
fi

echo ""

#############################################
# 6. ArgoCD RBAC ConfigMap (ESO → ConfigMap)
#############################################
echo "=== ArgoCD RBAC 설정 중 ==="

# RBAC ExternalSecret 생성
kubectl apply -f "$STAGING_DIR/argo-init/external-secret-rbac.yaml"

# ExternalSecret 강제 새로고침
kubectl annotate externalsecret argocd-rbac-eso -n argocd \
  force-sync="$(date +%s)" --overwrite 2>/dev/null || true

# ESO가 생성한 RBAC Secret 대기
echo "Waiting for argocd-rbac-eso secret..."
RBAC_SYNCED=false
for i in {1..30}; do
  if kubectl get secret argocd-rbac-eso -n argocd &>/dev/null; then
    policy=$(kubectl get secret argocd-rbac-eso -n argocd -o jsonpath='{.data.policy_csv}' 2>/dev/null | base64 -d || echo "")
    if [[ -n "$policy" ]]; then
      echo "  RBAC secret ready"
      RBAC_SYNCED=true
      break
    fi
  fi
  echo "  대기 중... ($i/30)"
  sleep 2
done

# RBAC ConfigMap 적용
if [[ "$RBAC_SYNCED" == "true" ]]; then
  echo "RBAC ConfigMap 적용 중..."
  echo "  정책:"
  echo "$policy" | sed 's/^/    /'

  # ConfigMap 생성/업데이트 (ArgoCD가 읽는 형식)
  kubectl create configmap argocd-rbac-cm -n argocd \
    --from-literal="policy.csv=$policy" \
    --from-literal="policy.default=role:none" \
    --from-literal="scopes=[email]" \
    --dry-run=client -o yaml | kubectl apply -f -

  # ConfigMap 라벨 추가 (ArgoCD가 인식하도록)
  kubectl label configmap argocd-rbac-cm -n argocd \
    app.kubernetes.io/name=argocd-rbac-cm \
    app.kubernetes.io/part-of=argocd \
    --overwrite

  echo "  RBAC ConfigMap 적용 완료"

  # ArgoCD server 재시작
  echo "RBAC 적용을 위해 ArgoCD 서버 재시작 중..."
  kubectl rollout restart deployment argocd-server -n argocd
  kubectl rollout status deployment argocd-server -n argocd --timeout=60s

  echo "  RBAC 설정 완료"
else
  echo "경고: 타임아웃 내에 RBAC 시크릿이 동기화되지 않았습니다"
  echo "  설치 후 수동으로 실행하세요: ./prod/scripts/sync-rbac.sh"
fi

echo ""

#############################################
# 7. Root Application
#############################################
echo "=== Root Application 배포 중 ==="

kubectl apply -f "$STAGING_DIR/argo-init/root-application.yaml"

echo "root-prod 앱 대기 중..."
sleep 5

# Refresh trigger
kubectl annotate application root-prod -n argocd argocd.argoproj.io/refresh=normal --overwrite 2>/dev/null || true

# App 상태 확인
for i in {1..12}; do
  health=$(kubectl get application root-prod -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "")
  sync=$(kubectl get application root-prod -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "")
  echo "  확인 중... ($i/12) [sync=$sync, health=$health]"
  if [[ "$sync" == "Synced" ]]; then
    break
  fi
  sleep 10
done

echo ""

#############################################
# 8. ALB webhook 준비 확인 후 ingress/DNS sync
# aws-load-balancer-controller의 certgen Job이 완료되어
# webhook TLS 인증서가 실제로 동작할 때까지 대기 후 sync
#############################################
echo "=== ALB Controller webhook 준비 확인 중 ==="

ALB_WEBHOOK_READY=false
for i in {1..24}; do
  # webhook 존재 여부 확인
  if kubectl get validatingwebhookconfigurations aws-load-balancer-webhook &>/dev/null; then
    # 실제 webhook이 동작하는지 테스트 (dry-run으로 검증)
    if kubectl create ingress test-webhook-check \
      --rule="test.example.com/=test-svc:80" \
      --dry-run=server -n default &>/dev/null 2>&1; then
      echo "  ALB webhook 준비 완료 ($i/24)"
      ALB_WEBHOOK_READY=true
      break
    fi
  fi
  echo "  ALB webhook 대기 중... ($i/24)"
  sleep 10
done

if [[ "$ALB_WEBHOOK_READY" == "true" ]]; then
  echo "ALB webhook 확인 완료 → alb-ingress, external-dns sync 트리거"

  # hard refresh 후 sync
  for app in alb-ingress external-dns; do
    kubectl annotate application "$app" -n argocd \
      argocd.argoproj.io/refresh=hard --overwrite 2>/dev/null || true
    sleep 2
    kubectl patch application "$app" -n argocd \
      --type merge -p '{"operation":{"sync":{}}}' 2>/dev/null || true
    echo "  $app sync 트리거 완료"
  done

  # sync 결과 대기
  echo "alb-ingress / external-dns sync 대기 중..."
  for i in {1..18}; do
    alb_sync=$(kubectl get application alb-ingress -n argocd \
      -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "")
    dns_sync=$(kubectl get application external-dns -n argocd \
      -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "")
    echo "  확인 중... ($i/18) [alb-ingress=$alb_sync, external-dns=$dns_sync]"
    if [[ "$alb_sync" == "Synced" && "$dns_sync" == "Synced" ]]; then
      echo "  alb-ingress, external-dns Sync 완료!"
      break
    fi
    sleep 10
  done
else
  echo "경고: ALB webhook이 4분 내 준비되지 않았습니다"
  echo "  수동으로 실행하세요:"
  echo "  kubectl patch application alb-ingress -n argocd --type merge -p '{\"operation\":{\"sync\":{}}}'"
  echo "  kubectl patch application external-dns -n argocd --type merge -p '{\"operation\":{\"sync\":{}}}'"
fi

echo ""

#############################################
# 9. OAuth Secret 동기화 대기 및 ArgoCD 재시작
# ArgoCD가 빈 값을 캐싱하는 것을 방지하기 위해
# Google OAuth Secret이 생성된 후 서버를 재시작합니다.
#############################################
echo "=== Google OAuth Secret 동기화 대기 중 ==="
OAUTH_SECRET_READY=false
for i in {1..12}; do
  if kubectl get secret argocd-google-oauth -n argocd &>/dev/null; then
    echo "  OAuth Secret 생성 확인 완료 ($i/12)"
    OAUTH_SECRET_READY=true
    break
  fi
  echo "  Secret 생성 대기 중... ($i/12)"
  sleep 10
done

if [[ "$OAUTH_SECRET_READY" == "true" ]]; then
  echo "OAuth Secret 캐시 갱신을 위해 ArgoCD 서버 재시작 중..."
  kubectl rollout restart deployment argocd-server -n argocd
  kubectl rollout status deployment argocd-server -n argocd --timeout=60s
  echo "  ArgoCD 서버 재시작 완료"
else
  echo "경고: OAuth Secret이 2분 내 생성되지 않았습니다."
  echo "  생성 확인 후 수동으로 재시작하세요: kubectl rollout restart deployment argocd-server -n argocd"
fi
echo ""

#############################################
# Done
#############################################
echo "=================================================="
echo "  부트스트랩 완료!"
echo "=================================================="
echo ""
echo "ArgoCD UI: $ARGOCD_URL"
echo ""
echo "관리자 비밀번호:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"
echo ""
echo "애플리케이션:"
kubectl get app -n argocd 2>/dev/null || echo "  (none yet, wait for sync)"
echo ""
