-- ============================================================================
-- Group 7 Evaluation of Group 8 (bwisIT Solutions - Campus Canteen Pre-Order)
-- Activity 4: Database Users, Roles, Privileges, and Access Control
-- Target Database: grp08_canteendb
-- Target RDBMS: PostgreSQL 18.6
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. CLEANUP PREVIOUS ROLES (IF APPLICABLE)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_database WHERE datname = 'grp08_canteendb') THEN
        REVOKE CONNECT ON DATABASE grp08_canteendb FROM PUBLIC;
    END IF;
END $$;

-- Drop login roles if they exist
DROP ROLE IF EXISTS canteen_app;
DROP ROLE IF EXISTS canteen_report;
DROP ROLE IF EXISTS canteen_backup;

-- Drop group roles if they exist
DROP ROLE IF EXISTS canteen_runtime_grp;
DROP ROLE IF EXISTS canteen_readonly_grp;
DROP ROLE IF EXISTS canteen_backup_grp;

-- ----------------------------------------------------------------------------
-- 2. CREATE GROUP ROLES (NOLOGIN)
-- ----------------------------------------------------------------------------
CREATE ROLE canteen_runtime_grp NOLOGIN;
CREATE ROLE canteen_readonly_grp NOLOGIN;
CREATE ROLE canteen_backup_grp NOLOGIN;

-- ----------------------------------------------------------------------------
-- 3. CREATE LOGIN ROLES (LOGIN)
-- ----------------------------------------------------------------------------
CREATE ROLE canteen_app WITH LOGIN PASSWORD 'CanteenRuntimePass2026!';
CREATE ROLE canteen_report WITH LOGIN PASSWORD 'CanteenReportPass2026!';
CREATE ROLE canteen_backup WITH LOGIN PASSWORD 'CanteenBackupPass2026!';

-- ----------------------------------------------------------------------------
-- 4. ASSIGN ROLE MEMBERSHIPS
-- ----------------------------------------------------------------------------
GRANT canteen_runtime_grp TO canteen_app;
GRANT canteen_readonly_grp TO canteen_report;
GRANT canteen_backup_grp TO canteen_backup;

-- ----------------------------------------------------------------------------
-- 5. HARDEN SESSION DEFAULTS & SECURITY TIMEOUTS
-- ----------------------------------------------------------------------------
ALTER ROLE canteen_app IN DATABASE grp08_canteendb SET search_path = public;
ALTER ROLE canteen_app IN DATABASE grp08_canteendb SET statement_timeout = '30s';
ALTER ROLE canteen_app IN DATABASE grp08_canteendb SET lock_timeout = '10s';

ALTER ROLE canteen_report IN DATABASE grp08_canteendb SET search_path = public;
ALTER ROLE canteen_report IN DATABASE grp08_canteendb SET statement_timeout = '15s';
ALTER ROLE canteen_report IN DATABASE grp08_canteendb SET lock_timeout = '5s';

ALTER ROLE canteen_backup IN DATABASE grp08_canteendb SET search_path = public;
ALTER ROLE canteen_backup IN DATABASE grp08_canteendb SET statement_timeout = '60s';

-- ----------------------------------------------------------------------------
-- 6. LOCK DOWN PUBLIC PRIVILEGES
-- ----------------------------------------------------------------------------
REVOKE ALL ON DATABASE grp08_canteendb FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- ----------------------------------------------------------------------------
-- 7. GRANT DATABASE CONNECTION & SCHEMA USAGE
-- ----------------------------------------------------------------------------
GRANT CONNECT ON DATABASE grp08_canteendb TO canteen_runtime_grp, canteen_readonly_grp, canteen_backup_grp, canteen_admin;
GRANT USAGE ON SCHEMA public TO canteen_runtime_grp, canteen_readonly_grp, canteen_backup_grp, canteen_admin;

-- ----------------------------------------------------------------------------
-- 8. RUNTIME APPLICATION PERMISSIONS (canteen_runtime_grp)
-- ----------------------------------------------------------------------------
-- Student management: SELECT, INSERT, UPDATE. DELETE is denied to preserve student identity links.
GRANT SELECT, INSERT, UPDATE ON student TO canteen_runtime_grp;

-- Vendor management: SELECT, INSERT, UPDATE (switch stalls on/off, profile updates). DELETE denied.
GRANT SELECT, INSERT, UPDATE ON vendor TO canteen_runtime_grp;

-- Menu item management: Vendors can add, edit, toggle availability, and delete unused items.
GRANT SELECT, INSERT, UPDATE, DELETE ON menu_item TO canteen_runtime_grp;

-- Customer Order: Orders can be placed and status advanced (pending -> preparing -> ready -> completed / cancelled).
-- DELETE is strictly denied to preserve revenue and order transaction audit trails.
GRANT SELECT, INSERT, UPDATE ON customer_order TO canteen_runtime_grp;

-- Order Item: Line items are immutable once submitted. SELECT, INSERT only. UPDATE and DELETE strictly denied.
GRANT SELECT, INSERT ON order_item TO canteen_runtime_grp;

-- Queue Entry: Queue numbers are created and updated (waiting -> called -> served). DELETE denied.
GRANT SELECT, INSERT, UPDATE ON queue_entry TO canteen_runtime_grp;

-- Notifications: Can be created, viewed, marked read, and cleared.
GRANT SELECT, INSERT, UPDATE, DELETE ON notification TO canteen_runtime_grp;

-- Sequences for autoincrementing IDs
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO canteen_runtime_grp;

-- ----------------------------------------------------------------------------
-- 9. READ-ONLY / AUDITOR ROLE PERMISSIONS (canteen_readonly_grp)
-- ----------------------------------------------------------------------------
GRANT SELECT ON ALL TABLES IN SCHEMA public TO canteen_readonly_grp;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO canteen_readonly_grp;

-- ----------------------------------------------------------------------------
-- 10. BACKUP OPERATOR ROLE PERMISSIONS (canteen_backup_grp)
-- ----------------------------------------------------------------------------
GRANT SELECT ON ALL TABLES IN SCHEMA public TO canteen_backup_grp;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO canteen_backup_grp;
GRANT pg_read_all_data TO canteen_backup_grp;
