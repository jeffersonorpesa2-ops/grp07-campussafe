-- =============================================================================
-- Database Administration (COMP 018) — Activity 6: Verification Suite
-- Target Project: Group 11 — BoardTrack (Boarding House & Rental Management System)
-- Evaluating Group: Group 7 (Alba, Arreza, Orpesa, Robiso, Santos)
-- Database Engine: PostgreSQL 18.6 on x86_64 Windows
-- Target Database: grp11_boardtrackdb
-- Restored Test Database: grp11_boardtrackdb_restore_test
-- File: verification_suite.sql
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Table Existence and Object Count Verification
-- -----------------------------------------------------------------------------
SELECT 
    table_schema,
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_type, table_name;

-- -----------------------------------------------------------------------------
-- 2. Comprehensive Row Count Parity Verification
-- -----------------------------------------------------------------------------
-- Execute against primary (grp11_boardtrackdb) and restored (grp11_boardtrackdb_restore_test)
SELECT 'property' AS entity, count(*) AS total_rows FROM property
UNION ALL
SELECT 'room', count(*) FROM room
UNION ALL
SELECT 'tenant', count(*) FROM tenant
UNION ALL
SELECT 'lease', count(*) FROM lease
UNION ALL
SELECT 'payment', count(*) FROM payment
UNION ALL
SELECT 'utility_bill', count(*) FROM utility_bill
UNION ALL
SELECT 'app_user', count(*) FROM app_user
UNION ALL
SELECT 'schema_migrations', count(*) FROM schema_migrations
ORDER BY entity;

-- -----------------------------------------------------------------------------
-- 3. Sequence State and Last Value Parity Check
-- -----------------------------------------------------------------------------
SELECT 
    sequencename, 
    last_value,
    start_value,
    increment_by
FROM pg_sequences
ORDER BY sequencename;

-- -----------------------------------------------------------------------------
-- 4. Constraint and Index Integrity Check
-- -----------------------------------------------------------------------------
SELECT 
    conrelid::regclass AS table_name,
    conname AS constraint_name,
    contype AS constraint_type
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace
ORDER BY table_name, constraint_name;

SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- -----------------------------------------------------------------------------
-- 5. Canary Disaster Recovery Simulation Script
-- -----------------------------------------------------------------------------

-- Step A: Insert timestamped canary record into primary database
INSERT INTO property (property_name, address)
VALUES ('Canary Boarding House - Disaster Simulation Baseline', 'Unit 777 Emergency Lane, Calamba, Laguna')
RETURNING property_id, property_name, address;

-- Step B: Disaster event simulation (accidental loss)
DELETE FROM property 
WHERE property_name = 'Canary Boarding House - Disaster Simulation Baseline';

-- Step C: Confirm loss
SELECT count(*) AS canary_loss_verified
FROM property 
WHERE property_name = 'Canary Boarding House - Disaster Simulation Baseline';

-- Step D: Targeted restoration verification
-- (Restore snapshot to staging and retrieve lost canary record)
-- INSERT INTO property (property_id, property_name, address)
-- VALUES (8, 'Canary Boarding House - Disaster Simulation Baseline', 'Unit 777 Emergency Lane, Calamba, Laguna')
-- ON CONFLICT (property_id) DO NOTHING;

-- Step E: Cleanup post-drill
-- DELETE FROM property WHERE property_name = 'Canary Boarding House - Disaster Simulation Baseline';
