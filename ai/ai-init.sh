#!/bin/bash
# ============================================================
# ai/ai-init.sh
# AI Defense PostgreSQL 초기화 스크립트 (전 환경 공용)
#
# 사용법:
#   ./ai/ai-init.sh <환경> [bastion-instance-id]
#
# 환경:
#   staging, prod           — 기존 메인계정 (직접 접속)
#   ca-staging, ca-prod     — CA계정 (Bastion SSM 포트포워딩)
#
# 예시:
#   ./ai/ai-init.sh ca-staging i-0f6b0701f82bed9b8
#   ./ai/ai-init.sh staging
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV="${1:-}"
BASTION_ID="${2:-}"

# 환경 확인
if [[ -z "$ENV" ]]; then
    echo -e "${YELLOW}환경을 선택하세요:${NC}"
    echo "  1) staging"
    echo "  2) prod"
    echo "  3) ca-staging"
    echo "  4) ca-prod"
    read -r choice
    case "$choice" in
        1) ENV="staging" ;;
        2) ENV="prod" ;;
        3) ENV="ca-staging" ;;
        4) ENV="ca-prod" ;;
        *) echo -e "${RED}잘못된 선택${NC}"; exit 1 ;;
    esac
fi

# 환경별 설정
case "$ENV" in
    ca-staging)
        IS_CA=true
        SECRET_ID="staging/ai-service/common"
        TF_ENV="staging"
        HEADER="CA Staging"
        ;;
    ca-prod)
        IS_CA=true
        SECRET_ID="prod/ai-service/common"
        TF_ENV="prod"
        HEADER="CA Prod"
        ;;
    staging)
        IS_CA=false
        HEADER="Staging"
        ;;
    prod)
        IS_CA=false
        HEADER="Prod"
        ;;
    *)
        echo -e "${RED}지원하지 않는 환경: $ENV${NC}"
        exit 1
        ;;
esac

AWS_REGION="${AWS_REGION:-ap-northeast-2}"
SSM_PID=""

