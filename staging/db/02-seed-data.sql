-- ============================================================
-- staging/02-seed-data.sql
-- Staging 환경 시드 데이터 (구장, 구단, 좌석구조, 가격정책, 취소정책, 시즌통계)
-- 실행 순서: 2번째 (01-schema.sql 이후)
-- ============================================================

BEGIN;

-- ============================================================
-- 1. STADIUMS (11개 구장)
-- ============================================================
INSERT INTO stadiums (id, region, ko_name, en_name, address, created_at, updated_at) VALUES
(1,  '잠실', '잠실종합운동장 잠실야구장',     'Jamsil Baseball Stadium',       '서울 송파구 올림픽로 19-2 서울종합운동장',                   NOW(), NOW()),
(2,  '문학', '인천SSG 랜더스필드',             'Incheon SSG Landers Field',     '인천광역시 남동구 매소홀로 618',                             NOW(), NOW()),
(3,  '대구', '대구삼성라이온즈파크',           'Daegu Samsung Lions Park',      '대구 수성구 야구전설로 1 대구삼성라이온즈파크',               NOW(), NOW()),
(4,  '창원', '창원NC파크',                     'Changwon NC Park',              '경남 창원시 마산회원구 삼호로 63',                           NOW(), NOW()),
(5,  '대전', '대전한화생명볼파크',             'Hanwha Life Eagles Park',       '대전 중구 대종로 373',                                      NOW(), NOW()),
(6,  '사직', '부산사직종합운동장 사직야구장',   'Sajik Baseball Stadium',        '부산 동래구 사직로 55-32',                                  NOW(), NOW()),
(7,  '수원', '수원KT위즈파크',                 'Suwon KT Wiz Park',             '경기 수원시 장안구 경수대로 893 수원종합운동장(주경기장)',     NOW(), NOW()),
(8,  '광주', '광주기아챔피언스필드',           'Gwangju-Kia Champions Field',   '광주 북구 서림로 10 무등종합경기장',                         NOW(), NOW()),
(9,  '고척', '고척스카이돔',                   'Gocheok Sky Dome',              '서울 구로구 경인로 430',                                    NOW(), NOW()),
(10, '마산', '마산야구장',                     'Masan Baseball Stadium',        '경남 창원시 마산회원구 삼호로 63 마산공설운동장',             NOW(), NOW()),
(11, '이천', '두산베어스파크',                 'Doosan Bears Park',             '경기 이천시 백사면 원적로 668',                              NOW(), NOW());

-- 시퀀스 동기화
SELECT setval('stadiums_id_seq', 11);

-- ============================================================
-- 2. CLUBS (10개 구단 + 홈페이지 URL 포함)
-- ============================================================
-- 구단 ID: 1=두산, 2=삼성, 3=키움, 4=한화, 5=롯데, 6=LG, 7=NC, 8=SSG, 9=kt, 10=KIA
INSERT INTO clubs (id, ko_name, en_name, logo_img, club_color, stadium_id, homepage_redirect_url, created_at, updated_at) VALUES
(1,  '두산 베어스',    'Doosan Bears',    'doosan-bears.png',    '#121130', 1, 'https://www.doosanbears.com/?from=membershipMain', NOW(), NOW()),
(2,  '삼성 라이온즈',  'Samsung Lions',   'samsung-lions.png',   '#0472C4', 3, 'https://www.samsunglions.com/',                    NOW(), NOW()),
(3,  '키움 히어로즈',  'Kiwoom Heroes',   'kiwoom-heroes.png',   '#6C1126', 9, 'https://heroesbaseball.co.kr/index.do',            NOW(), NOW()),
(4,  '한화 이글스',    'Hanwha Eagles',   'hanwha-eagles.png',   '#E27032', 5, 'https://www.hanwhaeagles.co.kr/',                  NOW(), NOW()),
(5,  '롯데 자이언츠',  'Lotte Giants',    'lotte-giants.png',    '#072C5A', 6, 'https://www.giantsclub.com/html/',                 NOW(), NOW()),
(6,  'LG 트윈스',     'LG Twins',        'lg-twins.png',        '#A32C41', 1, 'https://www.lgtwins.com/',                         NOW(), NOW()),
(7,  'NC 다이노스',   'NC Dinos',        'nc-dinos.png',        '#1C467D', 4, 'https://www.ncdinos.com/',                         NOW(), NOW()),
(8,  'SSG 랜더스',    'SSG Landers',     'ssg-landers.png',     '#BB2F45', 2, 'https://www.ssglanders.com/',                      NOW(), NOW()),
(9,  'kt 위즈',      'kt wiz',          'kt-wiz.png',          '#231F20', 7, 'https://www.ktwiz.co.kr/',                         NOW(), NOW()),
(10, 'KIA 타이거즈',  'KIA Tigers',      'kia-tigers.png',      '#A32425', 8, 'https://www.tigers.co.kr/',                        NOW(), NOW());

