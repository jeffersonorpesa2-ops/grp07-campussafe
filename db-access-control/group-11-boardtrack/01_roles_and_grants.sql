-- =============================================================================
-- Database Administration (COMP 018) — Activity 4: Access Control Implementation
-- Target Project: Group 11 — BoardTrack (Boarding House & Rental Management System)
-- Evaluating Group: Group 7 (Alba, Arreza, Orpesa, Robiso, Santos)
-- Database Engine: PostgreSQL 18.6 on x86_64 Windows
-- Target Database: grp11_boardtrackdb
-- File: 01_roles_and_grants.sql
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Step 1: Cluster-Wide Cleanup (Idempotent Drop if Exists)
-- -----------------------------------------------------------------------------
DROP ROLE IF EXISTS boardtrack_app;
DROP ROLE IF EXISTS boardtrack_report;
DROP ROLE IF EXISTS boardtrack_maint;
DROP ROLE IF EXISTS boardtrack_backup;
DROP ROLE IF EXISTS boardtrack_dba;

DROP ROLE IF EXISTS boardtrack_runtime_grp;
DROP ROLE IF EXISTS boardtrack_readonly_grp;
DROP ROLE IF EXISTS boardtrack_maint_grp;
DROP ROLE IF EXISTS boardtrack_backup_grp;
DROP ROLE IF EXISTS boardtrack_admin_grp;

-- -----------------------------------------------------------------------------
-- Step 2: Database and Schema Public Isolation
-- -----------------------------------------------------------------------------
REVOKE ALL ON DATABASE grp11_boardtrackdb FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM PUBLIC;

-- -----------------------------------------------------------------------------
-- Step 3: Create NOLOGIN Group Roles (Role-Based Access Control)
-- -----------------------------------------------------------------------------
CREATE ROLE boardtrack_runtime_grp NOLOGIN;
CREATE ROLE boardtrack_readonly_grp NOLOGIN;
CREATE ROLE boardtrack_maint_grp NOLOGIN;
CREATE ROLE boardtrack_backup_grp NOLOGIN;
CREATE ROLE boardtrack_admin_grp NOLOGIN;

-- -----------------------------------------------------------------------------
-- Step 4: Create Authenticated LOGIN Accounts with Hardened Configurations
-- -----------------------------------------------------------------------------
CREATE ROLE boardtrack_app WITH
    LOGIN
    PASSWORD 'BoardTrack_App#2026!'
    CONNECTION LIMIT 25;

CREATE ROLE boardtrack_report WITH
    LOGIN
    PASSWORD 'BoardTrack_Report#2026!'
    CONNECTION LIMIT 5;

CREATE ROLE boardtrack_maint WITH
    LOGIN
    PASSWORD 'BoardTrack_Maint#2026!'
    CONNECTION LIMIT 3;

CREATE ROLE boardtrack_backup WITH
    LOGIN
    PASSWORD 'BoardTrack_Backup#2026!'
    CONNECTION LIMIT 3;

CREATE ROLE boardtrack_dba WITH
    LOGIN
    PASSWORD 'BoardTrack_Dba#2026!'
    CONNECTION LIMIT 5;

-- Assign login roles to their parent group roles
GRANT boardtrack_runtime_grp TO boardtrack_app;
GRANT boardtrack_readonly_grp TO boardtrack_report;
GRANT boardtrack_maint_grp TO boardtrack_maint;
GRANT boardtrack_backup_grp TO boardtrack_backup;
GRANT boardtrack_admin_grp TO boardtrack_dba;

-- Set session-level statement timeouts and parameters
ALTER ROLE boardtrack_app SET statement_timeout = '15s';
ALTER ROLE boardtrack_report SET statement_timeout = '30s';
ALTER ROLE boardtrack_maint SET statement_timeout = '60s';

-- -----------------------------------------------------------------------------
-- Step 5: Database Connection & Schema Usage Grants
-- -----------------------------------------------------------------------------
GRANT CONNECT ON DATABASE grp11_boardtrackdb TO
    boardtrack_runtime_grp,
    boardtrack_readonly_grp,
    boardtrack_maint_grp,
    boardtrack_backup_grp,
    boardtrack_admin_grp;

