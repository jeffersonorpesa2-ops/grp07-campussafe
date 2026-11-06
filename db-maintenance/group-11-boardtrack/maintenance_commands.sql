-- =============================================================================
-- Database Administration (COMP 018) — Activity 5: Maintenance Commands
-- Target Project: Group 11 — BoardTrack (Boarding House & Rental Management System)
-- Evaluating Group: Group 7 (Alba, Arreza, Orpesa, Robiso, Santos)
-- Database Engine: PostgreSQL 18.6 on x86_64 Windows
-- Target Database: grp11_boardtrackdb
-- File: maintenance_commands.sql
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Database and Storage Health Inspection
-- -----------------------------------------------------------------------------

-- 1.1 Total Database Physical Disk Footprint
SELECT 
    datname AS database_name,
    pg_size_pretty(pg_database_size('grp11_boardtrackdb')) AS database_size
FROM pg_database
WHERE datname = 'grp11_boardtrackdb';

-- 1.2 Table and Index Breakdown
SELECT 
    relname AS relation_name,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size,
    pg_size_pretty(pg_relation_size(c.oid)) AS table_size,
    pg_size_pretty(pg_total_relation_size(c.oid) - pg_relation_size(c.oid)) AS index_size
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind = 'r'
ORDER BY pg_total_relation_size(c.oid) DESC;

-- 1.3 Shared Buffer Cache Hit Ratio
SELECT 
    datname,
    blks_read,
    blks_hit,
    ROUND((blks_hit::numeric / NULLIF(blks_hit + blks_read, 0)::numeric) * 100, 2) AS cache_hit_ratio_pct
FROM pg_stat_database
WHERE datname = 'grp11_boardtrackdb';

-- 1.4 Active Sessions and Connection States
SELECT 
    pid, usename, client_addr, state, backend_start, query
FROM pg_stat_activity
WHERE datname = 'grp11_boardtrackdb';

-- -----------------------------------------------------------------------------
-- 2. Dead Tuple and Bloat Analysis (pg_stat_user_tables)
-- -----------------------------------------------------------------------------
SELECT 
    relname,
    n_live_tup,
    n_dead_tup,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze,
    vacuum_count,
    analyze_count
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC;

-- -----------------------------------------------------------------------------
-- 3. Routine Maintenance Execution (DBA / Maintenance User)
-- -----------------------------------------------------------------------------

-- 3.1 Non-privileged execution denial (run as boardtrack_app)
-- WARNING: permission denied to vacuum "room", skipping it
-- VACUUM room;

-- 3.2 Update Statistics and Execution Plans
ANALYZE VERBOSE;

-- 3.3 Reclaim Dead Tuples, Update Visibility Maps, and Refresh Statistics
VACUUM (VERBOSE, ANALYZE);

-- -----------------------------------------------------------------------------
-- 4. Targeted Indexing Optimizations
-- -----------------------------------------------------------------------------

-- 4.1 Partial Index for Active Lease Contracts (Filtering Out Expired/Terminated)
CREATE INDEX IF NOT EXISTS idx_lease_active 
ON lease(lease_id, room_id, tenant_id, monthly_rent) 
WHERE status = 'ACTIVE';

-- 4.2 Composite Covering Index for Rent Collections and Payment Verification
CREATE INDEX IF NOT EXISTS idx_payment_lease_status 
ON payment(lease_id, status) 
INCLUDE (amount);

-- 4.3 Partial Index for Unpaid Utility Arrears Tracking
CREATE INDEX IF NOT EXISTS idx_utility_bill_unpaid 
ON utility_bill(lease_id, amount) 
WHERE status = 'UNPAID';

-- -----------------------------------------------------------------------------
-- 5. Query Performance Profiling with EXPLAIN (ANALYZE, BUFFERS)
-- -----------------------------------------------------------------------------

-- 5.1 Query 1: Delinquent & Pending Tenant Collections Report
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    p.property_name,
    r.room_number,
    t.full_name AS tenant_name,
    t.contact_number,
    l.lease_id,
    l.monthly_rent,
    COALESCE(SUM(pay.amount) FILTER (WHERE pay.status = 'PENDING'), 0) AS pending_rent_amount,
    COALESCE(SUM(ub.amount) FILTER (WHERE ub.status = 'UNPAID'), 0) AS unpaid_utility_amount
FROM lease l
JOIN tenant t ON t.tenant_id = l.tenant_id
JOIN room r ON r.room_id = l.room_id
JOIN property p ON p.property_id = r.property_id
LEFT JOIN payment pay ON pay.lease_id = l.lease_id
LEFT JOIN utility_bill ub ON ub.lease_id = l.lease_id
WHERE l.status = 'ACTIVE'
GROUP BY p.property_name, r.room_number, t.full_name, t.contact_number, l.lease_id, l.monthly_rent
ORDER BY p.property_name, r.room_number;

-- 5.2 Query 2: Property Occupancy & Revenue Performance Analysis
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    p.property_id,
    p.property_name,
    COUNT(DISTINCT r.room_id) AS total_rooms,
    COUNT(DISTINCT l.lease_id) FILTER (WHERE l.status = 'ACTIVE') AS occupied_rooms,
    ROUND(
        (COUNT(DISTINCT l.lease_id) FILTER (WHERE l.status = 'ACTIVE')::numeric / NULLIF(COUNT(DISTINCT r.room_id), 0)::numeric) * 100, 
        2
    ) AS occupancy_rate_pct,
    COALESCE(SUM(l.monthly_rent) FILTER (WHERE l.status = 'ACTIVE'), 0) AS total_active_rent_contracted,
    COALESCE(SUM(pay.amount) FILTER (WHERE pay.status = 'COMPLETED'), 0) AS total_revenue_collected
FROM property p
JOIN room r ON r.property_id = p.property_id
LEFT JOIN lease l ON l.room_id = r.room_id
LEFT JOIN payment pay ON pay.lease_id = l.lease_id
GROUP BY p.property_id, p.property_name
ORDER BY p.property_id;
