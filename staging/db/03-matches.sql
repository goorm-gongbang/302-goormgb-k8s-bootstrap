-- ============================================================
-- staging/03-matches.sql
-- Staging 환경 경기 일정 데이터
-- 실행 순서: 3번째 (02-seed-data.sql 이후)
--
-- 시간: UTC 기준 (KST -9시간)
--   KST 14:00 → UTC 05:00
--   KST 17:00 → UTC 08:00
--   KST 18:30 → UTC 09:30
--
-- 4/15 경기까지: ON_SALE
-- 4/15 이후:     UPCOMING
--
-- 구단 ID: 1=두산, 2=삼성, 3=키움, 4=한화, 5=롯데, 6=LG, 7=NC, 8=SSG, 9=kt, 10=KIA
-- 구장 ID: 1=잠실, 2=문학, 3=대구, 4=창원, 5=대전, 6=사직, 7=수원, 8=광주, 9=고척
-- ============================================================

BEGIN;

-- ============================================================
-- 기존 경기 데이터 정리 (match_seats → matches 순서로 삭제)
-- ============================================================
DELETE FROM match_seats;
DELETE FROM matches;

-- ============================================================
-- 3/28 (토) 14:00 KST = 05:00 UTC — ENDED
-- ============================================================
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-03-28 05:00:00', 6,  9,  1, 'ENDED', NOW(), NOW()),  -- LG vs kt @ 잠실
                                                                                                                ('2026-03-28 05:00:00', 8,  10, 2, 'ENDED', NOW(), NOW()),  -- SSG vs KIA @ 문학
                                                                                                                ('2026-03-28 05:00:00', 2,  5,  3, 'ENDED', NOW(), NOW()),  -- 삼성 vs 롯데 @ 대구
                                                                                                                ('2026-03-28 05:00:00', 7,  1,  4, 'ENDED', NOW(), NOW()),  -- NC vs 두산 @ 창원
                                                                                                                ('2026-03-28 05:00:00', 4,  3,  5, 'ENDED', NOW(), NOW());  -- 한화 vs 키움 @ 대전

-- ============================================================
-- 3/29 (일) 14:00 KST = 05:00 UTC — ENDED
-- ============================================================
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-03-29 05:00:00', 6,  9,  1, 'ENDED', NOW(), NOW()),  -- LG vs kt @ 잠실
                                                                                                                ('2026-03-29 05:00:00', 8,  10, 2, 'ENDED', NOW(), NOW()),  -- SSG vs KIA @ 문학
                                                                                                                ('2026-03-29 05:00:00', 2,  5,  3, 'ENDED', NOW(), NOW()),  -- 삼성 vs 롯데 @ 대구
                                                                                                                ('2026-03-29 05:00:00', 7,  1,  4, 'ENDED', NOW(), NOW()),  -- NC vs 두산 @ 창원
                                                                                                                ('2026-03-29 05:00:00', 4,  3,  5, 'ENDED', NOW(), NOW());  -- 한화 vs 키움 @ 대전

-- ============================================================
-- 3/31 (화) 18:30 KST = 09:30 UTC — ENDED
-- ============================================================
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-03-31 09:30:00', 6,  10, 1, 'ENDED', NOW(), NOW()),  -- LG vs KIA @ 잠실
                                                                                                                ('2026-03-31 09:30:00', 8,  3,  2, 'ENDED', NOW(), NOW()),  -- SSG vs 키움 @ 문학
                                                                                                                ('2026-03-31 09:30:00', 2,  1,  3, 'ENDED', NOW(), NOW()),  -- 삼성 vs 두산 @ 대구
                                                                                                                ('2026-03-31 09:30:00', 7,  5,  4, 'ENDED', NOW(), NOW()),  -- NC vs 롯데 @ 창원
                                                                                                                ('2026-03-31 09:30:00', 4,  9,  5, 'ENDED', NOW(), NOW());  -- 한화 vs kt @ 대전

-- ============================================================
-- 4/1 (수) 18:30 KST = 09:30 UTC — ENDED
-- ============================================================
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-04-01 09:30:00', 6,  10, 1, 'ENDED', NOW(), NOW()),
                                                                                                                ('2026-04-01 09:30:00', 8,  3,  2, 'ENDED', NOW(), NOW()),
                                                                                                                ('2026-04-01 09:30:00', 2,  1,  3, 'ENDED', NOW(), NOW()),
                                                                                                                ('2026-04-01 09:30:00', 7,  5,  4, 'ENDED', NOW(), NOW()),
                                                                                                                ('2026-04-01 09:30:00', 4,  9,  5, 'ENDED', NOW(), NOW());

