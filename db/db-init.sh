#!/bin/bash
# ============================================================
# db/db-init.sh
# DB 초기화 스크립트 (전 환경 공용)
#
# 사용법:
#   ./db/db-init.sh <환경> [bastion-instance-id]
#
# 환경:
#   staging, prod           — 기존 메인계정 (직접 접속)
#   ca-staging, ca-prod     — CA계정 (Bastion SSM 포트포워딩)
#
# 예시:
#   ./db/db-init.sh ca-staging i-0f6b0701f82bed9b8
#   ./db/db-init.sh ca-staging              # Bastion ID 프롬프트
#   ./db/db-init.sh staging                 # 직접 접속 (export 필요)
#
# CA 환경: Secrets Manager + SSM 자동화
# 기존 환경: DB_HOST, DB_USER, DB_PASSWORD 환경변수 필요
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
        SECRET_ID="staging/services/db"
        TF_ENV="staging"
        HEADER="CA Staging"
        ;;
    ca-prod)
        IS_CA=true
        SECRET_ID="prod/services/db"
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
        echo "  사용 가능: staging, prod, ca-staging, ca-prod"
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

# 헤더
echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  ${HEADER} DB 초기화${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""

if [[ "$IS_CA" == true ]]; then
    #############################
    # CA 환경: 자동화
    #############################

    # AWS Profile
    AWS_PROFILE="${AWS_PROFILE:-}"
    if [[ -z "$AWS_PROFILE" ]]; then
        echo -e "${YELLOW}AWS Profile을 입력하세요 (기본: ca):${NC}"
        read -r AWS_PROFILE
        AWS_PROFILE="${AWS_PROFILE:-ca}"
    fi

    # Bastion ID
    if [[ -z "$BASTION_ID" ]]; then
        echo -e "${YELLOW}Bastion Instance ID를 입력하세요:${NC}"
        echo -e "  (확인: aws ec2 describe-instances --filters 'Name=tag:Name,Values=*bastion*' --query 'Reservations[].Instances[].InstanceId' --output text --profile $AWS_PROFILE --region $AWS_REGION)"
        echo ""
        read -r BASTION_ID
        if [[ -z "$BASTION_ID" ]]; then
            echo -e "${RED}Bastion ID가 필요합니다.${NC}"
            exit 1
        fi
    fi

    # RDS Host (terraform output)
    TERRAFORM_DIR="${TERRAFORM_DIR:-$HOME/Documents/GitHub/301-playball-terraform/environments/$TF_ENV}"
    RDS_HOST=""
    if [[ -d "$TERRAFORM_DIR" ]]; then
        echo -e "${BLUE}RDS 주소 감지 중 (terraform output)...${NC}"
        RDS_HOST=$(cd "$TERRAFORM_DIR" && terraform output -json rds 2>/dev/null | jq -r '.address // empty' 2>/dev/null || echo "")
        [[ "$RDS_HOST" == "null" ]] && RDS_HOST=""
    fi

    # DB 정보 (Secrets Manager)
    DB_PASSWORD="${DB_PASSWORD:-}"
    if [[ -z "$DB_PASSWORD" ]]; then
        echo -e "${BLUE}DB 정보 조회 중 (Secrets Manager)...${NC}"
        DB_SECRET=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ID" --query 'SecretString' --output text --profile "$AWS_PROFILE" --region "$AWS_REGION" 2>/dev/null || echo "")
        if [[ -n "$DB_SECRET" ]]; then
            DB_PASSWORD=$(echo "$DB_SECRET" | jq -r '.password')
            DB_USER=$(echo "$DB_SECRET" | jq -r '.username')
            DB_NAME=$(echo "$DB_SECRET" | jq -r '.dbname')
            if [[ -z "$RDS_HOST" ]]; then
                RDS_HOST=$(echo "$DB_SECRET" | jq -r '.host')
            fi
            echo -e "  ${GREEN}✓${NC} DB 정보 조회 성공"
        else
            echo -e "${YELLOW}Secrets Manager 조회 실패. 비밀번호를 입력하세요:${NC}"
            read -s DB_PASSWORD
            echo ""
        fi
    fi

    # RDS Host 최종 확인
    if [[ -z "$RDS_HOST" ]]; then
        echo -e "${YELLOW}RDS 주소를 입력하세요:${NC}"
        read -r RDS_HOST
        if [[ -z "$RDS_HOST" ]]; then
            echo -e "${RED}RDS Host가 필요합니다.${NC}"
            exit 1
        fi
    fi

    DB_USER="${DB_USER:-goormgb_admin}"
    DB_NAME="${DB_NAME:-goormgb}"
    LOCAL_PORT="${DB_PORT:-15432}"
    DB_HOST="localhost"
    DB_PORT="$LOCAL_PORT"

    # SSM 포트포워딩
    echo ""
    echo -e "${BLUE}SSM 포트포워딩 시작...${NC}"
    echo -e "  Bastion: $BASTION_ID"
    echo -e "  RDS:     $RDS_HOST:5432 → localhost:$LOCAL_PORT"
    echo ""

    aws ssm start-session \
        --target "$BASTION_ID" \
        --document-name AWS-StartPortForwardingSessionToRemoteHost \
        --parameters "host=$RDS_HOST,portNumber=5432,localPortNumber=$LOCAL_PORT" \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" &
    SSM_PID=$!

    echo -e "${BLUE}포트포워딩 연결 대기 중...${NC}"
    for i in {1..15}; do
        if PGPASSWORD="$DB_PASSWORD" psql -h localhost -p "$LOCAL_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1" > /dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} 연결 성공"
            break
        fi
        if [[ $i -eq 15 ]]; then
            echo -e "  ${RED}✗${NC} 포트포워딩 연결 실패 (timeout)"
            exit 1
        fi
        sleep 2
    done

