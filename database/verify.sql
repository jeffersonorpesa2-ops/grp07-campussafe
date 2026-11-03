-- =============================================================================
-- CampusSafe: Database Sanity and Integrity Verification (verify.sql)
-- Run to verify tables, row counts, constraints, and indexes.
-- =============================================================================

\echo '=== 1. TABLE ROW COUNTS ==='
SELECT 'role' AS table_name, COUNT(*) AS total_rows FROM role
UNION ALL SELECT 'app_user', COUNT(*) FROM app_user
UNION ALL SELECT 'hazard_category', COUNT(*) FROM hazard_category
UNION ALL SELECT 'campus_location', COUNT(*) FROM campus_location
UNION ALL SELECT 'hazard_report', COUNT(*) FROM hazard_report
UNION ALL SELECT 'assignment', COUNT(*) FROM assignment
UNION ALL SELECT 'report_status_history', COUNT(*) FROM report_status_history
UNION ALL SELECT 'maintenance_action', COUNT(*) FROM maintenance_action
UNION ALL SELECT 'attachment', COUNT(*) FROM attachment;

\echo '=== 2. STATUS DISTRIBUTION ==='
SELECT status, priority, COUNT(*) AS count
FROM hazard_report
GROUP BY status, priority
ORDER BY status, priority;

\echo '=== 3. CONSTRAINT INTEGRITY AUDIT ==='
-- A: Check if any unverified report has a verifier or priority (Should return 0)
SELECT COUNT(*) AS violation_unverified_with_verifier
FROM hazard_report
WHERE status = 'Submitted' AND (verified_by_user_id IS NOT NULL OR verified_at IS NOT NULL);

-- B: Check if any Resolved/Closed report is missing resolved_at (Should return 0)
SELECT COUNT(*) AS violation_resolved_missing_timestamp
FROM hazard_report
WHERE status IN ('Resolved', 'Closed') AND resolved_at IS NULL;

-- C: Check for any orphaned assignments or actions (Should return 0)
SELECT COUNT(*) AS orphaned_assignments
FROM assignment a
LEFT JOIN hazard_report r ON a.report_id = r.report_id
WHERE r.report_id IS NULL;

\echo '=== 4. RELATIONAL JOIN TEST (Sample Report Summary) ==='
SELECT
    r.report_id,
    u.full_name AS reporter,
    c.category_name AS category,
    l.building || ' - ' || l.room_area AS location,
    r.priority,
    r.status,
    COALESCE(m.full_name, 'Unassigned') AS assigned_tech,
    COUNT(h.history_id) AS history_steps
FROM hazard_report r
JOIN app_user u ON r.reporter_user_id = u.user_id
JOIN hazard_category c ON r.category_id = c.category_id
JOIN campus_location l ON r.location_id = l.location_id
LEFT JOIN assignment a ON r.report_id = a.report_id
LEFT JOIN app_user m ON a.maintenance_user_id = m.user_id
LEFT JOIN report_status_history h ON r.report_id = h.report_id
GROUP BY r.report_id, u.full_name, c.category_name, l.building, l.room_area, r.priority, r.status, m.full_name
ORDER BY r.report_id
LIMIT 10;

\echo '=== 5. INDEX STATUS ==='
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