SELECT setval('clubs_id_seq', 10);

-- ============================================================
-- 3. AREAS (4개 구역)
-- ============================================================
INSERT INTO areas (id, code, name, created_at, updated_at) VALUES
(1, 'HOME',     '1루(홈)',       NOW(), NOW()),
(2, 'AWAY',     '3루(어웨이)',    NOW(), NOW()),
(3, 'OUTFIELD', '외야',          NOW(), NOW()),
(4, 'CENTER',   '중앙',          NOW(), NOW());

SELECT setval('areas_id_seq', 4);

-- ============================================================
-- 4. SECTIONS (14개 섹션)
-- ============================================================
-- 1루(홈) 섹션
INSERT INTO sections (id, area_id, code, name, created_at, updated_at) VALUES
(1,  1, 'PURPLE',   '퍼플석(테이블석)',          NOW(), NOW()),
(2,  1, 'EXCITING', '익사이팅존',               NOW(), NOW()),
(3,  1, 'BLUE',     '블루석',                   NOW(), NOW()),
(4,  1, 'ORANGE',   '오렌지석',                 NOW(), NOW()),
(5,  1, 'RED',      '레드석',                   NOW(), NOW()),
(6,  1, 'NAVY',     '네이비석',                 NOW(), NOW());

-- 3루(어웨이) 섹션
INSERT INTO sections (id, area_id, code, name, created_at, updated_at) VALUES
(7,  2, 'PURPLE',   '퍼플석(테이블석)',          NOW(), NOW()),
(8,  2, 'EXCITING', '익사이팅존',               NOW(), NOW()),
(9,  2, 'BLUE',     '블루석',                   NOW(), NOW()),
(10, 2, 'ORANGE',   '오렌지석',                 NOW(), NOW()),
(11, 2, 'RED',      '레드석',                   NOW(), NOW()),
(12, 2, 'NAVY',     '네이비석',                 NOW(), NOW());

-- 외야
INSERT INTO sections (id, area_id, code, name, created_at, updated_at) VALUES
(13, 3, 'GREEN',   '그린석(외야석)',             NOW(), NOW());

-- 중앙
INSERT INTO sections (id, area_id, code, name, created_at, updated_at) VALUES
(14, 4, 'PREMIUM', '테라존(중앙 프리미엄석)',     NOW(), NOW());

SELECT setval('sections_id_seq', 14);

-- ============================================================
-- 5. BLOCKS (SeatDataInitializer 로직 기반)
-- ============================================================
-- block_id는 순차 부여 (총 88블록)
-- viewpoint: CENTER, INFIELD_1B, INFIELD_3B, OUTFIELD_R, OUTFIELD_C, OUTFIELD_L

-- 중앙 프리미엄석 CP (area=4/CENTER, section=14/PREMIUM)
INSERT INTO blocks (id, area_id, section_id, block_code, viewpoint, home_cheer_rank, away_cheer_rank, created_at, updated_at) VALUES
(1, 4, 14, 'CP', 'CENTER', 50, 50, NOW(), NOW());

-- 익사이팅존 (1루: area=1, section=2 / 3루: area=2, section=8)
INSERT INTO blocks (id, area_id, section_id, block_code, viewpoint, home_cheer_rank, away_cheer_rank, created_at, updated_at) VALUES
(2, 1, 2, 'EX-1', 'INFIELD_1B', 30, 40, NOW(), NOW()),
(3, 2, 8, 'EX-3', 'INFIELD_3B', 40, 30, NOW(), NOW());

-- 1루 오렌지석 205~208 (area=1, section=4)
INSERT INTO blocks (id, area_id, section_id, block_code, viewpoint, home_cheer_rank, away_cheer_rank, created_at, updated_at) VALUES
(4,  1, 4, '205', 'INFIELD_1B', 1, 80, NOW(), NOW()),
(5,  1, 4, '206', 'INFIELD_1B', 2, 81, NOW(), NOW()),
(6,  1, 4, '207', 'INFIELD_1B', 3, 82, NOW(), NOW()),
(7,  1, 4, '208', 'INFIELD_1B', 4, 83, NOW(), NOW());

