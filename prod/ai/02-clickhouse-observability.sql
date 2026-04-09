-- ============================================================
-- AI Defense - ClickHouse Observability Tables
-- Prod Environment
--
-- 실행: clickhouse-client로 실행
-- ============================================================

-- Database 생성
CREATE DATABASE IF NOT EXISTS ai_defense;

-- Raw audit events table
CREATE TABLE IF NOT EXISTS ai_defense.defense_audit_events (
    ts_ms UInt64,
    session_id String,
    event_type String,
    trace_id Nullable(String),
    challenge_id Nullable(String),
    flow_state Nullable(String),
    risk_tier Nullable(String),
    action Nullable(String),
    reason_code Nullable(String),
    policy_version Nullable(String),
    raw_payload_json String
)
ENGINE = MergeTree
PARTITION BY toDate(fromUnixTimestamp64Milli(ts_ms))
ORDER BY (session_id, ts_ms, event_type);

-- Session rollups view
CREATE VIEW IF NOT EXISTS ai_defense.defense_session_rollups AS
WITH 300000 AS window_ms
SELECT
    intDiv(ts_ms, window_ms) * window_ms AS window_start_ms,
    (intDiv(ts_ms, window_ms) * window_ms) + window_ms AS window_end_ms,
    session_id,
    min(ts_ms) AS first_ts_ms,
    max(ts_ms) AS last_ts_ms,
    toUInt32(count()) AS event_count,
    argMaxIf(flow_state, ts_ms, flow_state IS NOT NULL) AS latest_flow_state,
    argMaxIf(action, ts_ms, action IS NOT NULL) AS latest_action,
    argMaxIf(risk_tier, ts_ms, risk_tier IS NOT NULL) AS latest_risk_tier,
    argMaxIf(reason_code, ts_ms, reason_code IS NOT NULL) AS latest_reason_code,
    argMaxIf(policy_version, ts_ms, policy_version IS NOT NULL) AS latest_policy_version,
    toUInt32(countIf(action = 'THROTTLE')) AS throttle_action_count,
    toUInt32(countIf(action = 'BLOCK')) AS block_action_count,
    toUInt32(countIf(event_type = 'CHALLENGE_ISSUED')) AS challenge_issue_count,
    toUInt32(countIf(event_type = 'CHALLENGE_VERIFIED')) AS challenge_verified_count
FROM ai_defense.defense_audit_events
GROUP BY
    window_start_ms,
    window_end_ms,
    session_id;

-- Match rollups view
CREATE VIEW IF NOT EXISTS ai_defense.defense_match_rollups AS
WITH 300000 AS window_ms
SELECT
    window_start_ms,
    window_end_ms,
    match_id,
    toUInt32(uniqExact(session_id)) AS session_count,
    toUInt32(sum(event_count)) AS event_count,
    toUInt32(sum(block_action_count)) AS block_action_count,
    toUInt32(sum(throttle_action_count)) AS throttle_action_count,
    toUInt32(sum(challenge_issue_count)) AS challenge_issue_count,
    toUInt32(sum(challenge_verified_count)) AS challenge_verified_count,
    argMaxIf(latest_policy_version, last_ts_ms, latest_policy_version IS NOT NULL) AS latest_policy_version
FROM (
    WITH
        intDiv(ts_ms, window_ms) * window_ms AS window_start_ms,
        (intDiv(ts_ms, window_ms) * window_ms) + window_ms AS window_end_ms,
        nullIf(
            coalesce(
                nullIf(extract(JSONExtractString(raw_payload_json, 'path'), '/matches/([0-9]+)'), ''),
                if(
                    length(splitByChar(':', session_id)) = 2,
                    arrayElement(splitByChar(':', session_id), 2),
                    ''
                )
            ),
            ''
        ) AS match_id
    SELECT
        window_start_ms,
        window_end_ms,
        session_id,
        match_id,
        toUInt32(count()) AS event_count,
        max(ts_ms) AS last_ts_ms,
        toUInt32(countIf(action = 'BLOCK')) AS block_action_count,
        toUInt32(countIf(action = 'THROTTLE')) AS throttle_action_count,
        toUInt32(countIf(event_type = 'CHALLENGE_ISSUED')) AS challenge_issue_count,
        toUInt32(countIf(event_type = 'CHALLENGE_VERIFIED')) AS challenge_verified_count,
        argMaxIf(policy_version, ts_ms, policy_version IS NOT NULL) AS latest_policy_version
    FROM ai_defense.defense_audit_events
    GROUP BY
        window_start_ms,
        window_end_ms,
        session_id,
        match_id
)
WHERE match_id IS NOT NULL
GROUP BY
    window_start_ms,
    window_end_ms,
    match_id;

-- Post-review candidates view
CREATE VIEW IF NOT EXISTS ai_defense.defense_post_review_candidates_v1 AS
SELECT
    window_start_ms,
    window_end_ms,
    session_id,
    first_ts_ms,
    last_ts_ms,
    latest_action,
    latest_risk_tier,
    latest_reason_code,
    latest_policy_version,
    block_action_count,
    throttle_action_count,
    challenge_issue_count,
    challenge_verified_count,
    multiIf(
        block_action_count > 0, 'block_action_detected',
        challenge_issue_count > 0, 'challenge_issue_detected',
        challenge_verified_count > 0, 'challenge_verified_detected',
        throttle_action_count > 0, 'throttle_action_detected',
        latest_action IS NOT NULL AND latest_action != 'NONE', 'non_none_action_detected',
        'unknown_candidate_reason'
    ) AS candidate_reason
FROM ai_defense.defense_session_rollups
WHERE
    block_action_count > 0
    OR challenge_issue_count > 0
    OR challenge_verified_count > 0
    OR throttle_action_count > 0
    OR (latest_action IS NOT NULL AND latest_action != 'NONE');