-- ============================================================
-- 4/2 (목) 18:30 KST = 09:30 UTC — ENDED
-- ============================================================
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-04-02 09:30:00', 6,  10, 1, 'ENDED', NOW(), NOW()),
                                                                                                                ('2026-04-02 09:30:00', 8,  3,  2, 'ENDED', NOW(), NOW()),
                                                                                                                ('2026-04-02 09:30:00', 2,  1,  3, 'ENDED', NOW(), NOW()),
                                                                                                                ('2026-04-02 09:30:00', 7,  5,  4, 'ENDED', NOW(), NOW()),
                                                                                                                ('2026-04-02 09:30:00', 4,  9,  5, 'ENDED', NOW(), NOW());

-- ============================================================
-- 4/3 (금) 18:30 KST = 09:30 UTC — UPCOMING
-- ============================================================
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-04-03 09:30:00', 1,  4,  1, 'ENDED', NOW(), NOW()),  -- 두산 vs 한화 @ 잠실
                                                                                                                ('2026-04-03 09:30:00', 5,  8,  6, 'ENDED', NOW(), NOW()),  -- 롯데 vs SSG @ 사직
                                                                                                                ('2026-04-03 09:30:00', 9,  2,  7, 'ENDED', NOW(), NOW()),  -- kt vs 삼성 @ 수원
                                                                                                                ('2026-04-03 09:30:00', 10, 7,  8, 'ENDED', NOW(), NOW()),  -- KIA vs NC @ 광주
                                                                                                                ('2026-04-03 09:30:00', 3,  6,  9, 'ENDED', NOW(), NOW());  -- 키움 vs LG @ 고척

-- ============================================================
-- 4/4 (토) 17:00 KST = 08:00 UTC — UPCOMING
-- ============================================================
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-04-04 08:00:00', 1,  4,  1, 'ENDED', NOW(), NOW()),
                                                                                                                ('2026-04-04 08:00:00', 5,  8,  6, 'ENDED', NOW(), NOW()),
                                                                                                                ('2026-04-04 08:00:00', 9,  2,  7, 'ENDED', NOW(), NOW()),
                                                                                                                ('2026-04-04 08:00:00', 10, 7,  8, 'ENDED', NOW(), NOW()),
                                                                                                                ('2026-04-04 08:00:00', 3,  6,  9, 'ENDED', NOW(), NOW());

-- ============================================================
-- 4/5 (일) 14:00 KST = 05:00 UTC — UPCOMING
-- ============================================================
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-04-05 05:00:00', 1,  4,  1, 'ENDED', NOW(), NOW()),
                                                                                                                ('2026-04-05 05:00:00', 5,  8,  6, 'ENDED', NOW(), NOW()),
                                                                                                                ('2026-04-05 05:00:00', 9,  2,  7, 'ENDED', NOW(), NOW()),
                                                                                                                ('2026-04-05 05:00:00', 10, 7,  8, 'ENDED', NOW(), NOW()),
                                                                                                                ('2026-04-05 05:00:00', 3,  6,  9, 'ENDED', NOW(), NOW());

-- ============================================================
-- 4/7 (화) 18:30 KST = 09:30 UTC — UPCOMING
-- ============================================================
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-04-07 09:30:00', 1,  3,  1, 'ENDED', NOW(), NOW()),  -- 두산 vs 키움 @ 잠실
                                                                                                                ('2026-04-07 09:30:00', 8,  4,  2, 'ENDED', NOW(), NOW()),  -- SSG vs 한화 @ 문학
                                                                                                                ('2026-04-07 09:30:00', 5,  9,  6, 'ENDED', NOW(), NOW()),  -- 롯데 vs kt @ 사직
                                                                                                                ('2026-04-07 09:30:00', 7,  6,  4, 'ENDED', NOW(), NOW()),  -- NC vs LG @ 창원
                                                                                                                ('2026-04-07 09:30:00', 10, 2,  8, 'ENDED', NOW(), NOW());  -- KIA vs 삼성 @ 광주