-- 3루 오렌지석 219~222 (area=2, section=10)
INSERT INTO blocks (id, area_id, section_id, block_code, viewpoint, home_cheer_rank, away_cheer_rank, created_at, updated_at) VALUES
(8,  2, 10, '219', 'INFIELD_3B', 80, 1, NOW(), NOW()),
(9,  2, 10, '220', 'INFIELD_3B', 81, 2, NOW(), NOW()),
(10, 2, 10, '221', 'INFIELD_3B', 82, 3, NOW(), NOW()),
(11, 2, 10, '222', 'INFIELD_3B', 83, 4, NOW(), NOW());

-- 1루 퍼플석 110~113 (area=1, section=1)
INSERT INTO blocks (id, area_id, section_id, block_code, viewpoint, home_cheer_rank, away_cheer_rank, created_at, updated_at) VALUES
(12, 1, 1, '110', 'INFIELD_1B', 10, 60, NOW(), NOW()),
(13, 1, 1, '111', 'INFIELD_1B', 11, 61, NOW(), NOW()),
(14, 1, 1, '112', 'INFIELD_1B', 12, 62, NOW(), NOW()),
(15, 1, 1, '113', 'INFIELD_1B', 13, 63, NOW(), NOW());

-- 3루 퍼플석 212~215 (area=2, section=7)
INSERT INTO blocks (id, area_id, section_id, block_code, viewpoint, home_cheer_rank, away_cheer_rank, created_at, updated_at) VALUES
(16, 2, 7, '212', 'INFIELD_3B', 60, 10, NOW(), NOW()),
(17, 2, 7, '213', 'INFIELD_3B', 61, 11, NOW(), NOW()),
(18, 2, 7, '214', 'INFIELD_3B', 62, 12, NOW(), NOW()),
(19, 2, 7, '215', 'INFIELD_3B', 63, 13, NOW(), NOW());

-- 1루 블루석 114~116 (area=1, section=3)
INSERT INTO blocks (id, area_id, section_id, block_code, viewpoint, home_cheer_rank, away_cheer_rank, created_at, updated_at) VALUES
(20, 1, 3, '114', 'INFIELD_1B', 14, 55, NOW(), NOW()),
(21, 1, 3, '115', 'INFIELD_1B', 15, 56, NOW(), NOW()),
(22, 1, 3, '116', 'INFIELD_1B', 16, 57, NOW(), NOW());

-- 1루 블루석 216~218 2층 (area=1, section=3)
INSERT INTO blocks (id, area_id, section_id, block_code, viewpoint, home_cheer_rank, away_cheer_rank, created_at, updated_at) VALUES
(23, 1, 3, '216', 'INFIELD_1B', 5, 70, NOW(), NOW()),
(24, 1, 3, '217', 'INFIELD_1B', 6, 71, NOW(), NOW()),
(25, 1, 3, '218', 'INFIELD_1B', 7, 72, NOW(), NOW());

-- 3루 블루석 107~109 (area=2, section=9)
INSERT INTO blocks (id, area_id, section_id, block_code, viewpoint, home_cheer_rank, away_cheer_rank, created_at, updated_at) VALUES
(26, 2, 9, '107', 'INFIELD_3B', 55, 14, NOW(), NOW()),
(27, 2, 9, '108', 'INFIELD_3B', 56, 15, NOW(), NOW()),
(28, 2, 9, '109', 'INFIELD_3B', 57, 16, NOW(), NOW());

-- 3루 블루석 209~211 2층 (area=2, section=9)
INSERT INTO blocks (id, area_id, section_id, block_code, viewpoint, home_cheer_rank, away_cheer_rank, created_at, updated_at) VALUES
(29, 2, 9, '209', 'INFIELD_3B', 70, 5, NOW(), NOW()),
(30, 2, 9, '210', 'INFIELD_3B', 71, 6, NOW(), NOW()),
(31, 2, 9, '211', 'INFIELD_3B', 72, 7, NOW(), NOW());

-- 1루 레드석 117~122 (area=1, section=5)
INSERT INTO blocks (id, area_id, section_id, block_code, viewpoint, home_cheer_rank, away_cheer_rank, created_at, updated_at) VALUES
(32, 1, 5, '117', 'INFIELD_1B', 17, 45, NOW(), NOW()),
(33, 1, 5, '118', 'INFIELD_1B', 18, 46, NOW(), NOW()),
(34, 1, 5, '119', 'INFIELD_1B', 19, 47, NOW(), NOW()),
(35, 1, 5, '120', 'INFIELD_1B', 20, 48, NOW(), NOW()),
(36, 1, 5, '121', 'INFIELD_1B', 21, 49, NOW(), NOW()),
(37, 1, 5, '122', 'INFIELD_1B', 22, 50, NOW(), NOW());

