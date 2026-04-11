# Dev 환경 (kubeadm)

kubeadm 클러스터(MiniPC)에 ArgoCD 환경을 구성하는 부트스트랩 스크립트.

## 설치 항목 (순서대로)

| 순서 | 컴포넌트 | 설명 |
|------|----------|------|
| 1 | Calico CNI | 네트워크 플러그인 (kubeadm 필수) |
| 2 | Local Path Provisioner | StorageClass (PV 동적 프로비저닝) |
| 3 | External Secrets Operator | AWS Secrets Manager 연동 |
| 4 | AWS Credentials | ESO용 인증 정보 등록 |
| 5 | cert-manager | TLS 인증서 자동 발급 (Let's Encrypt) |
| 6 | Istio | Service Mesh (IngressGateway 포함) |
| 7 | Prometheus Operator CRDs | ServiceMonitor, PodMonitor 등 CRD |
| 8 | ArgoCD | GitOps CD 도구 |
| 9 | GitHub SSH Key | ArgoCD가 private repo 접근용 |
| 10 | Root Application | App of Apps (303 레포의 dev/root 참조) |

## 사용법

### 전체 설치

```bash
cd 302-goormgb-k8s-bootstrap/dev
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
make install-prometheus-crds
make install-argocd
make setup-github-ssh     # GitHub SSH Key 설정 (ExternalSecret)
make deploy-root-app      # ArgoCD Root Application
```

### 유틸리티

```bash
make fix-port-conflict    # 80/443 포트 충돌 해결
make rbac-create-users    # 팀원 kubeconfig 생성
make ddns-test            # Route53 API 테스트
make ddns-update          # DDNS 수동 업데이트
```

### 정리

```bash
make clean-apps           # 앱 정리 (ArgoCD, cert-manager 유지)
make clean-all            # 완전 초기화 (전체 삭제, kubeadm 유지)
```

## 디렉토리 구조

```
dev/
├── Makefile                    # 설치 명령어 모음
├── README.md                   # 이 파일
├── scripts/
│   ├── calico/install.sh       # Calico CNI
│   ├── storage/install.sh      # Local Path Provisioner
│   ├── argocd/install.sh       # ArgoCD Helm 설치
│   ├── cert-manager/install.sh
│   ├── eso/
│   │   ├── install.sh
│   │   └── bootstrap-aws.sh
│   ├── istio/
│   │   ├── install.sh
│   │   └── fix-port-conflict.sh
│   ├── monitoring/
│   │   ├── install-crds.sh     # Prometheus CRDs
│   │   └── enable-etcd-metrics.sh
│   ├── rbac/
│   │   └── create-all-users.sh
│   ├── ddns/
│   │   ├── test-api.sh
│   │   └── update-now.sh
│   ├── clean-apps.sh
│   └── clean-all.sh
├── argo-init/
│   ├── root-application.yaml   # App of Apps (303 레포의 dev/root 참조)
│   └── external-secret-*.yaml
└── manifests/
    └── kubeadm 관련 매니페스트
```

## 설치 후 확인

```bash
# ArgoCD UI
https://argocd.goormgb.space

# Application 상태
kubectl get applications -n argocd

# Pod 상태
kubectl get pods -A
```

## EKS와 차이점

| 컴포넌트 | kubeadm (이 환경) | EKS (staging/prod) |
|----------|-------------------|---------------------|
| CNI | Calico | VPC CNI |
| Storage | Local Path Provisioner | EBS CSI |
| TLS | cert-manager + Let's Encrypt | ACM |
| DB | PostgreSQL Pod | RDS |
| Cache | Redis Pod | ElastiCache |
| DDNS | Cloudflare CronJob | 불필요 (고정 IP) |
