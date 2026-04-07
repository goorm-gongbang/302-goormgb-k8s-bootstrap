#!/bin/bash
# ============================================================
# dev/ai/ai-init.sh
# AI Defense PostgreSQL 초기화 스크립트 (Dev - 클러스터 내부 PG)
#
# 사용법:
#   ./ai-init.sh
#
# 환경변수:
#   DB_HOST     - PostgreSQL 호스트 (기본: localhost, port-forward 사용)
#   DB_PORT     - PostgreSQL 포트 (기본: 5432)
#   DB_NAME     - 데이터베이스 이름 (기본: ai_defense)
#   DB_USER     - 데이터베이스 사용자 (기본: postgres)
#   DB_PASSWORD - 데이터베이스 비밀번호 (필수)
#
# 사전 준비:
#   kubectl port-forward svc/postgresql 5432:5432 -n data
# ============================================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 환경변수 기본값 (dev 클러스터 내부 PostgreSQL)
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-ai_defense}"
DB_USER="${DB_USER:-postgres}"

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  AI Defense DB 초기화 (Dev)${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""

# DB_PASSWORD 체크
if [ -z "$DB_PASSWORD" ]; then
    echo -e "${YELLOW}DB_PASSWORD 환경변수가 설정되지 않았습니다.${NC}"
    echo -e "${YELLOW}비밀번호를 입력하세요:${NC}"
    read -s DB_PASSWORD
    echo ""
fi

echo -e "${BLUE}연결 정보:${NC}"
echo "  Host: $DB_HOST"
echo "  Port: $DB_PORT"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo ""

# SQL 파일 확인
SQL_FILES=(
    "01-postgresql-policy-control-plane.sql"
)

echo -e "${BLUE}실행할 SQL 파일:${NC}"
for sql_file in "${SQL_FILES[@]}"; do
    if [ -f "$SCRIPT_DIR/$sql_file" ]; then
        echo -e "  ${GREEN}O${NC} $sql_file"
    else
        echo -e "  ${RED}X${NC} $sql_file (파일 없음)"
        exit 1
    fi
done
echo ""

# 연결 테스트
echo -e "${BLUE}데이터베이스 연결 테스트...${NC}"
if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1" > /dev/null 2>&1; then
    echo -e "  ${GREEN}O${NC} 연결 성공"
else
    echo -e "  ${RED}X${NC} 연결 실패"
    echo ""
    echo -e "${YELLOW}확인사항:${NC}"
    echo "  1. port-forward 실행: kubectl port-forward svc/postgresql 5432:5432 -n data"
    echo "  2. ai_defense 데이터베이스가 생성되어 있는지 확인"
    echo "     (postgresql values.yaml에 databases: [goormgb, ai_defense] 추가됨)"
    exit 1
fi
echo ""

# SQL 파일 실행
for sql_file in "${SQL_FILES[@]}"; do
    echo -e "${BLUE}실행 중: ${sql_file}${NC}"

    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$SCRIPT_DIR/$sql_file" > /tmp/ai-init-output.log 2>&1; then
        echo -e "  ${GREEN}O${NC} 완료"
    else
        echo -e "  ${RED}X${NC} 실패"
        echo ""
        echo -e "${RED}에러 로그:${NC}"
        cat /tmp/ai-init-output.log
        exit 1
    fi
done

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  AI Defense DB 초기화 완료!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""

# 테이블 확인
echo -e "${BLUE}생성된 테이블:${NC}"
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
"
