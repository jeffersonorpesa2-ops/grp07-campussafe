-- =============================================================================
-- COMP 018: Database Administration - Midterm Examination
-- Group 7 (CampusSafe) - Owner Universal Diagnostic & Inspection Suite
-- Purpose: Rapidly detect anomalies, revoked grants, dropped objects, sequence
--          desynchronization, bloat, or missing indexes injected by peer designer.
-- Target Database: grp07_campussafedb_disposable
-- =============================================================================

-- -----------------------------------------------------------------------------
-- CHECK 1: Database Identity, Connection Context & Current User
-- -----------------------------------------------------------------------------
SELECT 
    current_database() AS connected_db,
    current_user AS session_user,
    session_user AS logged_in_user,
    inet_server_addr() AS server_ip,
    inet_server_port() AS server_port,
    pg_is_in_recovery() AS is_in_recovery;

-- -----------------------------------------------------------------------------
-- CHECK 2: Table & View Inventory vs. Expected Baseline (9 Tables, 1 View)
-- Baseline Expected Tables:
--   app_user, user_role, location, hazard_category, hazard_report,
--   hazard_photo, report_status_history, assignment, system_audit_log
-- Baseline Expected Views:
--   v_user_directory
-- -----------------------------------------------------------------------------
SELECT 
    table_schema,
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_type, table_name;

-- -----------------------------------------------------------------------------
-- CHECK 3: Table Row Counts Across All Entities
-- -----------------------------------------------------------------------------
SELECT 'app_user' AS entity, count(*) AS total_rows FROM app_user
UNION ALL SELECT 'user_role', count(*) FROM user_role
UNION ALL SELECT 'location', count(*) FROM location
UNION ALL SELECT 'hazard_category', count(*) FROM hazard_category
UNION ALL SELECT 'hazard_report', count(*) FROM hazard_report
UNION ALL SELECT 'hazard_photo', count(*) FROM hazard_photo
UNION ALL SELECT 'report_status_history', count(*) FROM report_status_history
UNION ALL SELECT 'assignment', count(*) FROM assignment
UNION ALL SELECT 'system_audit_log', count(*) FROM system_audit_log
ORDER BY entity;

-- -----------------------------------------------------------------------------
-- CHECK 4: Role Grants & Table Privilege Verification
-- Inspect if runtime, readonly, or backup roles lost permissions
-- -----------------------------------------------------------------------------
SELECT 
    grantee, 
    table_name, 
    string_agg(privilege_type, ', ' ORDER BY privilege_type) AS granted_privileges
FROM information_schema.role_table_grants
WHERE table_schema = 'public' 
  AND grantee IN ('app_runtime_grp', 'app_readonly_grp', 'app_backup_grp', 'campussafe_app', 'campussafe_auditor', 'campussafe_backup', 'public')
GROUP BY grantee, table_name
ORDER BY grantee, table_name;

