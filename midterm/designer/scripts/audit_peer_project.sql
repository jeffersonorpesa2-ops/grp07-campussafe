-- =============================================================================
-- COMP 018: Database Administration - Midterm Examination
-- Group 7 - Rapid Peer Flaw-Finding & Audit Script
-- Purpose: Run against ANY assigned peer database to discover evidence-based flaws
--          across Schema, Access Control, Maintenance, and Recoverability.
-- Usage: psql -U postgres -d <peer_database_name> -f audit_peer_project.sql
-- =============================================================================

\echo '========================================================'
\echo 'AUDIT 1: BASIC SCHEMA INVENTORY & MISSING PRIMARY KEYS'
\echo '========================================================'
SELECT 
    t.table_name,
    CASE 
        WHEN pk.constraint_name IS NULL THEN 'FLAW: MISSING PRIMARY KEY'
        ELSE 'OK (PK: ' || pk.constraint_name || ')'
    END AS primary_key_status
FROM information_schema.tables t
LEFT JOIN (
    SELECT tc.table_name, tc.constraint_name
    FROM information_schema.table_constraints tc
    WHERE tc.constraint_type = 'PRIMARY KEY' AND tc.table_schema = 'public'
) pk ON t.table_name = pk.table_name
WHERE t.table_schema = 'public' AND t.table_type = 'BASE TABLE'
ORDER BY primary_key_status DESC, t.table_name;

\echo '========================================================'
\echo 'AUDIT 2: FOREIGN KEYS MISSING INDEXES (PERFORMANCE BOTTLENECK)'
\echo '========================================================'
-- Foreign key columns without supporting indexes cause table-wide sequential locks on DELETE/UPDATE
SELECT 
    c.conrelid::regclass AS table_name,
    c.conname AS fk_constraint,
    pg_get_constraintdef(c.oid) AS fk_definition
FROM pg_constraint c
WHERE c.contype = 'f' AND c.connamespace = 'public'::regnamespace
  AND NOT EXISTS (
      SELECT 1 FROM pg_index i
      WHERE i.indrelid = c.conrelid
        AND c.conkey[1] = ANY(i.indkey)
  )
ORDER BY table_name;

\echo '========================================================'
\echo 'AUDIT 3: SECURITY & PRIVILEGE AUDIT (LEAST PRIVILEGE FLAWS)'
\echo '========================================================'
-- Inspect non-superuser roles having blanket SUPERUSER or CREATEDB
SELECT 
    rolname, 
    rolsuper, 
    rolcreaterole, 
    rolcreatedb, 
    rolcanlogin
FROM pg_roles
WHERE rolname NOT LIKE 'pg_%' AND rolname != 'postgres'
ORDER BY rolsuper DESC, rolcanlogin DESC;

-- Inspect tables with direct PUBLIC grants
SELECT 
    table_name, 
    privilege_type
FROM information_schema.table_privileges
WHERE grantee = 'PUBLIC' AND table_schema = 'public'
ORDER BY table_name;

\echo '========================================================'
\echo 'AUDIT 4: CREDENTIAL EXPOSURE AUDIT'
\echo '========================================================'
-- Check if any user credential columns exist without security views masking them
SELECT 
    table_name, 
    column_name, 
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (column_name ILIKE '%pass%' OR column_name ILIKE '%secret%' OR column_name ILIKE '%token%')
ORDER BY table_name, column_name;

\echo '========================================================'
\echo 'AUDIT 5: TABLE BLOAT & STALE PLANNER STATISTICS'
\echo '========================================================'
SELECT 
    relname AS table_name,
    n_live_tup,
    n_dead_tup,
    last_analyze,
    last_vacuum,
    CASE 
        WHEN last_analyze IS NULL THEN 'FLAW: NEVER ANALYZED (STALE STATS)'
        WHEN n_dead_tup > 10 THEN 'WARNING: HIGH DEAD TUPLE BLOAT'
        ELSE 'HEALTHY'
    END AS maintenance_status
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC, n_live_tup DESC;

\echo '========================================================'
\echo 'AUDIT 6: SEQUENCE INTEGRITY & OVERFLOW CHECK'
\echo '========================================================'
SELECT 
    sequencename, 
    last_value, 
    start_value, 
    increment_by 
FROM pg_sequences 
ORDER BY sequencename;
