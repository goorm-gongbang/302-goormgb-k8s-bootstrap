-- ============================================================
-- staging/01-schema.sql
-- Staging 환경 스키마 초기화 (26개 엔티티 기준)
-- 실행 순서: 1번째
-- ============================================================

BEGIN;

-- ============================================================
-- DROP (CASCADE로 FK 제약조건 포함 삭제, 역순)
-- ============================================================
DROP TABLE IF EXISTS inquiry_answers CASCADE;
DROP TABLE IF EXISTS inquiries CASCADE;
DROP TABLE IF EXISTS cash_receipts CASCADE;
DROP TABLE IF EXISTS qr_tokens CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS order_seats CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS cancellation_fee_policies CASCADE;
DROP TABLE IF EXISTS seat_holds CASCADE;
DROP TABLE IF EXISTS match_seats CASCADE;
DROP TABLE IF EXISTS price_policies CASCADE;
DROP TABLE IF EXISTS seats CASCADE;
DROP TABLE IF EXISTS blocks CASCADE;
DROP TABLE IF EXISTS sections CASCADE;
DROP TABLE IF EXISTS areas CASCADE;
DROP TABLE IF EXISTS onboarding_viewpoint_priorities CASCADE;
DROP TABLE IF EXISTS onboarding_preferred_blocks CASCADE;
DROP TABLE IF EXISTS onboarding_preferences CASCADE;
DROP TABLE IF EXISTS team_season_stats CASCADE;
DROP TABLE IF EXISTS matches CASCADE;
DROP TABLE IF EXISTS clubs CASCADE;
DROP TABLE IF EXISTS stadiums CASCADE;
DROP TABLE IF EXISTS withdrawal_requests CASCADE;
DROP TABLE IF EXISTS load_test_users CASCADE;
DROP TABLE IF EXISTS dev_users CASCADE;
DROP TABLE IF EXISTS user_sns CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- ============================================================
-- stadiums
-- ============================================================
CREATE TABLE stadiums
(
    id         BIGSERIAL PRIMARY KEY,
    region     VARCHAR(50)  NOT NULL,
    ko_name    VARCHAR(100) NOT NULL,
    en_name    VARCHAR(100) NOT NULL,
    address    VARCHAR(255),
    created_at TIMESTAMP    NOT NULL,
    updated_at TIMESTAMP    NOT NULL
);

-- ============================================================
-- clubs
-- ============================================================
CREATE TABLE clubs
(
    id                    BIGSERIAL PRIMARY KEY,
    ko_name               VARCHAR(100) NOT NULL,
    en_name               VARCHAR(100) NOT NULL,
    logo_img              VARCHAR(255),
    club_color            VARCHAR(20),
    stadium_id            BIGINT       NOT NULL,
    homepage_redirect_url VARCHAR(255),
    created_at            TIMESTAMP    NOT NULL,
    updated_at            TIMESTAMP    NOT NULL,
    CONSTRAINT fk_clubs_stadium_id FOREIGN KEY (stadium_id) REFERENCES stadiums (id)
);

-- ============================================================
-- matches
-- ============================================================
CREATE TABLE matches
(
    id           BIGSERIAL PRIMARY KEY,
    match_at     TIMESTAMP   NOT NULL,
    home_club_id BIGINT      NOT NULL,
    away_club_id BIGINT      NOT NULL,
    stadium_id   BIGINT      NOT NULL,
    sale_status  VARCHAR(20) NOT NULL,
    created_at   TIMESTAMP   NOT NULL,
    updated_at   TIMESTAMP   NOT NULL,
    CONSTRAINT fk_matches_home_club_id FOREIGN KEY (home_club_id) REFERENCES clubs (id),
    CONSTRAINT fk_matches_away_club_id FOREIGN KEY (away_club_id) REFERENCES clubs (id),
    CONSTRAINT fk_matches_stadium_id FOREIGN KEY (stadium_id) REFERENCES stadiums (id),
    CONSTRAINT uk_matches_stadium_id_match_at UNIQUE (stadium_id, match_at)
);