-- 1루 레드석 223~226 2층 (area=1, section=5)
INSERT INTO blocks (id, area_id, section_id, block_code, viewpoint, home_cheer_rank, away_cheer_rank, created_at, updated_at) VALUES
(38, 1, 5, '223', 'INFIELD_1B', 8, 65, NOW(), NOW()),
(39, 1, 5, '224', 'INFIELD_1B', 9, 66, NOW(), NOW()),
(40, 1, 5, '225', 'INFIELD_1B', 10, 67, NOW(), NOW()),
(41, 1, 5, '226', 'INFIELD_1B', 11, 68, NOW(), NOW());

-- 3루 레드석 101~106 (area=2, section=11)
INSERT INTO blocks (id, area_id, section_id, block_code, viewpoint, home_cheer_rank, away_cheer_rank, created_at, updated_at) VALUES
(42, 2, 11, '101', 'INFIELD_3B', 45, 17, NOW(), NOW()),
(43, 2, 11, '102', 'INFIELD_3B', 46, 18, NOW(), NOW()),
(44, 2, 11, '103', 'INFIELD_3B', 47, 19, NOW(), NOW()),
(45, 2, 11, '104', 'INFIELD_3B', 48, 20, NOW(), NOW()),
(46, 2, 11, '105', 'INFIELD_3B', 49, 21, NOW(), NOW()),
(47, 2, 11, '106', 'INFIELD_3B', 50, 22, NOW(), NOW());

-- 3루 레드석 201~204 2층 (area=2, section=11)
INSERT INTO blocks (id, area_id, section_id, block_code, viewpoint, home_cheer_rank, away_cheer_rank, created_at, updated_at) VALUES
(48, 2, 11, '201', 'INFIELD_3B', 65, 8, NOW(), NOW()),
(49, 2, 11, '202', 'INFIELD_3B', 66, 9, NOW(), NOW()),
(50, 2, 11, '203', 'INFIELD_3B', 67, 10, NOW(), NOW()),
(51, 2, 11, '204', 'INFIELD_3B', 68, 11, NOW(), NOW());

-- 1루 네이비석 301~317 (area=1, section=6)
INSERT INTO blocks (id, area_id, section_id, block_code, viewpoint, home_cheer_rank, away_cheer_rank, created_at, updated_at) VALUES
(52, 1, 6, '301', 'INFIELD_1B', 23, 35, NOW(), NOW()),
(53, 1, 6, '302', 'INFIELD_1B', 24, 36, NOW(), NOW()),
(54, 1, 6, '303', 'INFIELD_1B', 25, 37, NOW(), NOW()),
(55, 1, 6, '304', 'INFIELD_1B', 26, 38, NOW(), NOW()),
(56, 1, 6, '305', 'INFIELD_1B', 27, 39, NOW(), NOW()),
(57, 1, 6, '306', 'INFIELD_1B', 28, 40, NOW(), NOW()),
(58, 1, 6, '307', 'INFIELD_1B', 29, 41, NOW(), NOW()),
(59, 1, 6, '308', 'INFIELD_1B', 30, 42, NOW(), NOW()),
(60, 1, 6, '309', 'INFIELD_1B', 31, 43, NOW(), NOW()),
(61, 1, 6, '310', 'INFIELD_1B', 32, 44, NOW(), NOW()),
(62, 1, 6, '311', 'INFIELD_1B', 33, 45, NOW(), NOW()),
(63, 1, 6, '312', 'INFIELD_1B', 34, 46, NOW(), NOW()),
(64, 1, 6, '313', 'INFIELD_1B', 35, 47, NOW(), NOW()),
(65, 1, 6, '314', 'INFIELD_1B', 36, 48, NOW(), NOW()),
(66, 1, 6, '315', 'INFIELD_1B', 37, 49, NOW(), NOW()),
(67, 1, 6, '316', 'INFIELD_1B', 38, 50, NOW(), NOW()),
(68, 1, 6, '317', 'INFIELD_1B', 39, 51, NOW(), NOW());

