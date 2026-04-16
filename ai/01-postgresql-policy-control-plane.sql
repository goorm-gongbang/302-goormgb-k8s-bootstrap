-- ============================================================
-- AI Defense - PostgreSQL Policy Control Plane Tables
-- Staging Environment
--
-- Source: 201-goormgb-ai/src/traffic_master_ai/defense/backoffice_copilot/storage/sql/
--   - 002_postgresql_policy_control_plane_tables.sql (policy tables)
--   - 001_post_review_tables.sql (post-review tables — SSOT)
--
-- Schema history:
--   Original bootstrap had an outdated post_review_runs / post_review_session_results
--   schema (BIGSERIAL PK, final_label, FK-linked design) that diverged from the AI
--   code's actual save_bundle() contract. This file now carries the correct final
--   schema so that any fresh environment is immediately aligned with the AI code.
--
-- IMPORTANT: If applying to an environment that was bootstrapped with the old schema
--   (post_review_runs.id BIGSERIAL PK), run the AI migration command first:
--     tm-ai-storage-migrate
--   Migration 007_post_review_tables_rebuild.sql detects and replaces the old schema.
-- ============================================================

-- ============================================================
-- Policy Control Plane Tables
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

-- ============================================================
-- Post-Review Persistence Tables (final schema — SSOT)
--
-- Schema contract (aligned with save_bundle() in repository.py):
--   post_review_runs      PK: match_id TEXT
--   post_review_session_results  PK: (match_id, session_id)
--
-- Column design rationale:
--   - match_id TEXT PRIMARY KEY: natural business key; avoids surrogate BIGSERIAL
--   - candidate_count / suspicious_count: required for run-level summary analytics
--   - summary_text_json: JSONB array[3] — three structured text lines per run
--   - review_result: NORMAL | SUSPICIOUS (NOT final_label — that was the old design)
--   - evidence_summary: free-text evidence string per session
--   - session_analysis_json: full SessionAnalysis object as JSONB for audit trail
--   - backend_delivery_status: PENDING | SENT | FAILED delivery state machine
--   - updated_at: explicit timestamp updated on every UPSERT (no trigger dependency)
-- ============================================================

-- Post-review runs: one row per match_id window execution
CREATE TABLE IF NOT EXISTS post_review_runs (
    match_id TEXT PRIMARY KEY,
    window_start_ms BIGINT NOT NULL,
    window_end_ms BIGINT NOT NULL,
    candidate_count INTEGER NOT NULL,
    suspicious_count INTEGER NOT NULL,
    summary_text_json JSONB NOT NULL,
    status TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT post_review_runs_status_check
        CHECK (status IN ('SUCCESS', 'PARTIAL_SUCCESS', 'FAILED')),
    CONSTRAINT post_review_runs_counts_check
        CHECK (candidate_count >= suspicious_count),
    CONSTRAINT post_review_runs_summary_text_json_check
        CHECK (
            jsonb_typeof(summary_text_json) = 'array'
            AND jsonb_array_length(summary_text_json) = 3
        )
);

-- Post-review session results: one row per (match_id, session_id) pair
CREATE TABLE IF NOT EXISTS post_review_session_results (
    match_id TEXT NOT NULL,
    session_id TEXT NOT NULL,
    review_result TEXT NOT NULL,
    evidence_summary TEXT NOT NULL,
    session_analysis_json JSONB NOT NULL,
    backend_delivery_status TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (match_id, session_id),
    CONSTRAINT post_review_session_results_review_result_check
        CHECK (review_result IN ('NORMAL', 'SUSPICIOUS')),
    CONSTRAINT post_review_session_results_backend_delivery_status_check
        CHECK (backend_delivery_status IN ('PENDING', 'SENT', 'FAILED')),
    CONSTRAINT post_review_session_results_session_analysis_json_check
        CHECK (jsonb_typeof(session_analysis_json) = 'object')
);

-- ============================================================
-- Indexes
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_policy_versions_status
    ON policy_versions(status);

CREATE INDEX IF NOT EXISTS idx_policy_rollout_events_rollout_id
    ON policy_rollout_events(rollout_id);

CREATE INDEX IF NOT EXISTS idx_policy_optimization_runs_status
    ON policy_optimization_runs(result_status);

-- post_review_runs: match_id is already PRIMARY KEY (implicitly indexed)
-- Additional index for time-range queries on window
CREATE INDEX IF NOT EXISTS idx_post_review_runs_window
    ON post_review_runs(window_start_ms, window_end_ms);

-- post_review_session_results: (match_id, session_id) is already PRIMARY KEY
-- Additional index for per-session queries across runs
CREATE INDEX IF NOT EXISTS idx_post_review_session_results_session_id
    ON post_review_session_results(session_id);
