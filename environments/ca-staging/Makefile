# CA Staging EKS Bootstrap
# 사용법: make help

ENV := ca-staging
ROOT_DIR := $(shell cd ../.. && pwd)

.PHONY: help 00-install-all 01-db-init 02-ai-init sync-rbac

help:
	@echo "=== CA Staging EKS Bootstrap ==="
	@echo ""
	@echo "순서대로 실행:"
	@echo "  make 00-install-all    - 전체 설치 (ESO → Karpenter → ArgoCD → Root App)"
	@echo "  make 01-db-init        - PostgreSQL 스키마/시드 데이터 초기화"
	@echo "  make 02-ai-init        - AI Defense DB 초기화"
	@echo ""
	@echo "유틸리티:"
	@echo "  make sync-rbac         - RBAC ConfigMap 수동 동기화"

00-install-all:
	@echo "=== CA Staging: Installing all components ==="
	./scripts/install-all.sh

01-db-init:
	@echo "=== CA Staging: DB 초기화 ==="
	$(ROOT_DIR)/db/db-init.sh $(ENV)

02-ai-init:
	@echo "=== CA Staging: AI Defense DB 초기화 ==="
	$(ROOT_DIR)/ai/ai-init.sh $(ENV)

sync-rbac:
	./scripts/sync-rbac.sh
