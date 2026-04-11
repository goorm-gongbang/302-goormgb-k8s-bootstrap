# Staging 환경 (EKS)

EKS 클러스터(AWS)에 ArgoCD 환경을 구성하는 부트스트랩 스크립트.

## 설치 항목 (순서대로)

| 순서 | 컴포넌트 | 설명 |
|------|----------|------|
| 1 | External Secrets Operator | AWS Secrets Manager 연동 (IRSA 사용) |
| 2 | ClusterSecretStore | ESO가 AWS SM 접근하기 위한 설정 |
| 3 | Karpenter | Node Auto Provisioning |
| 4 | ArgoCD | GitOps CD 도구 |
| 5 | GitHub SSH Key | ArgoCD가 private repo 접근용 |
| 6 | RBAC ConfigMap | ArgoCD 권한 설정 (Google OAuth 연동) |
| 7 | Root Application | App of Apps (303 레포의 staging/root 참조) |

> **참고:** DB 초기화는 앱 배포 전에 별도로 실행해야 합니다.

## 사용법

### 전체 설치

```bash
cd 302-goormgb-k8s-bootstrap/staging
make install-all
```

### 개별 설치

```bash
make help                 # 명령어 목록

make install-eso          # External Secrets Operator
make install-karpenter    # Karpenter (환경변수 필요)
make install-argocd       # ArgoCD
make setup-github-ssh     # GitHub SSH Key (ExternalSecret)
make setup-rbac           # RBAC ConfigMap
make deploy-root-app      # ArgoCD Root Application
```

### DB 초기화 (앱 배포 전 필수!)

```bash
# 환경변수 설정 (AWS Secrets Manager에서 가져오기)
export DB_HOST=$(aws secretsmanager get-secret-value \
  --secret-id staging/services/db --query 'SecretString' --output text | jq -r '.host')
export DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id staging/services/db --query 'SecretString' --output text | jq -r '.password')
export DB_USER=$(aws secretsmanager get-secret-value \
  --secret-id staging/services/db --query 'SecretString' --output text | jq -r '.username')
export DB_NAME=$(aws secretsmanager get-secret-value \
  --secret-id staging/services/db --query 'SecretString' --output text | jq -r '.dbname')

# DB 초기화
make db-init
```

## 전체 배포 순서

### Phase 1: 인프라 (301-goormgb-terraform)

```bash
cd ~/Documents/GitHub/301-goormgb-terraform/environments/staging

# AWS 인증
aws sso login --profile wonny
export AWS_PROFILE=wonny

# Terraform apply
terraform apply
```

### Phase 2: kubeconfig 설정

```bash
aws eks update-kubeconfig \
  --region ap-northeast-2 \
  --name goormgb-staging \
  --profile wonny

kubectl get nodes
```

### Phase 3: Bootstrap

```bash
cd ~/Documents/GitHub/302-goormgb-k8s-bootstrap/staging
make install-all
```

### Phase 4: DB 초기화

```bash
# 환경변수 설정 후
make db-init
```

### Phase 5: ArgoCD Sync

```bash
# ArgoCD UI에서 sync 또는
argocd app sync root-staging --prune
```

## 디렉토리 구조

```
staging/
├── Makefile                   # 설치 명령어 모음
├── README.md                  # 이 파일
├── argo-init/
│   ├── root-application.yaml  # ArgoCD Root App (App of Apps)
│   ├── external-secret-github.yaml
│   └── external-secret-rbac.yaml
├── db/
│   ├── 01-schema.sql          # 테이블 생성 (DDL)
│   ├── 02-seed-data.sql       # 시드 데이터 (구장, 구단, 좌석, 가격)
│   ├── 03-matches.sql         # 경기 일정
│   └── db-init.sh             # 초기화 스크립트
└── scripts/
    ├── install-all.sh         # 전체 설치 스크립트
    └── sync-rbac.sh           # RBAC 수동 동기화
```

## DB 스크립트 상세

| 파일 | 내용 |
|------|------|
| `01-schema.sql` | 26개 테이블 생성 |
| `02-seed-data.sql` | 구장 11개, 구단 10개, 좌석 29,960석, 가격 정책 |
| `03-matches.sql` | 3월~9월 경기 일정 (~300경기) |

## 설치 후 확인

```bash
# ArgoCD UI
https://argocd.staging.playball.one

# Application 상태
kubectl get applications -n argocd

# Pod 상태
kubectl get pods -A
```

## kubeadm과 차이점

| 컴포넌트 | EKS (이 환경) | kubeadm (dev) |
|----------|---------------|---------------|
| CNI | VPC CNI | Calico |
| Storage | EBS CSI | Local Path Provisioner |
| TLS | ACM | cert-manager + Let's Encrypt |
| DB | RDS | PostgreSQL Pod |
| Cache | ElastiCache | Redis Pod |
| Node Scaling | Karpenter | 수동 |

## 트러블슈팅

### Secret Manager 오류: "secret already scheduled for deletion"

```bash
aws secretsmanager delete-secret \
  --secret-id staging/services/db \
  --force-delete-without-recovery
```

### Karpenter 환경변수 설정

```bash
cd ~/Documents/GitHub/301-goormgb-terraform/environments/staging
export KARPENTER_ROLE_ARN=$(terraform output -raw karpenter_irsa_role_arn)
export KARPENTER_QUEUE_NAME=$(terraform output -raw karpenter_queue_name)
```

### ArgoCD 앱 sync 실패

```bash
kubectl get applications -n argocd
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```