cleanup() {
    if [[ -n "$SSM_PID" ]]; then
        echo -e "\n${BLUE}SSM 포트포워딩 종료${NC}"
        kill "$SSM_PID" 2>/dev/null || true
        wait "$SSM_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  AI Defense DB 초기화 (${HEADER})${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""

if [[ "$IS_CA" == true ]]; then
    AWS_PROFILE="${AWS_PROFILE:-}"
    if [[ -z "$AWS_PROFILE" ]]; then
        echo -e "${YELLOW}AWS Profile을 입력하세요 (기본: ca):${NC}"
        read -r AWS_PROFILE
        AWS_PROFILE="${AWS_PROFILE:-ca}"
    fi

    if [[ -z "$BASTION_ID" ]]; then
        echo -e "${YELLOW}Bastion Instance ID를 입력하세요:${NC}"
        read -r BASTION_ID
        if [[ -z "$BASTION_ID" ]]; then
            echo -e "${RED}Bastion ID가 필요합니다.${NC}"
            exit 1
        fi
    fi

    # RDS Host (terraform)
    TERRAFORM_DIR="${TERRAFORM_DIR:-$HOME/Documents/GitHub/301-playball-terraform/environments/$TF_ENV}"
    RDS_HOST=""
    if [[ -d "$TERRAFORM_DIR" ]]; then
        echo -e "${BLUE}RDS 주소 감지 중 (terraform output)...${NC}"
        RDS_HOST=$(cd "$TERRAFORM_DIR" && terraform output -json rds 2>/dev/null | jq -r '.address' || echo "")
    fi

    # AI 서비스 DB 정보 (Secrets Manager)
    AI_DB_PASSWORD=""
    AI_DB_USER="ai_defense"
    AI_DB_NAME="ai_defense"
    echo -e "${BLUE}AI DB 정보 조회 중 (Secrets Manager)...${NC}"
    AI_SECRET=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ID" --query 'SecretString' --output text --profile "$AWS_PROFILE" --region "$AWS_REGION" 2>/dev/null || echo "")
    if [[ -n "$AI_SECRET" ]]; then
        AI_DB_PASSWORD=$(echo "$AI_SECRET" | jq -r '.pg_password')
        AI_DB_USER=$(echo "$AI_SECRET" | jq -r '.pg_username // "ai_defense"')
        AI_DB_NAME=$(echo "$AI_SECRET" | jq -r '.pg_dbname // "ai_defense"')
        if [[ -z "$RDS_HOST" ]]; then
            RDS_HOST=$(echo "$AI_SECRET" | jq -r '.pg_host')
        fi
        echo -e "  ${GREEN}✓${NC} AI DB 정보 조회 성공"
    fi

    # Master DB 정보 (DB/유저 생성용)
    MASTER_SECRET_ID="${TF_ENV}/services/db"
    echo -e "${BLUE}Master DB 정보 조회 중 (Secrets Manager)...${NC}"
    MASTER_SECRET=$(aws secretsmanager get-secret-value --secret-id "$MASTER_SECRET_ID" --query 'SecretString' --output text --profile "$AWS_PROFILE" --region "$AWS_REGION" 2>/dev/null || echo "")
    if [[ -n "$MASTER_SECRET" ]]; then
        MASTER_PASSWORD=$(echo "$MASTER_SECRET" | jq -r '.password')
        MASTER_USER=$(echo "$MASTER_SECRET" | jq -r '.username')
        if [[ -z "$RDS_HOST" ]]; then
            RDS_HOST=$(echo "$MASTER_SECRET" | jq -r '.host')
        fi
        echo -e "  ${GREEN}✓${NC} Master DB 정보 조회 성공"
    else
        echo -e "${YELLOW}Master DB 정보 조회 실패. Master 비밀번호를 입력하세요:${NC}"
        read -s MASTER_PASSWORD
        echo ""
        MASTER_USER="${MASTER_USER:-goormgb_admin}"
    fi

    if [[ -z "$AI_DB_PASSWORD" ]]; then
        echo -e "${YELLOW}AI Defense DB 비밀번호를 입력하세요:${NC}"
        read -s AI_DB_PASSWORD
        echo ""
    fi

    if [[ -z "$RDS_HOST" ]]; then
        echo -e "${YELLOW}RDS 주소를 입력하세요:${NC}"
        read -r RDS_HOST
        if [[ -z "$RDS_HOST" ]]; then
            echo -e "${RED}RDS Host가 필요합니다.${NC}"
            exit 1
        fi
    fi

    LOCAL_PORT="${DB_PORT:-15432}"
    DB_HOST="localhost"
    DB_PORT="$LOCAL_PORT"

    # SSM 포트포워딩
    echo ""
    echo -e "${BLUE}SSM 포트포워딩 시작...${NC}"
    aws ssm start-session \
        --target "$BASTION_ID" \
        --document-name AWS-StartPortForwardingSessionToRemoteHost \
        --parameters "host=$RDS_HOST,portNumber=5432,localPortNumber=$LOCAL_PORT" \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" &
    SSM_PID=$!

    # Master로 연결 대기
    echo -e "${BLUE}포트포워딩 연결 대기 중...${NC}"
    for i in {1..15}; do
        if PGPASSWORD="$MASTER_PASSWORD" psql -h localhost -p "$LOCAL_PORT" -U "$MASTER_USER" -d postgres -c "SELECT 1" > /dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} 연결 성공"
            break
        fi
        if [[ $i -eq 15 ]]; then
            echo -e "  ${RED}✗${NC} 포트포워딩 연결 실패 (timeout)"
            exit 1
        fi
        sleep 2
    done

    # ai_defense DB/유저 생성 (master 권한으로)
    echo ""
    echo -e "${BLUE}ai_defense DB/유저 생성 중...${NC}"
    PGPASSWORD="$MASTER_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$MASTER_USER" -d postgres -c "
        DO \$\$
        BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${AI_DB_USER}') THEN
                CREATE ROLE ${AI_DB_USER} WITH LOGIN PASSWORD '${AI_DB_PASSWORD}';
                RAISE NOTICE 'Role ${AI_DB_USER} created';
            ELSE
                RAISE NOTICE 'Role ${AI_DB_USER} already exists';
            END IF;
        END
        \$\$;
    " 2>&1 && echo -e "  ${GREEN}✓${NC} 유저 확인/생성 완료" || echo -e "  ${RED}✗${NC} 유저 생성 실패"

    # DB 생성 (이미 있으면 무시)
    PGPASSWORD="$MASTER_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$MASTER_USER" -d postgres -tc "SELECT 1 FROM pg_database WHERE datname = '${AI_DB_NAME}'" | grep -q 1 || \
        PGPASSWORD="$MASTER_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$MASTER_USER" -d postgres -c "CREATE DATABASE ${AI_DB_NAME} OWNER ${AI_DB_USER};" 2>&1
    echo -e "  ${GREEN}✓${NC} DB 확인/생성 완료"

    PGPASSWORD="$MASTER_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$MASTER_USER" -d "$AI_DB_NAME" -c "GRANT ALL PRIVILEGES ON DATABASE ${AI_DB_NAME} TO ${AI_DB_USER};" > /dev/null 2>&1

    # 이후 SQL은 ai_defense 유저로 실행
    DB_USER="$AI_DB_USER"
    DB_NAME="$AI_DB_NAME"
    DB_PASSWORD="$AI_DB_PASSWORD"
else
    DB_HOST="${DB_HOST:-localhost}"
    DB_PORT="${DB_PORT:-5432}"
    DB_NAME="${DB_NAME:-ai_defense}"
    DB_USER="${DB_USER:-ai_defense}"

    if [[ -z "$DB_PASSWORD" ]]; then
        echo -e "${YELLOW}DB_PASSWORD를 입력하세요:${NC}"
        read -s DB_PASSWORD
        echo ""
    fi

    echo -e "${BLUE}연결 테스트...${NC}"
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} 연결 성공"
    else
        echo -e "  ${RED}✗${NC} 연결 실패"
        exit 1
    fi
fi

echo ""
echo -e "${BLUE}연결 정보:${NC}"
echo "  Host: $DB_HOST:$DB_PORT"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo ""

# SQL 파일
SQL_FILES=(
    "01-postgresql-policy-control-plane.sql"
)

echo -e "${BLUE}실행할 SQL 파일:${NC}"
for sql_file in "${SQL_FILES[@]}"; do
    if [ -f "$SCRIPT_DIR/$sql_file" ]; then
        echo -e "  ${GREEN}✓${NC} $sql_file"
    else
        echo -e "  ${RED}✗${NC} $sql_file (파일 없음)"
        exit 1
    fi
done
echo ""

# SQL 실행
for sql_file in "${SQL_FILES[@]}"; do
    echo -e "${BLUE}실행 중: ${sql_file}${NC}"
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$SCRIPT_DIR/$sql_file" > /tmp/ai-init-output.log 2>&1; then
        echo -e "  ${GREEN}✓${NC} 완료"
    else
        echo -e "  ${RED}✗${NC} 실패"
        echo -e "${RED}에러 로그:${NC}"
        cat /tmp/ai-init-output.log
        exit 1
    fi
done

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  AI Defense DB 초기화 완료! (${HEADER})${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""

echo -e "${BLUE}생성된 테이블:${NC}"
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
"
