#!/bin/bash
# ============================================================
# staging/db/db-init.sh
# Staging 환경 DB 초기화 스크립트
#
# 사용법:
#   ./db-init.sh
#
# 사전 준비:
#   1. RDS 엔드포인트로 접근 가능한 상태 (Bastion 또는 port-forward)
#   2. 환경변수 설정 또는 스크립트 내 기본값 수정
#
# 환경변수:
#   DB_HOST     - PostgreSQL 호스트 (기본: localhost)
#   DB_PORT     - PostgreSQL 포트 (기본: 5432)
#   DB_NAME     - 데이터베이스 이름 (기본: playball)
#   DB_USER     - 데이터베이스 사용자 (기본: playball)
#   DB_PASSWORD - 데이터베이스 비밀번호 (필수)
# ============================================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 스크립트 디렉토리
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 환경변수 기본값
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-playball}"
DB_USER="${DB_USER:-playball}"

# 헤더 출력
echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  Staging DB 초기화 스크립트${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""

# DB_PASSWORD 체크
if [ -z "$DB_PASSWORD" ]; then
    echo -e "${YELLOW}DB_PASSWORD 환경변수가 설정되지 않았습니다.${NC}"
    echo -e "${YELLOW}비밀번호를 입력하세요:${NC}"
    read -s DB_PASSWORD
    echo ""
fi

# 연결 정보 출력
echo -e "${BLUE}연결 정보:${NC}"
echo "  Host: $DB_HOST"
echo "  Port: $DB_PORT"
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

# 연결 테스트
echo -e "${BLUE}데이터베이스 연결 테스트...${NC}"
if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1" > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} 연결 성공"
else
    echo -e "  ${RED}✗${NC} 연결 실패"
    echo ""
    echo -e "${YELLOW}확인사항:${NC}"
    echo "  1. RDS가 실행 중인지 확인"
    echo "  2. 보안그룹에서 접근이 허용되어 있는지 확인"
    echo "  3. port-forward가 필요한 경우:"
    echo "     kubectl port-forward svc/postgres 5432:5432 -n database"
    exit 1
fi
echo ""

# 확인 프롬프트
echo -e "${YELLOW}주의: 이 스크립트는 기존 테이블을 삭제하고 다시 생성합니다.${NC}"
echo -e "${YELLOW}계속하시겠습니까? (y/N)${NC}"
read -r confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${RED}취소되었습니다.${NC}"
    exit 0
fi
echo ""

# SQL 파일 실행
for sql_file in "${SQL_FILES[@]}"; do
    echo -e "${BLUE}실행 중: ${sql_file}${NC}"

    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$SCRIPT_DIR/$sql_file" > /tmp/db-init-output.log 2>&1; then
        echo -e "  ${GREEN}✓${NC} 완료"
    else
        echo -e "  ${RED}✗${NC} 실패"
        echo ""
        echo -e "${RED}에러 로그:${NC}"
        cat /tmp/db-init-output.log
        exit 1
    fi
done

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  DB 초기화 완료!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""

# 검증 결과 출력
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