else
    #############################
    # 기존 환경: 수동 export
    #############################
    DB_HOST="${DB_HOST:-localhost}"
    DB_PORT="${DB_PORT:-5432}"
    DB_NAME="${DB_NAME:-playball}"
    DB_USER="${DB_USER:-playball}"

    if [[ -z "$DB_PASSWORD" ]]; then
        echo -e "${YELLOW}DB_PASSWORD 환경변수가 설정되지 않았습니다.${NC}"
        echo -e "${YELLOW}비밀번호를 입력하세요:${NC}"
        read -s DB_PASSWORD
        echo ""
    fi

    echo -e "${BLUE}데이터베이스 연결 테스트...${NC}"
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} 연결 성공"
    else
        echo -e "  ${RED}✗${NC} 연결 실패"
        echo -e "${YELLOW}확인: DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME${NC}"
        exit 1
    fi
fi

# 연결 정보
echo ""
echo -e "${BLUE}연결 정보:${NC}"
echo "  Host: $DB_HOST:$DB_PORT"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo ""

# SQL 파일 확인
SQL_FILES=(
    "01-schema.sql"
    "02-seed-data.sql"
    "03-matches.sql"
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

# 확인
echo -e "${YELLOW}주의: 이 스크립트는 기존 테이블을 삭제하고 다시 생성합니다.${NC}"
echo -e "${YELLOW}계속하시겠습니까? (y/N)${NC}"
read -r confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${RED}취소되었습니다.${NC}"
    exit 0
fi
echo ""

# SQL 실행
for sql_file in "${SQL_FILES[@]}"; do
    echo -e "${BLUE}실행 중: ${sql_file}${NC}"
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$SCRIPT_DIR/$sql_file" > /tmp/db-init-output.log 2>&1; then
        echo -e "  ${GREEN}✓${NC} 완료"
    else
        echo -e "  ${RED}✗${NC} 실패"
        echo -e "${RED}에러 로그:${NC}"
        cat /tmp/db-init-output.log
        exit 1
    fi
done

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  ${HEADER} DB 초기화 완료!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""

echo -e "${BLUE}테이블 행 수:${NC}"
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
SELECT 'stadiums' AS tbl, COUNT(*) AS cnt FROM stadiums
UNION ALL SELECT 'clubs', COUNT(*) FROM clubs
UNION ALL SELECT 'areas', COUNT(*) FROM areas
UNION ALL SELECT 'sections', COUNT(*) FROM sections
UNION ALL SELECT 'blocks', COUNT(*) FROM blocks
UNION ALL SELECT 'seats', COUNT(*) FROM seats
UNION ALL SELECT 'matches', COUNT(*) FROM matches
UNION ALL SELECT 'match_seats', COUNT(*) FROM match_seats
UNION ALL SELECT 'price_policies', COUNT(*) FROM price_policies
ORDER BY tbl;
"
