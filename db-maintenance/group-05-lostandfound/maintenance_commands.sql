-- ============================================================================
-- Group 7 Evaluation of Group 5 (PUP-SPOT — Campus Lost and Found)
-- Activity 5: Database Maintenance Commands
-- Database: grp05_lostandfounddb
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
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname || '.' || tablename) DESC;

-- 2. Connections, Commits, Conflicts, and Buffer Cache
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
VACUUM (VERBOSE, ANALYZE) public.items;
VACUUM (VERBOSE, ANALYZE) public.claims;
VACUUM (VERBOSE, ANALYZE) public.lost_reports;
VACUUM (VERBOSE, ANALYZE) public.potential_matches;

-- 5. Query 1: Public Item Catalog Search & Filtering
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    i.item_id,
    i.title,
    c.name AS category_name,
    i.location_found,
    i.date_found,
    i.time_found,
    i.status
FROM items i
JOIN categories c ON i.category_id = c.category_id
WHERE i.status = 'unclaimed'
ORDER BY i.date_found DESC, i.time_found DESC;

-- 6. Query 2: Potential Matches and Similarity Inspection
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    pm.match_id,
    lr.report_code,
    lr.title AS lost_title,
    lr.full_name AS reporter_name,
    i.title AS found_title,
    i.location_found,
    pm.similarity_score,
    pm.created_at
FROM potential_matches pm
JOIN lost_reports lr ON pm.report_id = lr.report_id
JOIN items i ON pm.item_id = i.item_id
WHERE pm.similarity_score >= 60.00
ORDER BY pm.similarity_score DESC;
