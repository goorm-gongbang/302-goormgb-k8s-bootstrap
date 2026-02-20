# 302-goormgb-k8s-bootstrap

kubeadm 클러스터에 ArgoCD 환경을 구성하는 부트스트랩 스크립트.

## 레포 역할

- **302-goormgb-k8s-bootstrap** (이 레포): MiniPC에서 1회 실행하여 기반 인프라 설치
- **303-goormgb-k8s-helm**: ArgoCD가 watch하며 지속적 GitOps 배포

부트스트랩 실행 후, 모든 변경은 303 레포에서 Git push로 진행합니다.

## ArgoCD가 바라보는 브랜치

| 환경    | 브랜치                | 클러스터         |
| ------- | --------------------- | ---------------- |
| dev     | `argocd-sync/dev`     | kubeadm (MiniPC) |
| staging | `argocd-sync/staging` | EKS              |
| prod    | `argocd-sync/prod`    | EKS              |

해당 브랜치에 push하면 ArgoCD가 자동으로 감지하여 배포합니다.

## 설치 항목

- Calico CNI
- Local Path Provisioner (StorageClass)
- External Secrets Operator (ESO)
- cert-manager
- Istio
- ArgoCD + Root Application

## 사용법

### 전체 설치

```bash
git clone https://github.com/goorm-gongbang/302-goormgb-k8s-bootstrap.git
cd 302-goormgb-k8s-bootstrap

make install-all
```

### 개별 설치

```bash
make help                 # 명령어 목록

make install-calico       # Calico CNI (kubeadm 필수)
make install-storage      # Local Path Provisioner
make install-eso          # External Secrets Operator
make bootstrap-aws        # AWS credentials 등록 (대화형)
make install-cert-manager
make install-istio
make install-argocd
make deploy-root-app      # ArgoCD Root Application
```

### 유틸리티

```bash
make ddns-update          # DDNS 수동 업데이트
make ddns-test            # Route53 API 테스트
make rbac-create-users    # 팀원 kubeconfig 생성
make fix-port-conflict    # 80/443 포트 충돌 해결
```

### 정리

```bash
make clean-apps           # 앱 정리 (ArgoCD, cert-manager 유지)
make clean-cluster        # kubeadm 완전 초기화
```

## 디렉토리 구조

```
.
├── Makefile                    # 설치 명령어 모음
├── scripts/
│   ├── calico/install.sh       # Calico CNI 설치
│   ├── storage/install.sh      # Local Path Provisioner
│   ├── argocd/install.sh       # ArgoCD Helm 설치
│   ├── cert-manager/install.sh
│   ├── eso/
│   │   ├── install.sh
│   │   └── bootstrap-aws.sh
│   ├── istio/
│   │   ├── install.sh
│   │   └── fix-port-conflict.sh
│   ├── rbac/
│   │   └── create-all-users.sh
│   ├── ddns/
│   │   ├── test-api.sh
│   │   └── update-now.sh
│   ├── clean-apps.sh
│   └── clean-cluster.sh
└── argo-init/
    ├── root-application.yaml   # App of Apps 루트 (303 레포를 가리킴)
    └── external-secret-github.yaml
```

## 설치 후 확인

```bash
# ArgoCD UI
https://argocd.goormgb.homes

# Application 상태
kubectl get applications -n argocd

# Pod 상태
kubectl get pods -A
```

## 관련 레포

| 레포                                                                           | 용도                    |
| ------------------------------------------------------------------------------ | ----------------------- |
| **302-goormgb-k8s-bootstrap**                                                  | 1회성 부트스트랩        |
| [303-goormgb-k8s-helm](https://github.com/goorm-gongbang/303-goormgb-k8s-helm) | GitOps (ArgoCD가 watch) |
