# Activity 5: Database Maintenance, Health Monitoring & Query Optimization

**System:** CampusSafe: Campus Hazard & Safety Reporting System  
**Course:** COMP 018 Database Administration &bull; Group 7  

---

## 1. Overview & Objectives

In Activity 5, you monitor database health, examine server logs, execute maintenance (`VACUUM` and `ANALYZE`), and inspect SQL execution plans using `EXPLAIN (ANALYZE, BUFFERS)` to diagnose bottlenecks and tune query performance.

---

## 2. Server Health Check Suite

Connect to `grp07_campussafedb` using your Activity 4 account or DBA role:

```sql
-- 1. Verify PostgreSQL Version and OS build
SELECT version();

-- 2. Database disk footprint
SELECT pg_size_pretty(pg_database_size('grp07_campussafedb')) AS total_db_size;

-- 3. Table and index sizes
SELECT
    relname AS object_name,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
    pg_size_pretty(pg_relation_size(relid)) AS table_size,
    pg_size_pretty(pg_indexes_size(relid)) AS index_size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;

-- 4. Active Connections and Running Queries
SELECT pid, usename, client_addr, state, query_start, query
FROM pg_stat_activity
WHERE datname = 'grp07_campussafedb';

-- 5. Database Statistics & Cache Hit Ratio
SELECT
    numbackends,
    xact_commit,
    xact_rollback,
    blks_read,
    blks_hit,
    round((blks_hit::numeric / (blks_hit + blks_read + 0.0001)) * 100, 2) AS buffer_cache_hit_pct
FROM pg_stat_database
WHERE datname = 'grp07_campussafedb';
```

---

## 3. Maintenance Procedures (`ANALYZE` & `VACUUM`)

> **PostgreSQL 14 Note:** `VACUUM` and `ANALYZE` require table ownership or superuser status. When testing peer projects, document whether the account has ownership or if an administrative maintenance role is required.

```sql
-- 1. Gather fresh query planner statistics
ANALYZE;

-- 2. Clean dead tuples and update statistics without locking tables
VACUUM (VERBOSE, ANALYZE) public.hazard_report;
VACUUM (VERBOSE, ANALYZE) public.report_status_history;
VACUUM (VERBOSE, ANALYZE) public.maintenance_action;
VACUUM (VERBOSE, ANALYZE) public.assignment;
```
*Never run `VACUUM FULL` in production unless resolving severe disk bloat during scheduled maintenance, as it places an exclusive table lock.*

---

## 4. Query Plan Analysis (`EXPLAIN ANALYZE`)

The following real CampusSafe queries should be inspected and documented in the Activity 5 Log.

### Query 1: Admin Filter by Status & Recency
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * 
FROM hazard_report 
WHERE status = 'Submitted' 
ORDER BY submitted_at DESC;
```
*Analysis Goal:* Verify whether the query planner uses index `idx_report_status` or a sequential scan. Note that on small tables (under a few hundred rows), the planner appropriately chooses a Sequential Scan because reading contiguous disk blocks in memory is faster than index pointer lookups.

### Query 2: Hazard Reports with Joined Categories and Locations
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT r.report_id, c.category_name, l.building, l.room_area, r.status, r.priority
FROM hazard_report r
JOIN hazard_category c ON c.category_id = r.category_id
JOIN campus_location l ON l.location_id = r.location_id
WHERE r.status = 'In Progress';
```
*Analysis Goal:* Observe Hash Joins vs. Nested Loops and examine buffer hits.
