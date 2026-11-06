-- ============================================================================
-- Group 7 Evaluation of Group HabalGo (HabalGo - Ride and Booking System)
-- Activity 5: Database Maintenance Commands
-- Database: grp00_habalgodb
-- Schema: habalgo
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
WHERE schemaname = 'habalgo'
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
WHERE schemaname = 'habalgo'
ORDER BY n_live_tup DESC;

-- 4. Routine Maintenance (Execute as DBA / Owner)
ANALYZE;
VACUUM (VERBOSE, ANALYZE) habalgo.customer;
VACUUM (VERBOSE, ANALYZE) habalgo.driver;
VACUUM (VERBOSE, ANALYZE) habalgo.vehicle;
VACUUM (VERBOSE, ANALYZE) habalgo.booking;
VACUUM (VERBOSE, ANALYZE) habalgo.payment;

-- 5. Query 1: Active Booking Fleet Dispatch & Route Lookup
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    b.booking_id,
    c.name AS customer_name,
    d.name AS driver_name,
    v.plate_no,
    v.model AS vehicle_model,
    loc_p.address AS pickup_address,
    loc_d.address AS dropoff_address,
    b.booking_status,
    b.booking_date
FROM habalgo.booking b
JOIN habalgo.customer c ON b.customer_id = c.customer_id
LEFT JOIN habalgo.driver d ON b.driver_id = d.driver_id
LEFT JOIN habalgo.driver_vehicle dv ON d.driver_id = dv.driver_id AND dv.assigned_to IS NULL
LEFT JOIN habalgo.vehicle v ON dv.vehicle_id = v.vehicle_id
JOIN habalgo.location loc_p ON b.pickup_location_id = loc_p.location_id
JOIN habalgo.location loc_d ON b.dropoff_location_id = loc_d.location_id
WHERE b.booking_status IN ('Pending', 'Confirmed', 'In Progress')
ORDER BY b.booking_date DESC;

-- 6. Query 2: Daily Revenue and Payment Reconciliation by Payment Method
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    p.method,
    p.status AS payment_status,
    count(p.payment_id) AS transaction_count,
    sum(p.amount) AS total_revenue,
    round(avg(p.amount), 2) AS avg_fare
FROM habalgo.payment p
JOIN habalgo.booking b ON p.booking_id = b.booking_id
GROUP BY p.method, p.status
ORDER BY total_revenue DESC;
