-- ============================================================================
-- Group 7 Evaluation of Group 2 (Park-It Database Management System)
-- Activity 5: Database Maintenance Commands
-- Database: grp_parkitdb
-- Target RDBMS: PostgreSQL 18.6
-- ============================================================================

-- 1. Database Health & Storage Overview
SELECT version() AS postgresql_version;
SELECT current_database() AS database_name, current_user AS connected_user;
SELECT pg_size_pretty(pg_database_size(current_database())) AS total_db_size;

SELECT 
    table_name,
    pg_size_pretty(pg_total_relation_size(quote_ident(table_name))) AS total_size,
    pg_size_pretty(pg_relation_size(quote_ident(table_name))) AS table_size,
    pg_size_pretty(pg_indexes_size(quote_ident(table_name))) AS index_size
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
ORDER BY pg_total_relation_size(quote_ident(table_name)) DESC;

-- 2. Connections, Commits and Conflicts
SELECT 
    datname, 
    numbackends AS open_connections,
    xact_commit AS committed_transactions,
    xact_rollback AS rolled_back_transactions,
    conflicts,
    deadlocks
FROM pg_stat_database
WHERE datname = current_database();

-- 3. Dead Tuples and Table Bloat Inspection
SELECT 
    relname AS table_name,
    seq_scan AS sequential_scans,
    seq_tup_read AS tuples_read_by_seq_scan,
    idx_scan AS index_scans,
    n_live_tup AS live_tuples,
    n_dead_tup AS dead_tuples,
    last_vacuum, last_autovacuum, last_analyze, last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

-- 4. Routine Maintenance (Execute as DBA / Owner)
ANALYZE;
VACUUM (VERBOSE, ANALYZE) public.parking_zone;
VACUUM (VERBOSE, ANALYZE) public.transaction;
VACUUM (VERBOSE, ANALYZE) public.payment;

-- 5. Query 1: Active Parking Sessions by Zone and Recency
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    t.transaction_id,
    v.license_plate,
    v.vehicle_type,
    z.zone_name,
    t.entry_time,
    t.status
FROM transaction t
JOIN vehicle v ON t.vehicle_id = v.vehicle_id
JOIN parking_zone z ON t.zone_id = z.zone_id
WHERE t.status = 'Active'
ORDER BY t.entry_time DESC;

-- 6. Query 2: Daily Parking Revenue & Collections by Payment Method
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    p.payment_method,
    count(p.payment_id) AS total_payments,
    sum(p.amount) AS total_revenue,
    avg(p.amount) AS avg_fee
FROM payment p
JOIN transaction t ON p.transaction_id = t.transaction_id
WHERE p.payment_time >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY p.payment_method
ORDER BY total_revenue DESC;
