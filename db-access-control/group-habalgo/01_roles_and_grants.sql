-- ============================================================================
-- Group 7 Evaluation of Group HabalGo (HabalGo - Ride and Booking System)
-- Activity 4: Database Users, Roles, Privileges, and Access Control
-- Target Database: grp00_habalgodb
-- Target RDBMS: PostgreSQL 18.6
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. CLEANUP PREVIOUS ROLES (IF APPLICABLE)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_database WHERE datname = 'grp00_habalgodb') THEN
        REVOKE CONNECT ON DATABASE grp00_habalgodb FROM PUBLIC;
    END IF;
END $$;

-- Drop login roles if they exist
DROP ROLE IF EXISTS habalgo_app;
DROP ROLE IF EXISTS habalgo_report;
DROP ROLE IF EXISTS habalgo_backup;

-- Drop group roles if they exist
DROP ROLE IF EXISTS habalgo_runtime_grp;
DROP ROLE IF EXISTS habalgo_readonly_grp;
DROP ROLE IF EXISTS habalgo_backup_grp;

-- ----------------------------------------------------------------------------
-- 2. CREATE GROUP ROLES (NOLOGIN)
-- ----------------------------------------------------------------------------
CREATE ROLE habalgo_runtime_grp NOLOGIN;
CREATE ROLE habalgo_readonly_grp NOLOGIN;
CREATE ROLE habalgo_backup_grp NOLOGIN;

-- ----------------------------------------------------------------------------
-- 3. CREATE LOGIN ROLES (LOGIN)
-- ----------------------------------------------------------------------------
CREATE ROLE habalgo_app WITH LOGIN PASSWORD 'HabalGoRuntimePass2026!';
CREATE ROLE habalgo_report WITH LOGIN PASSWORD 'HabalGoReportPass2026!';
CREATE ROLE habalgo_backup WITH LOGIN PASSWORD 'HabalGoBackupPass2026!';

-- ----------------------------------------------------------------------------
-- 4. ASSIGN ROLE MEMBERSHIPS
-- ----------------------------------------------------------------------------
GRANT habalgo_runtime_grp TO habalgo_app;
GRANT habalgo_readonly_grp TO habalgo_report;
GRANT habalgo_backup_grp TO habalgo_backup;

-- ----------------------------------------------------------------------------
-- 5. HARDEN SESSION DEFAULTS & SECURITY TIMEOUTS
-- ----------------------------------------------------------------------------
ALTER ROLE habalgo_app IN DATABASE grp00_habalgodb SET search_path = habalgo, public;
ALTER ROLE habalgo_app IN DATABASE grp00_habalgodb SET statement_timeout = '30s';
ALTER ROLE habalgo_app IN DATABASE grp00_habalgodb SET lock_timeout = '10s';

ALTER ROLE habalgo_report IN DATABASE grp00_habalgodb SET search_path = habalgo, public;
ALTER ROLE habalgo_report IN DATABASE grp00_habalgodb SET statement_timeout = '15s';
ALTER ROLE habalgo_report IN DATABASE grp00_habalgodb SET lock_timeout = '5s';

ALTER ROLE habalgo_backup IN DATABASE grp00_habalgodb SET search_path = habalgo, public;
ALTER ROLE habalgo_backup IN DATABASE grp00_habalgodb SET statement_timeout = '60s';

-- ----------------------------------------------------------------------------
-- 6. LOCK DOWN PUBLIC PRIVILEGES
-- ----------------------------------------------------------------------------
REVOKE ALL ON DATABASE grp00_habalgodb FROM PUBLIC;
REVOKE CREATE ON SCHEMA habalgo FROM PUBLIC;

-- ----------------------------------------------------------------------------
-- 7. GRANT DATABASE CONNECTION & SCHEMA USAGE
-- ----------------------------------------------------------------------------
GRANT CONNECT ON DATABASE grp00_habalgodb TO habalgo_runtime_grp, habalgo_readonly_grp, habalgo_backup_grp;
GRANT USAGE ON SCHEMA habalgo TO habalgo_runtime_grp, habalgo_readonly_grp, habalgo_backup_grp;

-- ----------------------------------------------------------------------------
-- 8. RUNTIME APPLICATION PERMISSIONS (habalgo_runtime_grp)
-- ----------------------------------------------------------------------------
-- Full CRUD on mutable customer, location, and rating records
GRANT SELECT, INSERT, UPDATE, DELETE ON 
    habalgo.customer,
    habalgo.location,
    habalgo.rating_feedback
TO habalgo_runtime_grp;

-- Booking: SELECT, INSERT, UPDATE (status transitions). DELETE is strictly denied.
GRANT SELECT, INSERT, UPDATE ON habalgo.booking TO habalgo_runtime_grp;

-- Payment: Append-only financial ledger. SELECT, INSERT only. UPDATE and DELETE strictly denied.
GRANT SELECT, INSERT ON habalgo.payment TO habalgo_runtime_grp;

-- Fleet: SELECT, INSERT, UPDATE on driver, vehicle, driver_vehicle. DELETE denied.
GRANT SELECT, INSERT, UPDATE ON 
    habalgo.driver,
    habalgo.vehicle,
    habalgo.driver_vehicle
TO habalgo_runtime_grp;

-- Sequences for autoincrementing IDs
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA habalgo TO habalgo_runtime_grp;

-- ----------------------------------------------------------------------------
-- 9. READ-ONLY / AUDITOR ROLE PERMISSIONS (habalgo_readonly_grp)
-- ----------------------------------------------------------------------------
GRANT SELECT ON ALL TABLES IN SCHEMA habalgo TO habalgo_readonly_grp;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA habalgo TO habalgo_readonly_grp;

-- ----------------------------------------------------------------------------
-- 10. BACKUP OPERATOR ROLE PERMISSIONS (habalgo_backup_grp)
-- ----------------------------------------------------------------------------
GRANT SELECT ON ALL TABLES IN SCHEMA habalgo TO habalgo_backup_grp;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA habalgo TO habalgo_backup_grp;
