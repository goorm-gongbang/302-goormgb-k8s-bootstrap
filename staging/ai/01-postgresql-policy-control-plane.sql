-- ============================================================
-- AI Defense - PostgreSQL Policy Control Plane Tables
-- Staging Environment
--
-- Source: 201-goormgb-ai/src/traffic_master_ai/defense/backoffice_copilot/storage/sql/002_postgresql_policy_control_plane_tables.sql
-- ============================================================

-- Policy versions: authoritative policy document store
CREATE TABLE IF NOT EXISTS policy_versions (
    policy_version TEXT PRIMARY KEY,
    schema_version TEXT NOT NULL,
    status TEXT NOT NULL,
    source_type TEXT NOT NULL,
    parent_policy_version TEXT NULL,
    document_json JSONB NOT NULL,
    validation_result_json JSONB NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    validated_at TIMESTAMPTZ NULL,
    activated_at TIMESTAMPTZ NULL
);

-- Policy rollout state: current rollout control state
CREATE TABLE IF NOT EXISTS policy_rollout_state (
    rollout_id TEXT PRIMARY KEY,
    stage TEXT NOT NULL,
    base_policy_version TEXT NOT NULL,
    candidate_policy_version TEXT NULL,
    ratio NUMERIC(6,5) NOT NULL,
    evaluation_window_seconds INTEGER NOT NULL,
    canary_duration_seconds INTEGER NOT NULL,
    expand_step_index INTEGER NULL,
    stage_started_at_ms BIGINT NOT NULL,
    updated_at_ms BIGINT NOT NULL,
    current_status TEXT NOT NULL,
    rollback_reason TEXT NULL
);

-- Policy rollout events: append-only rollout history
CREATE TABLE IF NOT EXISTS policy_rollout_events (
    event_id TEXT PRIMARY KEY,
    rollout_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    base_policy_version TEXT NOT NULL,
    candidate_policy_version TEXT NULL,
    stage_before TEXT NULL,
    stage_after TEXT NULL,
    ratio_before NUMERIC(6,5) NULL,
    ratio_after NUMERIC(6,5) NULL,
    reason_json JSONB NULL,
    metrics_snapshot_json JSONB NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Policy optimization runs: offline optimizer execution history
CREATE TABLE IF NOT EXISTS policy_optimization_runs (
    run_id TEXT PRIMARY KEY,
    base_policy_version TEXT NOT NULL,
    proposed_policy_version TEXT NULL,
    trigger_type TEXT NOT NULL,
    metrics_snapshot_id TEXT NULL,
    window_start_ms BIGINT NULL,
    window_end_ms BIGINT NULL,
    metrics_snapshot_json JSONB NULL,
    proposal_json JSONB NULL,
    validation_result_json JSONB NULL,
    result_status TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    finished_at TIMESTAMPTZ NULL
);

-- Post-review runs: backoffice copilot execution history
CREATE TABLE IF NOT EXISTS post_review_runs (
    id BIGSERIAL PRIMARY KEY,
    match_id TEXT NOT NULL,
    window_start_ms BIGINT NOT NULL,
    window_end_ms BIGINT NOT NULL,
    status TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ NULL
);

-- Post-review session results: final review results per session
CREATE TABLE IF NOT EXISTS post_review_session_results (
    id BIGSERIAL PRIMARY KEY,
    post_review_run_id BIGINT NOT NULL REFERENCES post_review_runs(id),
    session_id TEXT NOT NULL,
    match_id TEXT NULL,
    final_label TEXT NOT NULL,
    decision_summary_json JSONB NOT NULL,
    evidence_json JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_policy_versions_status ON policy_versions(status);
CREATE INDEX IF NOT EXISTS idx_policy_rollout_events_rollout_id ON policy_rollout_events(rollout_id);
CREATE INDEX IF NOT EXISTS idx_policy_optimization_runs_status ON policy_optimization_runs(result_status);
CREATE INDEX IF NOT EXISTS idx_post_review_runs_match_id ON post_review_runs(match_id);
CREATE INDEX IF NOT EXISTS idx_post_review_session_results_session_id ON post_review_session_results(session_id);