-- 3루 네이비석 318~334 (area=2, section=12)
INSERT INTO blocks (id, area_id, section_id, block_code, viewpoint, home_cheer_rank, away_cheer_rank, created_at, updated_at) VALUES
(69, 2, 12, '318', 'INFIELD_3B', 35, 23, NOW(), NOW()),
(70, 2, 12, '319', 'INFIELD_3B', 36, 24, NOW(), NOW()),
(71, 2, 12, '320', 'INFIELD_3B', 37, 25, NOW(), NOW()),
(72, 2, 12, '321', 'INFIELD_3B', 38, 26, NOW(), NOW()),
(73, 2, 12, '322', 'INFIELD_3B', 39, 27, NOW(), NOW()),
(74, 2, 12, '323', 'INFIELD_3B', 40, 28, NOW(), NOW()),
(75, 2, 12, '324', 'INFIELD_3B', 41, 29, NOW(), NOW()),
(76, 2, 12, '325', 'INFIELD_3B', 42, 30, NOW(), NOW()),
(77, 2, 12, '326', 'INFIELD_3B', 43, 31, NOW(), NOW()),
(78, 2, 12, '327', 'INFIELD_3B', 44, 32, NOW(), NOW()),
(79, 2, 12, '328', 'INFIELD_3B', 45, 33, NOW(), NOW()),
(80, 2, 12, '329', 'INFIELD_3B', 46, 34, NOW(), NOW()),
(81, 2, 12, '330', 'INFIELD_3B', 47, 35, NOW(), NOW()),
(82, 2, 12, '331', 'INFIELD_3B', 48, 36, NOW(), NOW()),
(83, 2, 12, '332', 'INFIELD_3B', 49, 37, NOW(), NOW()),
(84, 2, 12, '333', 'INFIELD_3B', 50, 38, NOW(), NOW()),
(85, 2, 12, '334', 'INFIELD_3B', 51, 39, NOW(), NOW());

-- 외야 그린석 401~407 (1루방향 OUTFIELD_R, area=3, section=13)
INSERT INTO blocks (id, area_id, section_id, block_code, viewpoint, home_cheer_rank, away_cheer_rank, created_at, updated_at) VALUES
(86,  3, 13, '401', 'OUTFIELD_R', 60, 90, NOW(), NOW()),
(87,  3, 13, '402', 'OUTFIELD_R', 61, 91, NOW(), NOW()),
(88,  3, 13, '403', 'OUTFIELD_R', 62, 92, NOW(), NOW()),
(89,  3, 13, '404', 'OUTFIELD_R', 63, 93, NOW(), NOW()),
(90,  3, 13, '405', 'OUTFIELD_R', 64, 94, NOW(), NOW()),
(91,  3, 13, '406', 'OUTFIELD_R', 65, 95, NOW(), NOW()),
(92,  3, 13, '407', 'OUTFIELD_R', 66, 96, NOW(), NOW());

-- 외야 그린석 408~415 (중앙 OUTFIELD_C, area=3, section=13)
INSERT INTO blocks (id, area_id, section_id, block_code, viewpoint, home_cheer_rank, away_cheer_rank, created_at, updated_at) VALUES
(93,  3, 13, '408', 'OUTFIELD_C', 70, 70, NOW(), NOW()),
(94,  3, 13, '409', 'OUTFIELD_C', 71, 71, NOW(), NOW()),
(95,  3, 13, '410', 'OUTFIELD_C', 72, 72, NOW(), NOW()),
(96,  3, 13, '411', 'OUTFIELD_C', 73, 73, NOW(), NOW()),
(97,  3, 13, '412', 'OUTFIELD_C', 74, 74, NOW(), NOW()),
(98,  3, 13, '413', 'OUTFIELD_C', 75, 75, NOW(), NOW()),
(99,  3, 13, '414', 'OUTFIELD_C', 76, 76, NOW(), NOW()),
(100, 3, 13, '415', 'OUTFIELD_C', 77, 77, NOW(), NOW());

-- 외야 그린석 416~422 (3루방향 OUTFIELD_L, area=3, section=13)
INSERT INTO blocks (id, area_id, section_id, block_code, viewpoint, home_cheer_rank, away_cheer_rank, created_at, updated_at) VALUES
(101, 3, 13, '416', 'OUTFIELD_L', 90, 60, NOW(), NOW()),
(102, 3, 13, '417', 'OUTFIELD_L', 91, 61, NOW(), NOW()),
(103, 3, 13, '418', 'OUTFIELD_L', 92, 62, NOW(), NOW()),
(104, 3, 13, '419', 'OUTFIELD_L', 93, 63, NOW(), NOW()),
(105, 3, 13, '420', 'OUTFIELD_L', 94, 64, NOW(), NOW()),
(106, 3, 13, '421', 'OUTFIELD_L', 95, 65, NOW(), NOW()),
(107, 3, 13, '422', 'OUTFIELD_L', 96, 66, NOW(), NOW());

