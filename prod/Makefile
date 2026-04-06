# 302-goormgb-k8s-bootstrap/prod Makefile
# EKS Prod 클러스터 초기 설정을 위한 명령어 모음

.PHONY: help install-all install-eso install-karpenter install-argocd setup-github-ssh setup-rbac deploy-root-app db-init sync-rbac

# 기본 타겟
help:
	@echo "=== Prod EKS 부트스트랩 명령어 ==="
	@echo ""
	@echo "전체 설치:"
	@echo "  make install-all       - 전체 설치 (ESO → Karpenter → ArgoCD → Root App)"
	@echo ""
	@echo "개별 설치:"
	@echo "  make install-eso       - External Secrets Operator 설치"
	@echo "  make install-karpenter - Karpenter 설치 (Node Auto Provisioning)"
	@echo "  make install-argocd    - ArgoCD 설치"
	@echo "  make setup-github-ssh  - GitHub SSH Key 설정 (ExternalSecret)"
	@echo "  make setup-rbac        - ArgoCD RBAC 설정"
	@echo "  make deploy-root-app   - ArgoCD Root Application 배포"
	@echo ""
	@echo "DB 초기화:"
	@echo "  make db-init           - PostgreSQL 스키마/시드 데이터 초기화"
	@echo ""
	@echo "유틸리티:"
	@echo "  make sync-rbac         - RBAC ConfigMap 수동 동기화"

# === 전체 설치 ===
install-all:
	@echo "=== 모든 컴포넌트 설치 중 ==="
	./scripts/install-all.sh

# === 개별 설치 ===
install-eso:
	@echo "=== External Secrets Operator 설치 중 ==="
	@helm repo add external-secrets https://charts.external-secrets.io 2>/dev/null || true
	@helm repo update
	@kubectl create namespace external-secrets --dry-run=client -o yaml | kubectl apply -f -
	@helm upgrade --install external-secrets external-secrets/external-secrets \
		-n external-secrets \
		--set installCRDs=true \
		--set serviceAccount.create=true \
		--set serviceAccount.name=external-secrets \
		--wait --timeout=5m
	@echo "ESO 설치 완료. 다음으로 ClusterSecretStore를 설정하세요."

install-karpenter:
	@echo "=== Karpenter 설치 중 ==="
	@echo "참고: KARPENTER_ROLE_ARN 및 KARPENTER_QUEUE_NAME 환경변수가 필요합니다"
	@echo "  export KARPENTER_ROLE_ARN=\$$(terraform output -raw karpenter_irsa_role_arn)"
	@echo "  export KARPENTER_QUEUE_NAME=\$$(terraform output -raw karpenter_queue_name)"
	@echo ""
	@if [ -z "$$KARPENTER_ROLE_ARN" ] || [ -z "$$KARPENTER_QUEUE_NAME" ]; then \
		echo "오류: 환경변수가 설정되지 않았습니다"; \
		exit 1; \
	fi
	@kubectl create namespace karpenter --dry-run=client -o yaml | kubectl apply -f -
	@aws ecr-public get-login-password --region us-east-1 | helm registry login --username AWS --password-stdin public.ecr.aws
	@helm upgrade --install karpenter "oci://public.ecr.aws/karpenter/karpenter" \
		-n karpenter \
		--version 1.1.1 \
		--set "settings.clusterName=$$(kubectl config current-context | cut -d'/' -f2)" \
		--set "settings.interruptionQueue=$$KARPENTER_QUEUE_NAME" \
		--set "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=$$KARPENTER_ROLE_ARN" \
		--set replicas=1 \
		--wait --timeout=5m
	@echo "Karpenter 설치 완료."

install-argocd:
	@echo "=== ArgoCD 설치 중 ==="
	@helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
	@helm repo update
	@kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	@helm upgrade --install argocd argo/argo-cd \
		-n argocd \
		--set server.extraArgs[0]="--insecure" \
		--set server.service.type=ClusterIP \
		--wait --timeout=5m
	@echo "ArgoCD 설치 완료."
	@echo "관리자 비밀번호: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"

setup-github-ssh:
	@echo "=== GitHub SSH Key 설정 (ExternalSecret) ==="
	kubectl apply -f argo-init/external-secret-github.yaml
	@echo "ExternalSecret 동기화 대기 중..."
	@sleep 5
	@kubectl get externalsecret repo-goormgb-helm -n argocd || echo "ExternalSecret이 아직 준비되지 않았습니다."

setup-rbac:
	@echo "=== ArgoCD RBAC 설정 중 ==="
	kubectl apply -f argo-init/external-secret-rbac.yaml
	@sleep 5
	./scripts/sync-rbac.sh

deploy-root-app:
	@echo "=== Root Application 배포 중 ==="
	kubectl apply -f argo-init/root-application.yaml
	@echo "Root 앱 생성 대기 중..."
	@sleep 5
	@kubectl annotate application root-prod -n argocd argocd.argoproj.io/refresh=normal --overwrite 2>/dev/null || true
	@echo "Root Application 배포 완료."

# === DB 초기화 ===
db-init:
	@echo "=== 데이터베이스 초기화 중 ==="
	@echo "DB_HOST, DB_USER, DB_PASSWORD, DB_NAME 환경변수 설정 여부를 확인하세요"
	./db/db-init.sh

# === 유틸리티 ===
sync-rbac:
	./scripts/sync-rbac.sh
