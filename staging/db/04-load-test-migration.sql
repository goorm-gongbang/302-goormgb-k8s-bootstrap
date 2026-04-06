-- ============================================================
-- Load Test Migration Script
-- 부하테스트를 위한 스키마 변경 및 테이블 추가
-- ============================================================

BEGIN;

-- ============================================================
-- 1. 암호화 대상 컬럼 길이 확장 (AES-256-GCM + Base64 기준)
-- ============================================================

-- users
ALTER TABLE users ALTER COLUMN email TYPE VARCHAR(512);
ALTER TABLE users ALTER COLUMN nickname TYPE VARCHAR(512);

-- orders
ALTER TABLE orders ALTER COLUMN orderer_name TYPE VARCHAR(512);
ALTER TABLE orders ALTER COLUMN orderer_email TYPE VARCHAR(512);
ALTER TABLE orders ALTER COLUMN orderer_phone TYPE VARCHAR(512);
ALTER TABLE orders ALTER COLUMN orderer_birth_date TYPE VARCHAR(512);

-- payments
ALTER TABLE payments ALTER COLUMN account_number TYPE VARCHAR(512);
ALTER TABLE payments ALTER COLUMN account_holder TYPE VARCHAR(512);

-- cash_receipts
ALTER TABLE cash_receipts ALTER COLUMN number TYPE VARCHAR(512);

-- inquiries
ALTER TABLE inquiries ALTER COLUMN phone_number TYPE VARCHAR(512);

-- ============================================================
-- 2. 부하테스트용 테이블 추가
-- ============================================================
CREATE TABLE IF NOT EXISTS load_test_users
(
    id            BIGSERIAL PRIMARY KEY,
    login_id      VARCHAR(50)  NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    user_id       BIGINT       NOT NULL UNIQUE,
    created_at    TIMESTAMP    NOT NULL,
    updated_at    TIMESTAMP    NOT NULL,
    CONSTRAINT fk_load_test_users_user_id FOREIGN KEY (user_id) REFERENCES users (id)
);

-- ============================================================
-- 참고
-- - user_sns.provider_user_id는 암호화 대상 아님 (카카오 로그인 검색용)
-- - 이미 VARCHAR(512)인 컬럼은 ALTER 실행해도 영향 없음 (멱등)
-- ============================================================

COMMIT;