GRANT USAGE ON SCHEMA public TO
    boardtrack_runtime_grp,
    boardtrack_readonly_grp,
    boardtrack_maint_grp,
    boardtrack_backup_grp,
    boardtrack_admin_grp;

-- DBA gets schema creation rights
GRANT CREATE ON SCHEMA public TO boardtrack_admin_grp;

-- -----------------------------------------------------------------------------
-- Step 6: Security View Creation (Sanitized User Directory)
-- -----------------------------------------------------------------------------
-- Shields bcrypt password hashes from read-only / auditor visibility
CREATE OR REPLACE VIEW v_user_directory AS
SELECT user_id, username, role, tenant_id, is_active
FROM app_user;

-- -----------------------------------------------------------------------------
-- Step 7: Granular Privilege Allocations (Least-Privilege Principle)
-- -----------------------------------------------------------------------------

-- [A] Runtime Group (`boardtrack_runtime_grp` / `boardtrack_app`)
-- Master and entity data: SELECT, INSERT, UPDATE
GRANT SELECT, INSERT, UPDATE ON property TO boardtrack_runtime_grp;
GRANT SELECT, INSERT, UPDATE ON room TO boardtrack_runtime_grp;
GRANT SELECT, INSERT, UPDATE ON tenant TO boardtrack_runtime_grp;
GRANT SELECT, INSERT, UPDATE ON app_user TO boardtrack_runtime_grp;

-- Financial Ledger & Lease Contracts: SELECT, INSERT, UPDATE ONLY (NO DELETE)
GRANT SELECT, INSERT, UPDATE ON lease TO boardtrack_runtime_grp;
GRANT SELECT, INSERT, UPDATE ON payment TO boardtrack_runtime_grp;
GRANT SELECT, INSERT, UPDATE ON utility_bill TO boardtrack_runtime_grp;

-- Views and system migrations
GRANT SELECT ON v_lease_summary TO boardtrack_runtime_grp;
GRANT SELECT ON v_user_directory TO boardtrack_runtime_grp;
GRANT SELECT ON schema_migrations TO boardtrack_runtime_grp;

-- Sequence usage for auto-increment PKs
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO boardtrack_runtime_grp;

-- [B] Read-Only Group (`boardtrack_readonly_grp` / `boardtrack_report`)
-- Operational and financial reporting: SELECT only
GRANT SELECT ON property TO boardtrack_readonly_grp;
GRANT SELECT ON room TO boardtrack_readonly_grp;
GRANT SELECT ON tenant TO boardtrack_readonly_grp;
GRANT SELECT ON lease TO boardtrack_readonly_grp;
GRANT SELECT ON payment TO boardtrack_readonly_grp;
GRANT SELECT ON utility_bill TO boardtrack_readonly_grp;
GRANT SELECT ON v_lease_summary TO boardtrack_readonly_grp;
GRANT SELECT ON schema_migrations TO boardtrack_readonly_grp;

-- Access sanitized user directory; DIRECT app_user SELECT IS WITHHELD
GRANT SELECT ON v_user_directory TO boardtrack_readonly_grp;

-- [C] Maintenance Group (`boardtrack_maint_grp` / `boardtrack_maint`)
-- Built-in maintenance and monitoring capabilities; ZERO direct table data access
GRANT pg_maintain TO boardtrack_maint_grp;
GRANT pg_monitor TO boardtrack_maint_grp;

-- [D] Backup Group (`boardtrack_backup_grp` / `boardtrack_backup`)
-- Non-destructive logical dump privilege across cluster data
GRANT pg_read_all_data TO boardtrack_backup_grp;

-- [E] Admin Group (`boardtrack_admin_grp` / `boardtrack_dba`)
-- Administrative management over all schema objects
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO boardtrack_admin_grp;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO boardtrack_admin_grp;
GRANT ALL PRIVILEGES ON ALL ROUTINES IN SCHEMA public TO boardtrack_admin_grp;
GRANT pg_monitor TO boardtrack_admin_grp;

-- Default privileges for future tables created in public schema
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE ON TABLES TO boardtrack_runtime_grp;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO boardtrack_readonly_grp;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO boardtrack_admin_grp;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO boardtrack_runtime_grp;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO boardtrack_admin_grp;