-- ============================================================
-- team_season_stats
-- ============================================================
CREATE TABLE team_season_stats
(
    id              BIGSERIAL PRIMARY KEY,
    club_id         BIGINT        NOT NULL,
    season_year     INTEGER       NOT NULL,
    season_ranking  INTEGER,
    wins            INTEGER DEFAULT 0,
    draws           INTEGER DEFAULT 0,
    losses          INTEGER DEFAULT 0,
    win_rate        DECIMAL(5, 3),
    batting_average DECIMAL(5, 3),
    era             DECIMAL(4, 2),
    games_behind    DECIMAL(4, 1),
    created_at      TIMESTAMP     NOT NULL,
    updated_at      TIMESTAMP     NOT NULL,
    CONSTRAINT fk_team_season_stats_club_id FOREIGN KEY (club_id) REFERENCES clubs (id),
    CONSTRAINT uk_team_season_stats_club_season UNIQUE (club_id, season_year)
);

-- ============================================================
-- users
-- ============================================================
CREATE TABLE users
(
    id                      BIGSERIAL PRIMARY KEY,
    status                  VARCHAR(20) NOT NULL DEFAULT 'ACTIVATE',
    email                   VARCHAR(512),
    nickname                VARCHAR(512),
    profile_image_url       VARCHAR(255),
    onboarding_completed    BOOLEAN     NOT NULL DEFAULT false,
    onboarding_completed_at TIMESTAMP,
    last_login_at           TIMESTAMP,
    marketing_consent       BOOLEAN     NOT NULL DEFAULT false,
    marketing_consented_at  TIMESTAMP,
    created_at              TIMESTAMP   NOT NULL,
    updated_at              TIMESTAMP   NOT NULL
);

-- ============================================================
-- user_sns
-- ============================================================
CREATE TABLE user_sns
(
    id               BIGSERIAL PRIMARY KEY,
    user_id          BIGINT       NOT NULL,
    provider         VARCHAR(20)  NOT NULL,
    provider_user_id VARCHAR(128) NOT NULL,
    created_at       TIMESTAMP    NOT NULL,
    updated_at       TIMESTAMP    NOT NULL,
    CONSTRAINT fk_user_sns_user_id FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT uk_user_sns_provider UNIQUE (provider, provider_user_id)
);

CREATE INDEX idx_user_sns_user_id ON user_sns (user_id);

-- ============================================================
-- dev_users
-- ============================================================
CREATE TABLE dev_users
(
    id            BIGSERIAL PRIMARY KEY,
    login_id      VARCHAR(50)  NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    user_id       BIGINT       NOT NULL UNIQUE,
    created_at    TIMESTAMP    NOT NULL,
    updated_at    TIMESTAMP    NOT NULL,
    CONSTRAINT fk_dev_users_user_id FOREIGN KEY (user_id) REFERENCES users (id)
);

-- ============================================================
-- load_test_users
-- ============================================================
CREATE TABLE load_test_users
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
-- withdrawal_requests
-- ============================================================
CREATE TABLE withdrawal_requests
(
    id           BIGSERIAL PRIMARY KEY,
    user_id      BIGINT      NOT NULL UNIQUE,
    requested_at TIMESTAMP   NOT NULL,
    effective_at TIMESTAMP   NOT NULL,
    status       VARCHAR(20) NOT NULL DEFAULT 'REQUESTED',
    cancelled_at TIMESTAMP,
    created_at   TIMESTAMP   NOT NULL,
    CONSTRAINT fk_withdrawal_requests_user_id FOREIGN KEY (user_id) REFERENCES users (id)
);

CREATE INDEX idx_withdrawal_requests_effective_at ON withdrawal_requests (effective_at);