-- ============================================================
-- 4/8 (수) 18:30 KST = 09:30 UTC — UPCOMING
-- ============================================================
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-04-08 09:30:00', 1,  3,  1, 'ENDED', NOW(), NOW()),
                                                                                                                ('2026-04-08 09:30:00', 8,  4,  2, 'ENDED', NOW(), NOW()),
                                                                                                                ('2026-04-08 09:30:00', 5,  9,  6, 'ENDED', NOW(), NOW()),
                                                                                                                ('2026-04-08 09:30:00', 7,  6,  4, 'ENDED', NOW(), NOW()),
                                                                                                                ('2026-04-08 09:30:00', 10, 2,  8, 'ENDED', NOW(), NOW());

-- ============================================================
-- 4/9 (목) 18:30 KST = 09:30 UTC — UPCOMING
-- ============================================================
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-04-09 09:30:00', 1,  3,  1, 'ON_SALE', NOW(), NOW()),
                                                                                                                ('2026-04-09 09:30:00', 8,  4,  2, 'ON_SALE', NOW(), NOW()),
                                                                                                                ('2026-04-09 09:30:00', 5,  9,  6, 'ON_SALE', NOW(), NOW()),
                                                                                                                ('2026-04-09 09:30:00', 7,  6,  4, 'ON_SALE', NOW(), NOW()),
                                                                                                                ('2026-04-09 09:30:00', 10, 2,  8, 'ON_SALE', NOW(), NOW());

-- ============================================================
-- 4/10 (금) 18:30 KST = 09:30 UTC — UPCOMING
-- ============================================================
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-04-10 09:30:00', 6,  8,  1, 'ON_SALE', NOW(), NOW()),  -- LG vs SSG @ 잠실
                                                                                                                ('2026-04-10 09:30:00', 2,  7,  3, 'ON_SALE', NOW(), NOW()),  -- 삼성 vs NC @ 대구
                                                                                                                ('2026-04-10 09:30:00', 9,  1,  7, 'ON_SALE', NOW(), NOW()),  -- kt vs 두산 @ 수원
                                                                                                                ('2026-04-10 09:30:00', 3,  5,  9, 'ON_SALE', NOW(), NOW()),  -- 키움 vs 롯데 @ 고척
                                                                                                                ('2026-04-10 09:30:00', 4,  10, 5, 'ON_SALE', NOW(), NOW());  -- 한화 vs KIA @ 대전

-- ============================================================
-- 4/11 ~ 9/6 경기 (UPCOMING) - 축약
-- ============================================================

-- 4/11 (토) 17:00 KST = 08:00 UTC
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-04-11 08:00:00', 6,  8,  1, 'ON_SALE', NOW(), NOW()),
                                                                                                                ('2026-04-11 08:00:00', 2,  7,  3, 'ON_SALE', NOW(), NOW()),
                                                                                                                ('2026-04-11 08:00:00', 9,  1,  7, 'ON_SALE', NOW(), NOW()),
                                                                                                                ('2026-04-11 08:00:00', 3,  5,  9, 'ON_SALE', NOW(), NOW()),
                                                                                                                ('2026-04-11 08:00:00', 4,  10, 5, 'ON_SALE', NOW(), NOW());

-- 4/12 (일) 14:00 KST = 05:00 UTC
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-04-12 05:00:00', 6,  8,  1, 'ON_SALE', NOW(), NOW()),
                                                                                                                ('2026-04-12 05:00:00', 2,  7,  3, 'ON_SALE', NOW(), NOW()),
                                                                                                                ('2026-04-12 05:00:00', 9,  1,  7, 'ON_SALE', NOW(), NOW()),
                                                                                                                ('2026-04-12 05:00:00', 3,  5,  9, 'ON_SALE', NOW(), NOW()),
                                                                                                                ('2026-04-12 05:00:00', 4,  10, 5, 'ON_SALE', NOW(), NOW());

-- 4/14 (화) 18:30 KST = 09:30 UTC
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-04-14 09:30:00', 6,  5,  1, 'ON_SALE', NOW(), NOW()),
                                                                                                                ('2026-04-14 09:30:00', 8,  1,  2, 'ON_SALE', NOW(), NOW()),
                                                                                                                ('2026-04-14 09:30:00', 7,  9,  4, 'ON_SALE', NOW(), NOW()),
                                                                                                                ('2026-04-14 09:30:00', 10, 3,  8, 'ON_SALE', NOW(), NOW()),
                                                                                                                ('2026-04-14 09:30:00', 4,  2,  5, 'ON_SALE', NOW(), NOW());ON_SALE