-- -----------------------------------------------------------------------------
-- CHECK 5: Sequence State & Desynchronization Check
-- Critical: Detects if designer group reset sequence causing 'duplicate key' errors
-- -----------------------------------------------------------------------------
SELECT 
    s.sequencename,
    s.last_value,
    s.start_value,
    s.increment_by,
    CASE 
        WHEN s.sequencename = 'hazard_report_report_id_seq' THEN (SELECT COALESCE(MAX(report_id), 0) FROM hazard_report)
        WHEN s.sequencename = 'app_user_user_id_seq' THEN (SELECT COALESCE(MAX(user_id), 0) FROM app_user)
        WHEN s.sequencename = 'location_location_id_seq' THEN (SELECT COALESCE(MAX(location_id), 0) FROM location)
        WHEN s.sequencename = 'hazard_category_category_id_seq' THEN (SELECT COALESCE(MAX(category_id), 0) FROM hazard_category)
        WHEN s.sequencename = 'hazard_photo_photo_id_seq' THEN (SELECT COALESCE(MAX(photo_id), 0) FROM hazard_photo)
        WHEN s.sequencename = 'report_status_history_history_id_seq' THEN (SELECT COALESCE(MAX(history_id), 0) FROM report_status_history)
        WHEN s.sequencename = 'assignment_assignment_id_seq' THEN (SELECT COALESCE(MAX(assignment_id), 0) FROM assignment)
        WHEN s.sequencename = 'system_audit_log_audit_id_seq' THEN (SELECT COALESCE(MAX(audit_id), 0) FROM system_audit_log)
        ELSE NULL
    END AS current_max_table_id,
    CASE 
        WHEN s.last_value < CASE 
            WHEN s.sequencename = 'hazard_report_report_id_seq' THEN (SELECT COALESCE(MAX(report_id), 0) FROM hazard_report)
            WHEN s.sequencename = 'app_user_user_id_seq' THEN (SELECT COALESCE(MAX(user_id), 0) FROM app_user)
            WHEN s.sequencename = 'location_location_id_seq' THEN (SELECT COALESCE(MAX(location_id), 0) FROM location)
            WHEN s.sequencename = 'hazard_category_category_id_seq' THEN (SELECT COALESCE(MAX(category_id), 0) FROM hazard_category)
            WHEN s.sequencename = 'hazard_photo_photo_id_seq' THEN (SELECT COALESCE(MAX(photo_id), 0) FROM hazard_photo)
            WHEN s.sequencename = 'report_status_history_history_id_seq' THEN (SELECT COALESCE(MAX(history_id), 0) FROM report_status_history)
            WHEN s.sequencename = 'assignment_assignment_id_seq' THEN (SELECT COALESCE(MAX(assignment_id), 0) FROM assignment)
            WHEN s.sequencename = 'system_audit_log_audit_id_seq' THEN (SELECT COALESCE(MAX(audit_id), 0) FROM system_audit_log)
            ELSE 0
        END THEN 'CRITICAL: SEQUENCE DESYNCHRONIZED (INSERT WILL FAIL)'
        ELSE 'SYNCHRONIZED'
    END AS sync_status
FROM pg_sequences s
ORDER BY s.sequencename;

-- -----------------------------------------------------------------------------
-- CHECK 6: Foreign Key & Check Constraint Integrity
-- Detects if designer dropped a constraint or disabled referential integrity
-- -----------------------------------------------------------------------------
SELECT 
    conrelid::regclass AS table_name,
    conname AS constraint_name,
    contype AS constraint_type, -- p=primary, f=foreign key, c=check, u=unique
    pg_get_constraintdef(c.oid) AS constraint_definition
FROM pg_constraint c
WHERE connamespace = 'public'::regnamespace
ORDER BY table_name, constraint_name;

-- -----------------------------------------------------------------------------
-- CHECK 7: Index Inventory & Verification
-- Detects if an index was dropped causing slow sequential scan performance
-- -----------------------------------------------------------------------------
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- -----------------------------------------------------------------------------
-- CHECK 8: Table Dead Tuple Bloat & Statistics
-- Detects if designer generated artificial bloat or stale stats
-- -----------------------------------------------------------------------------
SELECT 
    relname AS table_name,
    n_live_tup AS live_tuples,
    n_dead_tup AS dead_tuples,
    ROUND((n_dead_tup::numeric / NULLIF(n_live_tup + n_dead_tup, 0)::numeric) * 100, 2) AS dead_tuple_pct,
    last_vacuum,
    last_analyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

-- -----------------------------------------------------------------------------
-- CHECK 9: Active Locks & Blocked Queries
-- Detects if designer injected an uncommitted transaction causing lock hangs
-- -----------------------------------------------------------------------------
SELECT 
    pid, 
    usename, 
    state, 
    query, 
    now() - query_start AS query_age,
    wait_event_type, 
    wait_event
FROM pg_stat_activity
WHERE state != 'idle' 
  AND pid <> pg_backend_pid();