-- ============================================================
-- onboarding_preferences
-- ============================================================
CREATE TABLE onboarding_preferences
(
    id                      BIGSERIAL PRIMARY KEY,
    user_id                 BIGINT      NOT NULL,
    favorite_club_id        BIGINT      NOT NULL,
    cheer_proximity_pref    VARCHAR(20) NOT NULL DEFAULT 'ANY',
    seat_height             VARCHAR(20) NOT NULL DEFAULT 'ANY',
    section                 VARCHAR(20) NOT NULL DEFAULT 'ANY',
    seat_position_pref      VARCHAR(20) NOT NULL DEFAULT 'ANY',
    environment_pref        VARCHAR(20) NOT NULL DEFAULT 'ANY',
    mood_pref               VARCHAR(20) NOT NULL DEFAULT 'ANY',
    obstruction_sensitivity VARCHAR(30) NOT NULL DEFAULT 'NORMAL',
    price_mode              VARCHAR(20) NOT NULL DEFAULT 'ANY',
    price_min               INTEGER,
    price_max               INTEGER,
    created_at              TIMESTAMP   NOT NULL,
    updated_at              TIMESTAMP   NOT NULL,
    CONSTRAINT fk_onboarding_preferences_user_id FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_onboarding_preferences_favorite_club_id FOREIGN KEY (favorite_club_id) REFERENCES clubs (id),
    CONSTRAINT uk_onboarding_preferences_user_id UNIQUE (user_id)
);

CREATE INDEX idx_onboarding_preferences_user_id ON onboarding_preferences (user_id);
CREATE INDEX idx_onboarding_preferences_favorite_club_id ON onboarding_preferences (favorite_club_id);

-- ============================================================
-- onboarding_preferred_blocks
-- ============================================================
CREATE TABLE onboarding_preferred_blocks
(
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT    NOT NULL,
    block_id   BIGINT    NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    CONSTRAINT fk_onboarding_preferred_blocks_user_id FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT uk_onboarding_preferred_blocks_user_block UNIQUE (user_id, block_id)
);

CREATE INDEX idx_onboarding_preferred_blocks_user_id ON onboarding_preferred_blocks (user_id);
CREATE INDEX idx_onboarding_preferred_blocks_block_id ON onboarding_preferred_blocks (block_id);

-- ============================================================
-- onboarding_viewpoint_priorities
-- ============================================================
CREATE TABLE onboarding_viewpoint_priorities
(
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT      NOT NULL,
    priority   INTEGER     NOT NULL,
    viewpoint  VARCHAR(30) NOT NULL,
    created_at TIMESTAMP   NOT NULL,
    updated_at TIMESTAMP   NOT NULL,
    CONSTRAINT fk_onboarding_viewpoint_priorities_user_id FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT uk_viewpoint_priority_user_id_priority UNIQUE (user_id, priority),
    CONSTRAINT uk_viewpoint_priority_user_id_viewpoint UNIQUE (user_id, viewpoint)
);

CREATE INDEX idx_viewpoint_priority_user_id ON onboarding_viewpoint_priorities (user_id);

-- ============================================================
-- areas
-- ============================================================
CREATE TABLE areas
(
    id         BIGSERIAL PRIMARY KEY,
    code       VARCHAR(50)  NOT NULL,
    name       VARCHAR(100) NOT NULL,
    created_at TIMESTAMP    NOT NULL,
    updated_at TIMESTAMP    NOT NULL,
    CONSTRAINT uk_area_code UNIQUE (code)
);

-- ============================================================
-- sections
-- ============================================================
CREATE TABLE sections
(
    id         BIGSERIAL PRIMARY KEY,
    area_id    BIGINT      NOT NULL,
    code       VARCHAR(30) NOT NULL,
    name       VARCHAR(50) NOT NULL,
    created_at TIMESTAMP   NOT NULL,
    updated_at TIMESTAMP   NOT NULL,
    CONSTRAINT fk_sections_area_id FOREIGN KEY (area_id) REFERENCES areas (id),
    CONSTRAINT uk_section_area_code UNIQUE (area_id, code)
);

CREATE INDEX idx_section_area_id ON sections (area_id);