-- 4/15 ~ 4/16
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-04-15 09:30:00', 6,  5,  1, 'ON_SALE', NOW(), NOW()),
                                                                                                                ('2026-04-15 09:30:00', 8,  1,  2, 'ON_SALE', NOW(), NOW()),
                                                                                                                ('2026-04-15 09:30:00', 7,  9,  4, 'ON_SALE', NOW(), NOW()),
                                                                                                                ('2026-04-15 09:30:00', 10, 3,  8, 'ON_SALE', NOW(), NOW()),
                                                                                                                ('2026-04-15 09:30:00', 4,  2,  5, 'ON_SALE', NOW(), NOW()),
                                                                                                                ('2026-04-16 09:30:00', 6,  5,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-16 09:30:00', 8,  1,  2, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-16 09:30:00', 7,  9,  4, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-16 09:30:00', 10, 3,  8, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-16 09:30:00', 4,  2,  5, 'UPCOMING', NOW(), NOW());

-- 4/17 (금) ~ 4/19 (일)
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-04-17 09:30:00', 1,  10, 1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-17 09:30:00', 5,  4,  6, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-17 09:30:00', 2,  6,  3, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-17 09:30:00', 7,  8,  4, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-17 09:30:00', 9,  3,  7, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-18 08:00:00', 1,  10, 1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-18 08:00:00', 5,  4,  6, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-18 08:00:00', 2,  6,  3, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-18 08:00:00', 7,  8,  4, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-18 08:00:00', 9,  3,  7, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-19 05:00:00', 1,  10, 1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-19 05:00:00', 5,  4,  6, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-19 05:00:00', 2,  6,  3, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-19 05:00:00', 7,  8,  4, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-19 05:00:00', 9,  3,  7, 'UPCOMING', NOW(), NOW());

-- 4/21 ~ 4/23
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-04-21 09:30:00', 6,  4,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-21 09:30:00', 5,  1,  6, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-21 09:30:00', 2,  8,  3, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-21 09:30:00', 9,  10, 7, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-21 09:30:00', 3,  7,  9, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-22 09:30:00', 6,  4,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-22 09:30:00', 5,  1,  6, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-22 09:30:00', 2,  8,  3, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-22 09:30:00', 9,  10, 7, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-22 09:30:00', 3,  7,  9, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-23 09:30:00', 6,  4,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-23 09:30:00', 5,  1,  6, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-23 09:30:00', 2,  8,  3, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-23 09:30:00', 9,  10, 7, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-23 09:30:00', 3,  7,  9, 'UPCOMING', NOW(), NOW());

-- 4/24 ~ 4/26
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-04-24 09:30:00', 1,  6,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-24 09:30:00', 8,  9,  2, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-24 09:30:00', 10, 5,  8, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-24 09:30:00', 3,  2,  9, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-24 09:30:00', 4,  7,  5, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-25 08:00:00', 1,  6,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-25 08:00:00', 8,  9,  2, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-25 08:00:00', 10, 5,  8, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-25 08:00:00', 3,  2,  9, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-25 08:00:00', 4,  7,  5, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-26 05:00:00', 1,  6,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-26 05:00:00', 8,  9,  2, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-26 05:00:00', 10, 5,  8, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-26 05:00:00', 3,  2,  9, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-26 05:00:00', 4,  7,  5, 'UPCOMING', NOW(), NOW());

-- 4/28 ~ 4/30
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-04-28 09:30:00', 1,  2,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-28 09:30:00', 5,  3,  6, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-28 09:30:00', 7,  10, 4, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-28 09:30:00', 9,  6,  7, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-28 09:30:00', 4,  8,  5, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-29 09:30:00', 1,  2,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-29 09:30:00', 5,  3,  6, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-29 09:30:00', 7,  10, 4, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-29 09:30:00', 9,  6,  7, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-29 09:30:00', 4,  8,  5, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-30 09:30:00', 1,  2,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-30 09:30:00', 5,  3,  6, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-30 09:30:00', 7,  10, 4, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-30 09:30:00', 9,  6,  7, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-04-30 09:30:00', 4,  8,  5, 'UPCOMING', NOW(), NOW());