SELECT setval('blocks_id_seq', 107);

-- ============================================================
-- 6. SEATS (블록당 22열, STANDARD 패턴)
--    rows 1~3: 14석(col 1~14)  → LOW
--    rows 4~7: 7석(col 5~11)   → MID
--    rows 8~22: 14석(col 1~14) → HIGH
--    블록당 총: 14*3 + 7*4 + 14*15 = 42 + 28 + 210 = 280석
-- ============================================================
INSERT INTO seats (block_id, row_no, seat_no, template_col_no, seat_zone, created_at, updated_at)
SELECT
    b.id,
    r.row_no,
    s.seat_no,
    CASE
        WHEN r.row_no BETWEEN 4 AND 7 THEN 4 + s.seat_no  -- startTemplateColNo=5, so 5 + (seat_no - 1)
        ELSE s.seat_no                                      -- startTemplateColNo=1, so 1 + (seat_no - 1)
    END AS template_col_no,
    CASE
        WHEN r.row_no <= 3 THEN 'LOW'
        WHEN r.row_no <= 7 THEN 'MID'
        ELSE 'HIGH'
    END AS seat_zone,
    NOW(), NOW()
FROM blocks b
CROSS JOIN (
    SELECT 1 AS row_no, 14 AS seat_count UNION ALL
    SELECT 2, 14 UNION ALL SELECT 3, 14 UNION ALL
    SELECT 4, 7 UNION ALL SELECT 5, 7 UNION ALL
    SELECT 6, 7 UNION ALL SELECT 7, 7 UNION ALL
    SELECT 8, 14 UNION ALL SELECT 9, 14 UNION ALL
    SELECT 10, 14 UNION ALL SELECT 11, 14 UNION ALL
    SELECT 12, 14 UNION ALL SELECT 13, 14 UNION ALL
    SELECT 14, 14 UNION ALL SELECT 15, 14 UNION ALL
    SELECT 16, 14 UNION ALL SELECT 17, 14 UNION ALL
    SELECT 18, 14 UNION ALL SELECT 19, 14 UNION ALL
    SELECT 20, 14 UNION ALL SELECT 21, 14 UNION ALL
    SELECT 22, 14
) r
CROSS JOIN generate_series(1, 14) AS s(seat_no)
WHERE s.seat_no <= r.seat_count
ORDER BY b.id, r.row_no, s.seat_no;

-- ============================================================
-- 7. PRICE POLICIES
-- ============================================================
-- 가격은 section별로 적용 (1루/3루 동일 섹션코드는 각각 별도 section_id)
-- 이미지 기준:
--   중앙석(PREMIUM):      80,000 / 80,000
--   테이블석(PURPLE):      52,000 / 58,000
--   익사이팅존(EXCITING):  28,000 / 33,000
--   블루석(BLUE):          22,000 / 24,000
--   오렌지석(ORANGE):      20,000 / 22,000
--   레드석(RED):           17,000 / 19,000
--   네이비석(NAVY):        14,000 / 16,000
--   외야(GREEN) 일반:       9,000 / 10,000
--   외야(GREEN) 청소년/군경: 7,000 / 8,000
--   외야(GREEN) 어린이/유공자/경로자: 4,500 / 5,000

-- PREMIUM (section 14)
INSERT INTO price_policies (section_id, day_type, ticket_type, price, created_at, updated_at) VALUES
(14, 'WEEKDAY', 'ADULT', 80000, NOW(), NOW()),
(14, 'WEEKEND', 'ADULT', 80000, NOW(), NOW());

-- PURPLE (sections 1, 7)
INSERT INTO price_policies (section_id, day_type, ticket_type, price, created_at, updated_at)
SELECT s.id, dt.day_type, 'ADULT', CASE dt.day_type WHEN 'WEEKDAY' THEN 52000 ELSE 58000 END, NOW(), NOW()
FROM sections s CROSS JOIN (SELECT 'WEEKDAY' AS day_type UNION ALL SELECT 'WEEKEND') dt
WHERE s.code = 'PURPLE';

-- EXCITING (sections 2, 8)
INSERT INTO price_policies (section_id, day_type, ticket_type, price, created_at, updated_at)
SELECT s.id, dt.day_type, 'ADULT', CASE dt.day_type WHEN 'WEEKDAY' THEN 28000 ELSE 33000 END, NOW(), NOW()
FROM sections s CROSS JOIN (SELECT 'WEEKDAY' AS day_type UNION ALL SELECT 'WEEKEND') dt
WHERE s.code = 'EXCITING';

