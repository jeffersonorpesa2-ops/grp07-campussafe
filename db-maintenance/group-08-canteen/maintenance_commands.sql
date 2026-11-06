-- ============================================================================
-- Group 7 Evaluation of Group 8 (bwisIT Solutions - Campus Canteen Pre-Order)
-- Activity 5: Database Maintenance and Monitoring Commands
-- Target Database: grp08_canteendb
-- Target RDBMS: PostgreSQL 18.6
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. DATABASE HEALTH & STORAGE OVERVIEW
-- ----------------------------------------------------------------------------
SELECT version();

-- Database physical footprint
SELECT pg_size_pretty(pg_database_size('grp08_canteendb')) AS db_size;

-- Table and Index physical storage footprint
SELECT relname AS table_name,
       pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size,
       pg_size_pretty(pg_relation_size(c.oid)) AS table_size,
       pg_size_pretty(pg_indexes_size(c.oid)) AS index_size
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind = 'r'
ORDER BY pg_total_relation_size(c.oid) DESC;

-- Cache hit ratio & transaction performance metrics
SELECT datname, numbackends, xact_commit, xact_rollback,
       blks_read, blks_hit,
       ROUND(blks_hit::numeric / NULLIF(blks_hit + blks_read, 0) * 100, 2) AS cache_hit_ratio,
       conflicts, deadlocks
FROM pg_stat_database
WHERE datname = 'grp08_canteendb';

-- ----------------------------------------------------------------------------
-- 2. CONNECTION & SESSION ACTIVITY MONITORING
-- ----------------------------------------------------------------------------
SHOW max_connections;

SELECT count(*) AS total_connections,
       count(*) FILTER (WHERE state = 'active') AS active_connections,
       count(*) FILTER (WHERE state = 'idle') AS idle_connections,
       count(*) FILTER (WHERE state = 'idle in transaction') AS idle_in_transaction
FROM pg_stat_activity;

SELECT pid, usename, client_addr, state, backend_start, query 
FROM pg_stat_activity 
WHERE datname = 'grp08_canteendb';

-- ----------------------------------------------------------------------------
-- 3. TABLE STATISTICS & DEAD TUPLE BLOAT ANALYSIS
-- ----------------------------------------------------------------------------
SELECT relname, n_live_tup, n_dead_tup,
       ROUND(n_dead_tup::numeric / NULLIF(n_live_tup + n_dead_tup, 0) * 100, 2) AS dead_tuple_ratio,
       last_vacuum, last_autovacuum, last_analyze, last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

-- ----------------------------------------------------------------------------
-- 4. ROUTINE MAINTENANCE OPERATIONS
-- ----------------------------------------------------------------------------
-- Non-admin vacuum denial test (should warn/fail for non-owners)
-- \c grp08_canteendb canteen_app
-- VACUUM customer_order;

-- Administrative vacuum and analyze (run as superuser/owner)
-- \c grp08_canteendb postgres
ANALYZE VERBOSE;
VACUUM (VERBOSE, ANALYZE);

-- ----------------------------------------------------------------------------
-- 5. QUERY PERFORMANCE ANALYSIS: QUERY 1 (ACTIVE QUEUE & ORDERS)
-- ----------------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT co.order_id,
       qe.queue_number,
       qe.status AS queue_status,
       s.full_name AS student_name,
       v.vendor_name,
       co.pickup_time,
       co.status AS order_status,
       COUNT(oi.order_item_id) AS total_items,
       SUM(oi.quantity * oi.price_at_order) AS order_total
FROM customer_order co
JOIN queue_entry qe ON co.order_id = qe.order_id
JOIN student s ON co.student_id = s.student_id
JOIN vendor v ON co.vendor_id = v.vendor_id
JOIN order_item oi ON co.order_id = oi.order_id
WHERE qe.status IN ('waiting', 'called')
GROUP BY co.order_id, qe.queue_number, qe.status, s.full_name, v.vendor_name, co.pickup_time, co.status
ORDER BY qe.queue_number ASC;

-- ----------------------------------------------------------------------------
-- 6. QUERY PERFORMANCE ANALYSIS: QUERY 2 (VENDOR SALES PERFORMANCE)
-- ----------------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT v.vendor_id,
       v.vendor_name,
       COUNT(DISTINCT co.order_id) AS completed_orders,
       COALESCE(SUM(oi.quantity), 0) AS total_items_sold,
       COALESCE(SUM(oi.quantity * oi.price_at_order), 0.00) AS gross_revenue,
       ROUND(COALESCE(AVG(oi.quantity * oi.price_at_order), 0.00), 2) AS avg_item_revenue,
       (SELECT COUNT(*) FROM menu_item mi WHERE mi.vendor_id = v.vendor_id AND mi.is_available = TRUE) AS active_menu_items
FROM vendor v
LEFT JOIN customer_order co ON v.vendor_id = co.vendor_id AND co.status = 'completed'
LEFT JOIN order_item oi ON co.order_id = oi.order_id
GROUP BY v.vendor_id, v.vendor_name
ORDER BY gross_revenue DESC;

-- ----------------------------------------------------------------------------
-- 7. RECOMMENDED INDEX OPTIMIZATIONS
-- ----------------------------------------------------------------------------
-- Foreign key indexing for joins on orders and line items
CREATE INDEX IF NOT EXISTS idx_customer_order_vendor ON customer_order(vendor_id);
CREATE INDEX IF NOT EXISTS idx_customer_order_student ON customer_order(student_id);
CREATE INDEX IF NOT EXISTS idx_order_item_order_id ON order_item(order_id);
CREATE INDEX IF NOT EXISTS idx_order_item_item_id ON order_item(item_id);

-- Partial index for active queue lookup
CREATE INDEX IF NOT EXISTS idx_queue_active ON queue_entry(queue_date, status) WHERE status IN ('waiting', 'called');

-- Composite index for vendor menu item availability
CREATE INDEX IF NOT EXISTS idx_menu_item_vendor_avail ON menu_item(vendor_id, is_available);