-- 5/1 ~ 5/3
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-05-01 09:30:00', 6,  7,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-01 09:30:00', 8,  5,  2, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-01 09:30:00', 2,  4,  3, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-01 09:30:00', 10, 9,  8, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-01 09:30:00', 3,  1,  9, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-02 08:00:00', 6,  7,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-02 08:00:00', 8,  5,  2, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-02 08:00:00', 2,  4,  3, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-02 08:00:00', 10, 9,  8, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-02 08:00:00', 3,  1,  9, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-03 05:00:00', 6,  7,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-03 05:00:00', 8,  5,  2, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-03 05:00:00', 2,  4,  3, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-03 05:00:00', 10, 9,  8, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-03 05:00:00', 3,  1,  9, 'UPCOMING', NOW(), NOW());

-- 5/5 ~ 5/7
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-05-05 05:00:00', 6,  1,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-05 05:00:00', 8,  7,  2, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-05 05:00:00', 2,  3,  3, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-05 05:00:00', 9,  5,  7, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-05 05:00:00', 10, 4,  8, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-06 09:30:00', 6,  1,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-06 09:30:00', 8,  7,  2, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-06 09:30:00', 2,  3,  3, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-06 09:30:00', 9,  5,  7, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-06 09:30:00', 10, 4,  8, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-07 09:30:00', 6,  1,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-07 09:30:00', 8,  7,  2, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-07 09:30:00', 2,  3,  3, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-07 09:30:00', 9,  5,  7, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-07 09:30:00', 10, 4,  8, 'UPCOMING', NOW(), NOW());

-- 5/8 ~ 5/10
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-05-08 09:30:00', 1,  8,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-08 09:30:00', 5,  10, 6, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-08 09:30:00', 7,  2,  4, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-08 09:30:00', 3,  9,  9, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-08 09:30:00', 4,  6,  5, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-09 08:00:00', 1,  8,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-09 08:00:00', 5,  10, 6, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-09 08:00:00', 7,  2,  4, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-09 08:00:00', 3,  9,  9, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-09 08:00:00', 4,  6,  5, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-10 05:00:00', 1,  8,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-10 05:00:00', 5,  10, 6, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-10 05:00:00', 7,  2,  4, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-10 05:00:00', 3,  9,  9, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-10 05:00:00', 4,  6,  5, 'UPCOMING', NOW(), NOW());

-- 5/12 ~ 5/17 (추가 경기)
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-05-12 09:30:00', 6,  2,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-12 09:30:00', 5,  7,  6, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-12 09:30:00', 9,  8,  7, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-12 09:30:00', 10, 1,  8, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-12 09:30:00', 3,  4,  9, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-15 09:30:00', 1,  5,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-15 09:30:00', 8,  6,  2, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-15 09:30:00', 2,  10, 3, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-15 09:30:00', 7,  3,  4, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-15 09:30:00', 9,  4,  7, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-16 08:00:00', 1,  5,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-16 08:00:00', 8,  6,  2, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-16 08:00:00', 2,  10, 3, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-16 08:00:00', 7,  3,  4, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-16 08:00:00', 9,  4,  7, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-17 05:00:00', 1,  5,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-17 05:00:00', 8,  6,  2, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-17 05:00:00', 2,  10, 3, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-17 05:00:00', 7,  3,  4, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-05-17 05:00:00', 9,  4,  7, 'UPCOMING', NOW(), NOW());

-- 6월 경기 샘플
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-06-05 09:30:00', 1,  3,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-06-05 09:30:00', 8,  9,  2, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-06-05 09:30:00', 5,  4,  6, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-06-05 09:30:00', 7,  6,  4, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-06-05 09:30:00', 10, 2,  8, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-06-12 09:30:00', 6,  5,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-06-12 09:30:00', 2,  8,  3, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-06-12 09:30:00', 9,  7,  7, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-06-12 09:30:00', 10, 1,  8, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-06-12 09:30:00', 3,  4,  9, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-06-19 09:30:00', 6,  1,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-06-19 09:30:00', 7,  8,  4, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-06-19 09:30:00', 9,  10, 7, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-06-19 09:30:00', 3,  5,  9, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-06-19 09:30:00', 4,  2,  5, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-06-26 09:30:00', 1,  10, 1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-06-26 09:30:00', 8,  4,  2, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-06-26 09:30:00', 5,  6,  6, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-06-26 09:30:00', 2,  9,  3, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-06-26 09:30:00', 7,  3,  4, 'UPCOMING', NOW(), NOW());