-- BLUE (sections 3, 9) — 일반 + 장애인 50%
INSERT INTO price_policies (section_id, day_type, ticket_type, price, created_at, updated_at)
SELECT s.id, dt.day_type, tt.ticket_type,
    CASE
        WHEN tt.ticket_type = 'ADULT' AND dt.day_type = 'WEEKDAY' THEN 22000
        WHEN tt.ticket_type = 'ADULT' AND dt.day_type = 'WEEKEND' THEN 24000
        WHEN tt.ticket_type = 'DISABLED' AND dt.day_type = 'WEEKDAY' THEN 11000
        WHEN tt.ticket_type = 'DISABLED' AND dt.day_type = 'WEEKEND' THEN 12000
    END,
    NOW(), NOW()
FROM sections s
CROSS JOIN (SELECT 'WEEKDAY' AS day_type UNION ALL SELECT 'WEEKEND') dt
CROSS JOIN (SELECT 'ADULT' AS ticket_type UNION ALL SELECT 'DISABLED') tt
WHERE s.code = 'BLUE';

-- ORANGE (sections 4, 10) — 일반 + 장애인 50%
INSERT INTO price_policies (section_id, day_type, ticket_type, price, created_at, updated_at)
SELECT s.id, dt.day_type, tt.ticket_type,
    CASE
        WHEN tt.ticket_type = 'ADULT' AND dt.day_type = 'WEEKDAY' THEN 20000
        WHEN tt.ticket_type = 'ADULT' AND dt.day_type = 'WEEKEND' THEN 22000
        WHEN tt.ticket_type = 'DISABLED' AND dt.day_type = 'WEEKDAY' THEN 10000
        WHEN tt.ticket_type = 'DISABLED' AND dt.day_type = 'WEEKEND' THEN 11000
    END,
    NOW(), NOW()
FROM sections s
CROSS JOIN (SELECT 'WEEKDAY' AS day_type UNION ALL SELECT 'WEEKEND') dt
CROSS JOIN (SELECT 'ADULT' AS ticket_type UNION ALL SELECT 'DISABLED') tt
WHERE s.code = 'ORANGE';

-- RED (sections 5, 11) — 일반 + 장애인 50%
INSERT INTO price_policies (section_id, day_type, ticket_type, price, created_at, updated_at)
SELECT s.id, dt.day_type, tt.ticket_type,
    CASE
        WHEN tt.ticket_type = 'ADULT' AND dt.day_type = 'WEEKDAY' THEN 17000
        WHEN tt.ticket_type = 'ADULT' AND dt.day_type = 'WEEKEND' THEN 19000
        WHEN tt.ticket_type = 'DISABLED' AND dt.day_type = 'WEEKDAY' THEN 8500
        WHEN tt.ticket_type = 'DISABLED' AND dt.day_type = 'WEEKEND' THEN 9500
    END,
    NOW(), NOW()
FROM sections s
CROSS JOIN (SELECT 'WEEKDAY' AS day_type UNION ALL SELECT 'WEEKEND') dt
CROSS JOIN (SELECT 'ADULT' AS ticket_type UNION ALL SELECT 'DISABLED') tt
WHERE s.code = 'RED';

-- NAVY (sections 6, 12) — 일반 14,000/16,000 + 장애인 50%
INSERT INTO price_policies (section_id, day_type, ticket_type, price, created_at, updated_at)
SELECT s.id, dt.day_type, tt.ticket_type,
    CASE
        WHEN tt.ticket_type = 'ADULT' AND dt.day_type = 'WEEKDAY' THEN 14000
        WHEN tt.ticket_type = 'ADULT' AND dt.day_type = 'WEEKEND' THEN 16000
        WHEN tt.ticket_type = 'DISABLED' AND dt.day_type = 'WEEKDAY' THEN 7000
        WHEN tt.ticket_type = 'DISABLED' AND dt.day_type = 'WEEKEND' THEN 8000
    END,
    NOW(), NOW()
FROM sections s
CROSS JOIN (SELECT 'WEEKDAY' AS day_type UNION ALL SELECT 'WEEKEND') dt
CROSS JOIN (SELECT 'ADULT' AS ticket_type UNION ALL SELECT 'DISABLED') tt
WHERE s.code = 'NAVY';

