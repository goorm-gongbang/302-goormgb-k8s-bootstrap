#!/bin/bash
# ============================================================
# prod/ai/clickhouse-init.sh
# AI Defense ClickHouse 초기화 스크립트 (Prod)
#
# 사용법:
#   ./clickhouse-init.sh
#
# 환경변수:
#   CH_HOST     - ClickHouse 호스트 (기본: localhost, port-forward 사용)
#   CH_PORT     - ClickHouse HTTP 포트 (기본: 8123)
#   CH_USER     - ClickHouse 사용자 (기본: default)
#   CH_PASSWORD - ClickHouse 비밀번호 (기본: clickhouse)
#
# 사전 준비:
#   kubectl port-forward svc/clickhouse 8123:8123 -n data
# ============================================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 환경변수 기본값
CH_HOST="${CH_HOST:-localhost}"
CH_PORT="${CH_PORT:-8123}"
CH_USER="${CH_USER:-default}"
CH_PASSWORD="${CH_PASSWORD:-clickhouse}"

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  AI Defense ClickHouse 초기화 (Prod)${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""

echo -e "${BLUE}연결 정보:${NC}"
echo "  Host: $CH_HOST"
echo "  Port: $CH_PORT"
echo "  User: $CH_USER"
echo ""

# SQL 파일 확인
SQL_FILE="02-clickhouse-observability.sql"

if [ -f "$SCRIPT_DIR/$SQL_FILE" ]; then
    echo -e "  ${GREEN}O${NC} $SQL_FILE"
else
    echo -e "  ${RED}X${NC} $SQL_FILE (파일 없음)"
    exit 1
fi
echo ""

# 연결 테스트
echo -e "${BLUE}ClickHouse 연결 테스트...${NC}"
if curl -s "http://$CH_HOST:$CH_PORT/ping" | grep -q "Ok"; then
    echo -e "  ${GREEN}O${NC} 연결 성공"
else
    echo -e "  ${RED}X${NC} 연결 실패"
    echo ""
    echo -e "${YELLOW}확인사항:${NC}"
    echo "  1. port-forward 실행: kubectl port-forward svc/clickhouse 8123:8123 -n data"
    echo "  2. ClickHouse Pod가 Running 상태인지 확인"
    exit 1
fi
echo ""

# SQL 파일을 구문별로 실행
echo -e "${BLUE}SQL 실행 중: ${SQL_FILE}${NC}"

# 주석 제거하고 구문별로 실행
while IFS= read -r statement; do
    # 빈 줄 건너뛰기
    [ -z "$statement" ] && continue

    echo -e "  실행: ${statement:0:60}..."

    response=$(curl -s -w "\n%{http_code}" \
        --user "$CH_USER:$CH_PASSWORD" \
        "http://$CH_HOST:$CH_PORT/" \
        --data-binary "$statement")

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)

    if [ "$http_code" == "200" ]; then
        echo -e "    ${GREEN}O${NC} 완료"
    else
        echo -e "    ${RED}X${NC} 실패 (HTTP $http_code)"
        echo "$body"
        exit 1
    fi
done < <(grep -v '^--' "$SCRIPT_DIR/$SQL_FILE" | sed 's/;$/;SPLIT/g' | tr -d '\n' | sed 's/;SPLIT/\n/g' | grep -v '^[[:space:]]*$')

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  AI Defense ClickHouse 초기화 완료!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""

# 테이블/뷰 확인
echo -e "${BLUE}생성된 테이블/뷰:${NC}"
curl -s --user "$CH_USER:$CH_PASSWORD" \
    "http://$CH_HOST:$CH_PORT/" \
    --data-binary "SELECT name, engine FROM system.tables WHERE database = 'ai_defense' ORDER BY name FORMAT PrettyCompact"