-- 7월 경기 샘플
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-07-03 09:30:00', 6,  4,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-07-03 09:30:00', 8,  2,  2, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-07-03 09:30:00', 9,  5,  7, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-07-03 09:30:00', 10, 7,  8, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-07-03 09:30:00', 3,  1,  9, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-07-17 09:30:00', 6,  9,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-07-17 09:30:00', 8,  10, 2, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-07-17 09:30:00', 2,  5,  3, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-07-17 09:30:00', 7,  1,  4, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-07-17 09:30:00', 4,  3,  5, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-07-24 09:30:00', 1,  2,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-07-24 09:30:00', 8,  7,  2, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-07-24 09:30:00', 5,  9,  6, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-07-24 09:30:00', 10, 3,  8, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-07-24 09:30:00', 4,  6,  5, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-07-31 09:30:00', 1,  6,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-07-31 09:30:00', 5,  2,  6, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-07-31 09:30:00', 7,  10, 4, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-07-31 09:30:00', 9,  4,  7, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-07-31 09:30:00', 3,  8,  9, 'UPCOMING', NOW(), NOW());

-- 8월 경기 샘플
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-08-07 09:30:00', 6,  10, 1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-08-07 09:30:00', 2,  1,  3, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-08-07 09:30:00', 7,  8,  4, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-08-07 09:30:00', 9,  5,  7, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-08-07 09:30:00', 4,  3,  5, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-08-14 09:30:00', 6,  8,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-08-14 09:30:00', 5,  7,  6, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-08-14 09:30:00', 2,  4,  3, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-08-14 09:30:00', 9,  3,  7, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-08-14 09:30:00', 10, 1,  8, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-08-21 09:30:00', 1,  5,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-08-21 09:30:00', 8,  9,  2, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-08-21 09:30:00', 7,  2,  4, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-08-21 09:30:00', 3,  10, 9, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-08-21 09:30:00', 4,  6,  5, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-08-28 09:30:00', 1,  3,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-08-28 09:30:00', 5,  6,  6, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-08-28 09:30:00', 2,  9,  3, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-08-28 09:30:00', 10, 8,  8, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-08-28 09:30:00', 4,  7,  5, 'UPCOMING', NOW(), NOW());

-- 9월 경기 샘플 (시즌 마무리)
INSERT INTO matches (match_at, home_club_id, away_club_id, stadium_id, sale_status, created_at, updated_at) VALUES
                                                                                                                ('2026-09-04 09:30:00', 6,  2,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-09-04 09:30:00', 8,  1,  2, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-09-04 09:30:00', 5,  4,  6, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-09-04 09:30:00', 10, 9,  8, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-09-04 09:30:00', 3,  7,  9, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-09-05 08:00:00', 6,  2,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-09-05 08:00:00', 8,  1,  2, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-09-05 08:00:00', 5,  4,  6, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-09-05 08:00:00', 10, 9,  8, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-09-05 08:00:00', 3,  7,  9, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-09-06 05:00:00', 6,  2,  1, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-09-06 05:00:00', 8,  1,  2, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-09-06 05:00:00', 5,  4,  6, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-09-06 05:00:00', 10, 9,  8, 'UPCOMING', NOW(), NOW()),
                                                                                                                ('2026-09-06 05:00:00', 3,  7,  9, 'UPCOMING', NOW(), NOW());

-- ============================================================
-- ON_SALE 경기에 match_seats 생성
-- ============================================================
INSERT INTO match_seats (match_id, seat_id, area_id, section_id, block_id, row_no, seat_no, template_col_no, seat_zone, sale_status, created_at, updated_at)
SELECT m.id, s.id, b.area_id, b.section_id, b.id, s.row_no, s.seat_no, s.template_col_no, s.seat_zone, 'AVAILABLE', NOW(), NOW()
FROM matches m
         CROSS JOIN seats s
         JOIN blocks b ON s.block_id = b.id
WHERE m.sale_status = 'ON_SALE';

-- ============================================================
-- 검증 쿼리
-- ============================================================
SELECT m.sale_status, COUNT(*) AS match_count
FROM matches m
GROUP BY m.sale_status
ORDER BY m.sale_status;

SELECT m.id AS match_id, hc.ko_name AS home, ac.ko_name AS away,
       m.match_at AS utc_time,
       m.sale_status,
       COUNT(ms.id) AS seat_count
FROM matches m
         JOIN clubs hc ON m.home_club_id = hc.id
         JOIN clubs ac ON m.away_club_id = ac.id
         LEFT JOIN match_seats ms ON m.id = ms.match_id
GROUP BY m.id, hc.ko_name, ac.ko_name, m.match_at, m.sale_status
ORDER BY m.match_at
    LIMIT 20;

COMMIT;