-- GREEN (section 13) — 외야: 일반/청소년·군경/어린이·유공자·경로·장애인
INSERT INTO price_policies (section_id, day_type, ticket_type, price, created_at, updated_at) VALUES
-- 일반
(13, 'WEEKDAY', 'ADULT',    9000, NOW(), NOW()),
(13, 'WEEKEND', 'ADULT',   10000, NOW(), NOW()),
-- 청소년
(13, 'WEEKDAY', 'YOUTH',    7000, NOW(), NOW()),
(13, 'WEEKEND', 'YOUTH',    8000, NOW(), NOW()),
-- 군경
(13, 'WEEKDAY', 'MILITARY', 7000, NOW(), NOW()),
(13, 'WEEKEND', 'MILITARY', 8000, NOW(), NOW()),
-- 어린이
(13, 'WEEKDAY', 'CHILD',    4500, NOW(), NOW()),
(13, 'WEEKEND', 'CHILD',    5000, NOW(), NOW()),
-- 유공자
(13, 'WEEKDAY', 'VETERAN',  4500, NOW(), NOW()),
(13, 'WEEKEND', 'VETERAN',  5000, NOW(), NOW()),
-- 경로
(13, 'WEEKDAY', 'SENIOR',   4500, NOW(), NOW()),
(13, 'WEEKEND', 'SENIOR',   5000, NOW(), NOW()),
-- 장애인
(13, 'WEEKDAY', 'DISABLED', 4500, NOW(), NOW()),
(13, 'WEEKEND', 'DISABLED', 5000, NOW(), NOW());

-- ============================================================
-- 8. CANCELLATION FEE POLICIES (취소 수수료 정책)
-- ============================================================
INSERT INTO cancellation_fee_policies (days_before_match_min, days_before_match_max, cancellable, ticket_fee_rate, booking_fee_refundable, created_at, updated_at) VALUES
(0, 0,    false, 0.000, false, NOW(), NOW()),  -- D-0: 취소 불가
(1, 6,    true,  0.100, false, NOW(), NOW()),  -- D-1~D-6: 10% + 예매수수료 환불불가
(7, NULL, true,  0.000, true,  NOW(), NOW());  -- D-7 이상: 무료 취소

-- ============================================================
-- 9. TEAM SEASON STATS (2026 시즌)
-- ============================================================
INSERT INTO team_season_stats (club_id, season_year, season_ranking, wins, draws, losses, win_rate, batting_average, era, games_behind, created_at, updated_at) VALUES
(6,  2026, 1,  5, 0, 1, 0.500, 0.280, 3.45, 0.0, NOW(), NOW()),   -- LG
(1,  2026, 2,  4, 0, 2, 0.480, 0.275, 3.60, 0.5, NOW(), NOW()),   -- 두산
(8,  2026, 3,  4, 0, 2, 0.475, 0.270, 3.55, 1.0, NOW(), NOW()),   -- SSG
(9,  2026, 4,  3, 0, 3, 0.460, 0.268, 3.70, 1.5, NOW(), NOW()),   -- kt
(7,  2026, 5,  3, 0, 3, 0.455, 0.265, 3.80, 2.0, NOW(), NOW()),   -- NC
(3,  2026, 6,  2, 0, 4, 0.450, 0.262, 3.90, 2.5, NOW(), NOW()),   -- 키움
(2,  2026, 7,  2, 0, 4, 0.445, 0.260, 4.00, 3.0, NOW(), NOW()),   -- 삼성
(5,  2026, 8,  2, 0, 4, 0.440, 0.258, 4.10, 3.5, NOW(), NOW()),   -- 롯데
(4,  2026, 9,  1, 0, 5, 0.430, 0.255, 4.20, 4.0, NOW(), NOW()),   -- 한화
(10, 2026, 10, 1, 0, 5, 0.425, 0.252, 4.35, 4.5, NOW(), NOW());   -- KIA

-- ============================================================
-- 검증 쿼리
-- ============================================================
SELECT 'stadiums' AS tbl, COUNT(*) AS cnt FROM stadiums
UNION ALL SELECT 'clubs', COUNT(*) FROM clubs
UNION ALL SELECT 'areas', COUNT(*) FROM areas
UNION ALL SELECT 'sections', COUNT(*) FROM sections
UNION ALL SELECT 'blocks', COUNT(*) FROM blocks
UNION ALL SELECT 'seats', COUNT(*) FROM seats
UNION ALL SELECT 'price_policies', COUNT(*) FROM price_policies
UNION ALL SELECT 'cancellation_fee_policies', COUNT(*) FROM cancellation_fee_policies
UNION ALL SELECT 'team_season_stats', COUNT(*) FROM team_season_stats;

COMMIT;
