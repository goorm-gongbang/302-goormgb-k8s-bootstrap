# 302-goormgb-k8s-bootstrap/staging Makefile
# EKS Staging 클러스터 초기 설정을 위한 명령어 모음

.PHONY: help install-all install-eso install-karpenter install-argocd setup-github-ssh setup-rbac deploy-root-app db-init sync-rbac

# 기본 타겟
help:
	@echo "=== Staging EKS Bootstrap Commands ==="
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
	@echo "=== Installing all components ==="
	./scripts/install-all.sh

# === 개별 설치 ===
install-eso:
	@echo "=== Installing External Secrets Operator ==="
	@helm repo add external-secrets https://charts.external-secrets.io 2>/dev/null || true
	@helm repo update
	@kubectl create namespace external-secrets --dry-run=client -o yaml | kubectl apply -f -
	@helm upgrade --install external-secrets external-secrets/external-secrets \
		-n external-secrets \
		--set installCRDs=true \
		--set serviceAccount.create=true \
		--set serviceAccount.name=external-secrets \
		--wait --timeout=5m
	@echo "ESO installed. Set up ClusterSecretStore next."

install-karpenter:
	@echo "=== Installing Karpenter ==="
	@echo "NOTE: Requires KARPENTER_ROLE_ARN and KARPENTER_QUEUE_NAME environment variables"
	@echo "  export KARPENTER_ROLE_ARN=\$$(terraform output -raw karpenter_irsa_role_arn)"
	@echo "  export KARPENTER_QUEUE_NAME=\$$(terraform output -raw karpenter_queue_name)"
	@echo ""
	@if [ -z "$$KARPENTER_ROLE_ARN" ] || [ -z "$$KARPENTER_QUEUE_NAME" ]; then \
		echo "ERROR: Environment variables not set"; \
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
	@echo "Karpenter installed."

install-argocd:
	@echo "=== Installing ArgoCD ==="
	@helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
	@helm repo update
	@kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	@helm upgrade --install argocd argo/argo-cd \
		-n argocd \
		--set server.extraArgs[0]="--insecure" \
		--set server.service.type=ClusterIP \
		--wait --timeout=5m
	@echo "ArgoCD installed."
	@echo "Admin password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"

setup-github-ssh:
	@echo "=== Setting up GitHub SSH Key (ExternalSecret) ==="
	kubectl apply -f argo-init/external-secret-github.yaml
	@echo "Waiting for ExternalSecret to sync..."
	@sleep 5
	@kubectl get externalsecret repo-goormgb-helm -n argocd || echo "ExternalSecret not ready yet."

setup-rbac:
	@echo "=== Setting up ArgoCD RBAC ==="
	kubectl apply -f argo-init/external-secret-rbac.yaml
	@sleep 5
	./scripts/sync-rbac.sh

deploy-root-app:
	@echo "=== Deploying Root Application ==="
	kubectl apply -f argo-init/root-application.yaml
	@echo "Waiting for root app to be created..."
	@sleep 5
	@kubectl annotate application root-staging -n argocd argocd.argoproj.io/refresh=normal --overwrite 2>/dev/null || true
	@echo "Root Application deployed."

# === DB 초기화 ===
db-init:
	@echo "=== Initializing Database ==="
	@echo "Make sure to set DB_HOST, DB_USER, DB_PASSWORD, DB_NAME environment variables"
	./db/db-init.sh

# === 유틸리티 ===
sync-rbac:
	./scripts/sync-rbac.sh
