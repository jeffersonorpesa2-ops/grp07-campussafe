-- ============================================================================
-- Group 7 Evaluation of Group 4 (BrewPOS)
-- Activity 5: Database Maintenance Commands
-- Database: grp_brewposdb
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
VACUUM (VERBOSE, ANALYZE) public.menu_item;
VACUUM (VERBOSE, ANALYZE) public.order_ticket;
VACUUM (VERBOSE, ANALYZE) public.order_line_item;

-- 5. Query 1: Daily Sales Filter by Date Range and Order Timestamp
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, staff_id, order_timestamp, payment_method
FROM order_ticket
WHERE order_timestamp >= CURRENT_DATE AND order_timestamp < CURRENT_DATE + INTERVAL '1 day'
ORDER BY order_timestamp DESC;

-- 6. Query 2: Multi-table Join for Receipt Generation
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    o.order_id,
    o.order_timestamp,
    o.payment_method,
    s.full_name AS cashier_name,
    m.item_name,
    c.category_name,
    l.quantity,
    l.sold_price,
    (l.quantity * l.sold_price) AS line_total
FROM order_ticket o
JOIN staff s ON o.staff_id = s.staff_id
JOIN order_line_item l ON o.order_id = l.order_id
JOIN menu_item m ON l.item_id = m.item_id
JOIN menu_category c ON m.category_id = c.category_id
WHERE o.order_id = 1;
