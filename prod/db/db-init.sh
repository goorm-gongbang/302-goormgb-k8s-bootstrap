#!/bin/bash
# ============================================================
# prod/db/db-init.sh
# Prod 환경 DB 초기화 스크립트 (완전 자동화 버전)
#
# 요구사항:
#   1. PEM_PATH 환경변수 (Bastion 접속용 .pem 키 경로)
#   2. AWS CLI 및 Terraform 설치
# ============================================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 1. 필수 환경변수 체크
if [ -z "$PEM_PATH" ]; then
    echo -e "${RED}오류: PEM_PATH 환경변수가 설정되지 않았습니다.${NC}"
    echo -e "${YELLOW}사용법: export PEM_PATH=\"/path/to/your-key.pem\" && $0${NC}"
    exit 1
fi

if [ ! -f "$PEM_PATH" ]; then
    echo -e "${RED}오류: 지정된 경로에 PEM 파일이 존재하지 않습니다: $PEM_PATH${NC}"
    exit 1
fi

# **권한 자동 수정 추가**
echo -e "${YELLOW}보안을 위해 PEM 키 권한을 수정합니다 (chmod 400)...${NC}"
chmod 400 "$PEM_PATH"

# 2. 테라폼 정보 감지
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${TERRAFORM_DIR:-$HOME/01_KDT/301-goormgb-terraform/environments/prod}"

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  Prod DB 초기화 스크립트 (자동화)${NC}"
echo -e "${BLUE}============================================================${NC}"

if [ ! -d "$TERRAFORM_DIR" ]; then
    echo -e "${RED}오류: 테라폼 디렉토리를 찾을 수 없습니다: $TERRAFORM_DIR${NC}"
    exit 1
fi

echo -e "테라폼에서 정보를 가져오는 중..."
RDS_ENDPOINT=$(cd "$TERRAFORM_DIR" && terraform output -raw rds_address 2>/dev/null || echo "")
DB_USER=$(cd "$TERRAFORM_DIR" && terraform output -raw rds_username 2>/dev/null || echo "")
DB_NAME=$(cd "$TERRAFORM_DIR" && terraform output -raw rds_db_name 2>/dev/null || echo "")
SECRET_ARN=$(cd "$TERRAFORM_DIR" && terraform output -raw rds_secret_arn 2>/dev/null || echo "")
BASTION_ID=$(cd "$TERRAFORM_DIR" && terraform output -raw bastion_instance_id 2>/dev/null || echo "")

if [[ -z "$RDS_ENDPOINT" || -z "$BASTION_ID" ]]; then
    echo -e "${RED}오류: 테라폼 출력값을 가져오지 못했습니다. terraform apply 상태를 확인하세요.${NC}"
    exit 1
fi

# 3. Bastion 퍼블릭 IP 및 DB 비밀번호 조회
echo -e "Bastion IP 및 DB 비밀번호 조회 중..."
BASTION_IP=$(aws ec2 describe-instances --instance-ids "$BASTION_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text --region ap-northeast-2)
DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" --query 'SecretString' --output text --region ap-northeast-2 | python3 -c "import sys,json; print(json.load(sys.stdin).get('password',''))" 2>/dev/null || aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" --query 'SecretString' --output text --region ap-northeast-2)

if [[ -z "$BASTION_IP" || "$BASTION_IP" == "None" ]]; then
    echo -e "${RED}오류: Bastion의 퍼블릭 IP를 찾을 수 없습니다.${NC}"
    exit 1
fi

# 4. SSH 터널링 설정
LOCAL_PORT=5432
BASTION_USER="ec2-user"

echo -e "${BLUE}SSH 터널링 생성 중... (Local $LOCAL_PORT -> RDS)${NC}"
echo "Bastion IP: $BASTION_IP"

# 기존 터널링 프로세스 정리 (옵션)
LSOF_CHECK=$(lsof -ti :$LOCAL_PORT || true)
if [ -n "$LSOF_CHECK" ]; then
    echo -e "${YELLOW}포트 $LOCAL_PORT 사용 중. 기존 프로세스 종료...${NC}"
    kill -9 $LSOF_CHECK 2>/dev/null || true
    sleep 1
fi

# 터널링 실행 (Background, 에러 로그 기록)
SSH_LOG="/tmp/ssh_tunnel_error.log"
ssh -i "$PEM_PATH" -o StrictHostKeyChecking=no -o ExitOnForwardFailure=yes -f -N -L $LOCAL_PORT:$RDS_ENDPOINT:5432 $BASTION_USER@$BASTION_IP 2> "$SSH_LOG" || true

# 터널 프로세스 PID 저장
TUNNEL_PID=$(lsof -ti :$LOCAL_PORT)

if [ -z "$TUNNEL_PID" ]; then
    echo -e "${RED}X SSH 터널링 프로세스 생성 실패. 에러 메시지:${NC}"
    cat "$SSH_LOG"
    exit 1
fi

# 정리(Cleanup) 함수 정의
cleanup() {
    if [ -n "$TUNNEL_PID" ]; then
        echo -e "\n${BLUE}SSH 터널링 종료 중 (PID: $TUNNEL_PID)...${NC}"
        kill $TUNNEL_PID 2>/dev/null || true
    fi
}
trap cleanup EXIT

# 연결 대기
sleep 3

# 5. 연결 테스트 (최대 5회 재시도)
echo -e "${BLUE}데이터베이스 연결 테스트 (via Tunnel)...${NC}"
MAX_RETRIES=5
RETRY_COUNT=0
CONNECTED=false
PSQL_OUTPUT="/tmp/psql_error.log"

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    # 에러 메시지를 파일에 기록
    if PGPASSWORD="$DB_PASSWORD" psql -h "localhost" -p "$LOCAL_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1" > /dev/null 2> "$PSQL_OUTPUT"; then
        echo -e "  ${GREEN}✓${NC} 연결 성공"
        CONNECTED=true
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo -e "  대기 중... ($RETRY_COUNT/$MAX_RETRIES)"
        # 5회차 실패 시 실제 에러 내용 출력
        if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
            echo -e "${RED}상세 에러 내용:${NC}"
            cat "$PSQL_OUTPUT"
        fi
        sleep 2
    fi
done

if [ "$CONNECTED" = false ]; then
    echo -e "${RED}X 연결 실패. 터널링 상태를 확인하세요.${NC}"
    exit 1
fi

# 6. SQL 파일 실행
SQL_FILES=(
    "01-schema.sql"
    "02-seed-data.sql"
    "03-matches.sql"
)

for sql_file in "${SQL_FILES[@]}"; do
    echo -e "${BLUE}실행 중: ${sql_file}${NC}"
    if PGPASSWORD="$DB_PASSWORD" psql -h "localhost" -p "$LOCAL_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$SCRIPT_DIR/$sql_file" > /tmp/db-init-output.log 2>&1; then
        echo -e "  ${GREEN}✓${NC} 완료"
    else
        echo -e "  ${RED}✗${NC} 실패"
        cat /tmp/db-init-output.log
        exit 1
    fi
done

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Prod DB 자동 초기화 완료!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