-- ============================================================
-- blocks
-- ============================================================
CREATE TABLE blocks
(
    id              BIGSERIAL PRIMARY KEY,
    area_id         BIGINT      NOT NULL,
    section_id      BIGINT      NOT NULL,
    block_code      VARCHAR(20) NOT NULL,
    viewpoint       VARCHAR(30) NOT NULL,
    home_cheer_rank INTEGER,
    away_cheer_rank INTEGER,
    created_at      TIMESTAMP   NOT NULL,
    updated_at      TIMESTAMP   NOT NULL,
    CONSTRAINT fk_blocks_area_id FOREIGN KEY (area_id) REFERENCES areas (id),
    CONSTRAINT fk_blocks_section_id FOREIGN KEY (section_id) REFERENCES sections (id),
    CONSTRAINT uk_block_section_code UNIQUE (section_id, block_code),
    CONSTRAINT uk_block_num UNIQUE (block_num)
);

CREATE INDEX idx_block_section_id ON blocks (section_id);
CREATE INDEX idx_block_area_id ON blocks (area_id);
CREATE INDEX idx_block_num ON blocks (block_num);
CREATE INDEX idx_block_viewpoint ON blocks (viewpoint);
CREATE INDEX idx_block_home_cheer_rank ON blocks (home_cheer_rank);
CREATE INDEX idx_block_away_cheer_rank ON blocks (away_cheer_rank);

-- ============================================================
-- seats
-- ============================================================
CREATE TABLE seats
(
    id               BIGSERIAL PRIMARY KEY,
    block_id         BIGINT      NOT NULL,
    row_no           INTEGER     NOT NULL,
    seat_no          INTEGER     NOT NULL,
    template_col_no  INTEGER     NOT NULL,
    seat_zone        VARCHAR(10) NOT NULL,
    created_at       TIMESTAMP   NOT NULL,
    updated_at       TIMESTAMP   NOT NULL,
    CONSTRAINT fk_seats_block_id FOREIGN KEY (block_id) REFERENCES blocks (id),
    CONSTRAINT uk_seat_block_row_seat UNIQUE (block_id, row_no, seat_no),
    CONSTRAINT uk_seat_block_row_template_col UNIQUE (block_id, row_no, template_col_no)
);

CREATE INDEX idx_seat_block_id ON seats (block_id);
CREATE INDEX idx_seat_block_seat_zone ON seats (block_id, seat_zone);

-- ============================================================
-- match_seats
-- ============================================================
CREATE TABLE match_seats
(
    id              BIGSERIAL PRIMARY KEY,
    match_id        BIGINT      NOT NULL,
    seat_id         BIGINT      NOT NULL,
    area_id         BIGINT      NOT NULL,
    section_id      BIGINT      NOT NULL,
    block_id        BIGINT      NOT NULL,
    row_no          INTEGER     NOT NULL,
    seat_no         INTEGER     NOT NULL,
    template_col_no INTEGER     NOT NULL,
    seat_zone       VARCHAR(10) NOT NULL,
    sale_status     VARCHAR(20) NOT NULL,
    created_at      TIMESTAMP   NOT NULL,
    updated_at      TIMESTAMP   NOT NULL,
    CONSTRAINT uk_match_seats_match_id_seat_id UNIQUE (match_id, seat_id)
);

CREATE INDEX idx_match_seats_match_id ON match_seats (match_id);
CREATE INDEX idx_match_seats_match_id_block_id_row_no_seat_no ON match_seats (match_id, block_id, row_no, seat_no);
CREATE INDEX idx_match_seats_match_id_block_id_row_no_template_col_no ON match_seats (match_id, block_id, row_no, template_col_no);
CREATE INDEX idx_match_seats_match_id_block_id_sale_status_row_no_seat_no ON match_seats (match_id, block_id, sale_status, row_no, seat_no);
CREATE INDEX idx_match_seats_match_id_section_id_sale_status_seat_zone ON match_seats (match_id, section_id, sale_status, seat_zone);

-- ============================================================
-- seat_holds
-- ============================================================
CREATE TABLE seat_holds
(
    id            BIGSERIAL PRIMARY KEY,
    match_seat_id BIGINT    NOT NULL,
    match_id      BIGINT    NOT NULL,
    seat_id       BIGINT    NOT NULL,
    user_id       BIGINT    NOT NULL,
    expires_at    TIMESTAMP NOT NULL,
    created_at    TIMESTAMP NOT NULL,
    updated_at    TIMESTAMP NOT NULL,
    CONSTRAINT uk_seat_holds_match_seat_id UNIQUE (match_seat_id)
);

