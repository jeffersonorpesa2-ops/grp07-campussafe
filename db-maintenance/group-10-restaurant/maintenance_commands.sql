-- ============================================================================
-- Group 7 Evaluation of Group 10 (Binary Sisters - Restaurant Ordering & Reservation)
-- Activity 5: Database Maintenance and Monitoring Commands
-- Target Database: grp_binarysisters_projectdb
-- Target RDBMS: PostgreSQL 18.6
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. DATABASE HEALTH & STORAGE OVERVIEW
-- ----------------------------------------------------------------------------
SELECT version();

-- Database physical footprint
SELECT pg_size_pretty(pg_database_size('grp_binarysisters_projectdb')) AS db_size;

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
WHERE datname = 'grp_binarysisters_projectdb';

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
WHERE datname = 'grp_binarysisters_projectdb';

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
-- 4.1 Non-admin vacuum denial test (should warn/skip for non-owners)
-- \c grp_binarysisters_projectdb rors_app
-- VACUUM orders;

-- 4.2 Maintenance operator vacuum execution (succeeds via pg_maintain)
-- \c grp_binarysisters_projectdb rors_maint
-- VACUUM customer;

-- 4.3 Administrative vacuum and analyze (run as superuser/owner)
-- \c grp_binarysisters_projectdb postgres
ANALYZE VERBOSE;
VACUUM (VERBOSE, ANALYZE);

-- ----------------------------------------------------------------------------
-- 5. QUERY PERFORMANCE ANALYSIS: QUERY 1 (KITCHEN DISPLAY & ACTIVE ORDERS)
-- ----------------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT o.order_id,
       c.first_name || ' ' || c.last_name AS customer_name,
       c.phone,
       o.order_date,
       o.order_status,
       o.total_amount,
       p.payment_method,
       p.payment_status,
       COUNT(oi.menu_item_id) AS line_item_count,
       SUM(oi.quantity) AS total_units_ordered
FROM orders o
JOIN customer c ON o.customer_id = c.customer_id
LEFT JOIN payment p ON o.order_id = p.order_id
JOIN order_item oi ON o.order_id = oi.order_id
WHERE o.order_status IN ('pending', 'confirmed', 'preparing', 'ready')
GROUP BY o.order_id, c.first_name, c.last_name, c.phone, o.order_date, o.order_status, o.total_amount, p.payment_method, p.payment_status
ORDER BY o.order_date DESC;

-- ----------------------------------------------------------------------------
-- 6. QUERY PERFORMANCE ANALYSIS: QUERY 2 (POPULAR MENU CATEGORY & REVENUE)
-- ----------------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT mi.category,
       COUNT(DISTINCT mi.menu_item_id) AS items_in_category,
       COUNT(oi.order_id) AS times_ordered,
       COALESCE(SUM(oi.quantity), 0) AS total_units_sold,
       COALESCE(SUM(oi.subtotal), 0.00) AS gross_revenue,
       ROUND(AVG(mi.price), 2) AS avg_item_price,
       ROUND(COALESCE(SUM(oi.subtotal) / NULLIF(SUM(oi.quantity), 0), 0.00), 2) AS avg_sold_price
FROM menu_item mi
LEFT JOIN order_item oi ON mi.menu_item_id = oi.menu_item_id
LEFT JOIN orders o ON oi.order_id = o.order_id AND o.order_status = 'completed'
GROUP BY mi.category
ORDER BY gross_revenue DESC;

-- ----------------------------------------------------------------------------
-- 7. RECOMMENDED INDEX OPTIMIZATIONS
-- ----------------------------------------------------------------------------
-- Partial index on orders for active kitchen queue polling
CREATE INDEX IF NOT EXISTS idx_orders_active_queue 
ON orders (order_date DESC) 
WHERE order_status IN ('pending', 'confirmed', 'preparing', 'ready');

-- Covering index on order items for fast category sales aggregation
CREATE INDEX IF NOT EXISTS idx_order_item_covering 
ON order_item (menu_item_id) 
INCLUDE (quantity, subtotal);
