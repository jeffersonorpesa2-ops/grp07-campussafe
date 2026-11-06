-- ============================================================================
-- Group 7 Evaluation of Group OJT-RMA (Project-OJT-RMA-System)
-- Activity 5: Database Maintenance Commands
-- Database: ojt_managementdb
-- Target RDBMS: PostgreSQL 18.6
-- ============================================================================

-- 1. Database Health & Storage Overview
SELECT version() AS postgresql_version;
SELECT current_database() AS database_name, current_user AS connected_user;
SELECT pg_size_pretty(pg_database_size(current_database())) AS total_db_size;

SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname || '.' || tablename)) AS table_size,
    pg_size_pretty(pg_indexes_size(schemaname || '.' || tablename)) AS index_size
FROM pg_tables
WHERE schemaname IN ('public', 'lending')
ORDER BY pg_total_relation_size(schemaname || '.' || tablename) DESC;

-- 2. Connections, Commits and Conflicts
SELECT 
    datname, 
    numbackends AS open_connections,
    xact_commit AS committed_transactions,
    xact_rollback AS rolled_back_transactions,
    conflicts,
    deadlocks,
    blks_read,
    blks_hit
FROM pg_stat_database
WHERE datname = current_database();

-- 3. Dead Tuples and Table Bloat Inspection
SELECT 
    schemaname,
    relname AS table_name,
    seq_scan AS sequential_scans,
    seq_tup_read AS tuples_read_by_seq_scan,
    idx_scan AS index_scans,
    n_live_tup AS live_tuples,
    n_dead_tup AS dead_tuples,
    last_vacuum, 
    last_analyze
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC;

-- 4. Routine Maintenance (Execute as DBA / Owner)
ANALYZE;
VACUUM (VERBOSE, ANALYZE) public.attendance;
VACUUM (VERBOSE, ANALYZE) public.student_requirements;
VACUUM (VERBOSE, ANALYZE) public.users;

-- 5. Query 1: Active Student Placements & Hours Rendered
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    s.student_id,
    s.student_number,
    s.first_name || ' ' || s.last_name AS full_name,
    c.company_name,
    p.status,
    p.required_hours,
    COALESCE(SUM(a.hours_rendered), 0) AS total_hours_rendered,
    p.required_hours - COALESCE(SUM(a.hours_rendered), 0) AS hours_remaining
FROM students s
JOIN ojt_placements p ON s.student_id = p.student_id
JOIN companies c ON p.company_id = c.company_id
LEFT JOIN attendance a ON p.placement_id = a.placement_id
WHERE p.status = 'Active'
GROUP BY s.student_id, s.student_number, s.first_name, s.last_name, c.company_name, p.status, p.required_hours
ORDER BY total_hours_rendered DESC;

-- 6. Query 2: Mandatory Requirement Compliance Status
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    s.student_number,
    s.first_name || ' ' || s.last_name AS full_name,
    r.title AS requirement_title,
    r.is_mandatory,
    sr.status AS submission_status,
    sr.submission_date
FROM student_requirements sr
JOIN students s ON sr.student_id = s.student_id
JOIN requirements r ON sr.req_id = r.req_id
WHERE r.is_mandatory = TRUE
ORDER BY s.student_number, sr.submission_date DESC;