CREATE INDEX idx_seat_holds_match_id ON seat_holds (match_id);
CREATE INDEX idx_seat_holds_user_id ON seat_holds (user_id);
CREATE INDEX idx_seat_holds_expires_at ON seat_holds (expires_at);

-- ============================================================
-- price_policies
-- ============================================================
CREATE TABLE price_policies
(
    id          BIGSERIAL PRIMARY KEY,
    section_id  BIGINT      NOT NULL,
    day_type    VARCHAR(20) NOT NULL,
    ticket_type VARCHAR(30) NOT NULL,
    price       INTEGER     NOT NULL,
    created_at  TIMESTAMP   NOT NULL,
    updated_at  TIMESTAMP   NOT NULL,
    CONSTRAINT uk_price_policies_section_id_day_type_ticket_type UNIQUE (section_id, day_type, ticket_type)
);

CREATE INDEX idx_price_policies_section_id ON price_policies (section_id);

-- ============================================================
-- orders
-- ============================================================
CREATE TABLE orders
(
    id                 BIGSERIAL PRIMARY KEY,
    user_id            BIGINT      NOT NULL,
    match_id           BIGINT      NOT NULL,
    status             VARCHAR(30) NOT NULL,
    total_amount       INTEGER     NOT NULL,
    booking_fee        INTEGER     NOT NULL DEFAULT 2000,
    cancellation_fee   INTEGER     NOT NULL,
    refunded_amount    INTEGER,
    cancelled_at       TIMESTAMP,
    orderer_name       VARCHAR(512) NOT NULL,
    orderer_email      VARCHAR(512) NOT NULL,
    orderer_phone      VARCHAR(512) NOT NULL,
    orderer_birth_date VARCHAR(512) NOT NULL,
    created_at         TIMESTAMP   NOT NULL,
    updated_at         TIMESTAMP   NOT NULL,
    CONSTRAINT fk_orders_user_id FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_orders_match_id FOREIGN KEY (match_id) REFERENCES matches (id)
);

CREATE INDEX idx_orders_user_id ON orders (user_id);
CREATE INDEX idx_orders_match_id ON orders (match_id);
CREATE INDEX idx_orders_user_id_status ON orders (user_id, status);
CREATE INDEX idx_orders_user_id_created_at ON orders (user_id, created_at);
CREATE INDEX idx_orders_status ON orders (status);

-- ============================================================
-- order_seats
-- ============================================================
CREATE TABLE order_seats
(
    id            BIGSERIAL PRIMARY KEY,
    order_id      BIGINT      NOT NULL,
    match_seat_id BIGINT      NOT NULL,
    block_id      BIGINT      NOT NULL,
    section_id    BIGINT      NOT NULL,
    row_no        INTEGER     NOT NULL,
    seat_no       INTEGER     NOT NULL,
    price         INTEGER     NOT NULL,
    ticket_type   VARCHAR(30) NOT NULL,
    created_at    TIMESTAMP   NOT NULL,
    updated_at    TIMESTAMP   NOT NULL,
    CONSTRAINT fk_order_seats_order_id FOREIGN KEY (order_id) REFERENCES orders (id),
    CONSTRAINT uk_order_seats_match_seat_id UNIQUE (match_seat_id)
);

CREATE INDEX idx_order_seats_order_id ON order_seats (order_id);

-- ============================================================
-- payments
-- ============================================================
CREATE TABLE payments
(
    id               BIGSERIAL PRIMARY KEY,
    order_id         BIGINT      NOT NULL UNIQUE,
    payment_method   VARCHAR(30) NOT NULL,
    status           VARCHAR(30) NOT NULL,
    paid_at          TIMESTAMP,
    account_bank     VARCHAR(50),
    account_number   VARCHAR(512),
    account_holder   VARCHAR(512),
    deposit_deadline TIMESTAMP,
    created_at       TIMESTAMP   NOT NULL,
    updated_at       TIMESTAMP   NOT NULL,
    CONSTRAINT fk_payments_order_id FOREIGN KEY (order_id) REFERENCES orders (id),
    CONSTRAINT uk_payments_order_id UNIQUE (order_id)
);

