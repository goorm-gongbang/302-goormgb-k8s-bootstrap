# Staging 환경 배포 가이드

Staging 환경(EKS)의 전체 배포 순서를 설명합니다.

## 레포 역할

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  301-goormgb-terraform        │  302 (이 레포)           │  303-goormgb-k8s-helm │
│  ─────────────────────        │  ──────────────────────  │  ───────────────────  │
│  AWS 인프라 프로비저닝         │  Staging 초기화 스크립트  │  GitOps 배포           │
│  - VPC, RDS, ElastiCache      │  - DB 초기화              │  - ArgoCD가 watch     │
│  - EKS, Karpenter             │  - ArgoCD Root App        │  - Helm 차트          │
│  - Bastion                    │                          │                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 전체 배포 순서

### Phase 1: 인프라 (301-goormgb-terraform)

```bash
cd ~/Documents/GitHub/301-goormgb-terraform/environments/staging

# AWS 인증
aws sso login --profile wonny
export AWS_PROFILE=wonny

# 1단계: VPC
terraform apply -target=module.vpc

# 2단계: RDS + ElastiCache
terraform apply -target=module.rds -target=module.elasticache

# 3단계: EKS (~15분)
terraform apply -target=module.eks

# 4단계: Karpenter
terraform apply -target=module.karpenter

# 5단계: Bastion (선택)
terraform apply -target=module.bastion

# 전체 상태 정리
terraform apply
```

### Phase 2: kubeconfig 설정

```bash
# EKS 클러스터에 연결
aws eks update-kubeconfig \
  --region ap-northeast-2 \
  --name goormgb-staging \
  --profile wonny

# 연결 확인
kubectl get nodes
```

### Phase 3: ArgoCD Root Application 배포

```bash
cd ~/Documents/GitHub/302-goormgb-k8s-bootstrap/staging

# ArgoCD Root Application 배포
kubectl apply -f argo-init/
```

> **주의:** 아직 ArgoCD sync 하지 마세요! DB 초기화가 먼저 필요합니다.

### Phase 4: DB 초기화 (앱 배포 전 필수!)

```bash
cd ~/Documents/GitHub/302-goormgb-k8s-bootstrap/staging/db

# Secret Manager에서 DB 정보 가져오기
export DB_HOST=$(aws secretsmanager get-secret-value \
  --secret-id staging/services/db \
  --query 'SecretString' \
  --output text \
  --profile wonny | jq -r '.host')

export DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id staging/services/db \
  --query 'SecretString' \
  --output text \
  --profile wonny | jq -r '.password')

export DB_USER=$(aws secretsmanager get-secret-value \
  --secret-id staging/services/db \
  --query 'SecretString' \
  --output text \
  --profile wonny | jq -r '.username')

export DB_NAME=$(aws secretsmanager get-secret-value \
  --secret-id staging/services/db \
  --query 'SecretString' \
  --output text \
  --profile wonny | jq -r '.dbname')

# DB 초기화 스크립트 실행
./db-init.sh
```

**DB 초기화가 먼저 필요한 이유:**
- 백엔드 앱이 시작 시 테이블 존재 여부 확인
- 스키마/시드 데이터 없으면 앱 크래시

### Phase 5: ArgoCD Sync

```bash
# ArgoCD UI 접속
# https://argocd.staging.goormgb.space

# 또는 CLI로 sync
argocd app sync root-staging --prune
```

---

## 디렉토리 구조

```
staging/
├── README.md                  # 이 파일
├── argo-init/
│   ├── root-application.yaml  # ArgoCD Root App (App of Apps)
│   └── external-secret-*.yaml # GitHub SSH Key 등
├── db/
│   ├── 01-schema.sql          # 테이블 생성 (DDL)
│   ├── 02-seed-data.sql       # 시드 데이터 (구장, 구단, 좌석, 가격)
│   ├── 03-matches.sql         # 경기 일정
│   └── db-init.sh             # 초기화 스크립트
└── scripts/
    └── (staging 전용 스크립트)
```

---

## DB 스크립트 상세

| 파일 | 내용 | 행 수 |
|------|------|-------|
| `01-schema.sql` | 26개 테이블 생성 | - |
| `02-seed-data.sql` | 구장 11개, 구단 10개, 좌석 29,960석, 가격 정책 | ~600 |
| `03-matches.sql` | 3월~9월 경기 일정 | ~300경기 |

### 개별 SQL 실행 (필요 시)

```bash
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f 01-schema.sql
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f 02-seed-data.sql
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f 03-matches.sql
```

---

## 트러블슈팅

### Secret Manager 오류: "secret already scheduled for deletion"

```bash
aws secretsmanager delete-secret \
  --secret-id staging/services/db \
  --force-delete-without-recovery \
  --profile wonny
```

### DB 연결 실패

1. RDS 보안그룹 확인 (VPC CIDR 허용 여부)
2. Bastion 통해 접근 시 port-forward 필요:
   ```bash
   # Bastion SSH 터널
   ssh -L 5432:<RDS_ENDPOINT>:5432 ec2-user@<BASTION_IP>
   ```

### ArgoCD 앱 sync 실패

```bash
# 앱 상태 확인
kubectl get applications -n argocd

# 로그 확인
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

---

## 관련 문서

- [301-goormgb-terraform/environments/staging/README.md](https://github.com/goorm-gongbang/301-goormgb-terraform) - Terraform 상세
- [303-goormgb-k8s-helm](https://github.com/goorm-gongbang/303-goormgb-k8s-helm) - Helm 차트