CREATE INDEX idx_payments_status ON payments (status);

-- ============================================================
-- cash_receipts
-- ============================================================
CREATE TABLE cash_receipts
(
    id         BIGSERIAL PRIMARY KEY,
    payment_id BIGINT      NOT NULL UNIQUE,
    purpose    VARCHAR(30) NOT NULL,
    number     VARCHAR(512) NOT NULL,
    created_at TIMESTAMP   NOT NULL,
    updated_at TIMESTAMP   NOT NULL,
    CONSTRAINT fk_cash_receipts_payment_id FOREIGN KEY (payment_id) REFERENCES payments (id),
    CONSTRAINT uk_cash_receipts_payment_id UNIQUE (payment_id)
);

-- ============================================================
-- qr_tokens
-- ============================================================
CREATE TABLE qr_tokens
(
    id         BIGSERIAL PRIMARY KEY,
    order_id   BIGINT       NOT NULL,
    user_id    BIGINT       NOT NULL,
    qr_token   VARCHAR(512) NOT NULL UNIQUE,
    expires_at TIMESTAMP    NOT NULL,
    created_at TIMESTAMP    NOT NULL,
    updated_at TIMESTAMP    NOT NULL,
    CONSTRAINT fk_qr_tokens_order_id FOREIGN KEY (order_id) REFERENCES orders (id),
    CONSTRAINT fk_qr_tokens_user_id FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT uk_qr_tokens_qr_token UNIQUE (qr_token)
);

CREATE INDEX idx_qr_tokens_order_id ON qr_tokens (order_id);
CREATE INDEX idx_qr_tokens_user_id ON qr_tokens (user_id);
CREATE INDEX idx_qr_tokens_expires_at ON qr_tokens (expires_at);

-- ============================================================
-- cancellation_fee_policies
-- ============================================================
CREATE TABLE cancellation_fee_policies
(
    id                     BIGSERIAL PRIMARY KEY,
    days_before_match_min  INTEGER        NOT NULL,
    days_before_match_max  INTEGER,
    cancellable            BOOLEAN        NOT NULL,
    ticket_fee_rate        DECIMAL(5, 3)  NOT NULL,
    booking_fee_refundable BOOLEAN        NOT NULL,
    created_at             TIMESTAMP      NOT NULL,
    updated_at             TIMESTAMP      NOT NULL
);

-- ============================================================
-- inquiries
-- ============================================================
CREATE TABLE inquiries
(
    id           BIGSERIAL PRIMARY KEY,
    user_id      BIGINT      NOT NULL,
    category     VARCHAR(30) NOT NULL,
    title        VARCHAR(200) NOT NULL,
    content      TEXT        NOT NULL,
    status       VARCHAR(20) NOT NULL,
    phone_number VARCHAR(512),
    created_at   TIMESTAMP   NOT NULL,
    updated_at   TIMESTAMP   NOT NULL,
    CONSTRAINT fk_inquiries_user_id FOREIGN KEY (user_id) REFERENCES users (id)
);

CREATE INDEX idx_inquiries_user_id ON inquiries (user_id);
CREATE INDEX idx_inquiries_user_id_created_at ON inquiries (user_id, created_at);
CREATE INDEX idx_inquiries_status ON inquiries (status);

-- ============================================================
-- inquiry_answers
-- ============================================================
CREATE TABLE inquiry_answers
(
    id          BIGSERIAL PRIMARY KEY,
    inquiry_id  BIGINT    NOT NULL UNIQUE,
    content     TEXT      NOT NULL,
    answered_at TIMESTAMP NOT NULL,
    created_at  TIMESTAMP NOT NULL,
    updated_at  TIMESTAMP NOT NULL,
    CONSTRAINT fk_inquiry_answers_inquiry_id FOREIGN KEY (inquiry_id) REFERENCES inquiries (id),
    CONSTRAINT uk_inquiry_answers_inquiry_id UNIQUE (inquiry_id)
);

COMMIT;
