-- ============================================================================
-- Group 7 Evaluation of Group 10 (Binary Sisters - Restaurant Ordering & Reservation)
-- Activity 4: Database Users, Roles, Privileges, and Access Control
-- Target Database: grp_binarysisters_projectdb
-- Target RDBMS: PostgreSQL 18.6
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. CLEANUP PREVIOUS ROLES (IF APPLICABLE)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_database WHERE datname = 'grp_binarysisters_projectdb') THEN
        REVOKE CONNECT ON DATABASE grp_binarysisters_projectdb FROM PUBLIC;
    END IF;
END $$;

-- Drop login roles if they exist
DROP ROLE IF EXISTS rors_app;
DROP ROLE IF EXISTS rors_report;
DROP ROLE IF EXISTS rors_maint;
DROP ROLE IF EXISTS rors_backup;
DROP ROLE IF EXISTS rors_dba;

-- Drop group roles if they exist
DROP ROLE IF EXISTS rors_runtime_grp;
DROP ROLE IF EXISTS rors_readonly_grp;
DROP ROLE IF EXISTS rors_maint_grp;
DROP ROLE IF EXISTS rors_backup_grp;
DROP ROLE IF EXISTS rors_admin_grp;

-- ----------------------------------------------------------------------------
-- 2. CREATE GROUP ROLES (NOLOGIN)
-- ----------------------------------------------------------------------------
CREATE ROLE rors_runtime_grp NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
CREATE ROLE rors_readonly_grp NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
CREATE ROLE rors_maint_grp NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
CREATE ROLE rors_backup_grp NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
CREATE ROLE rors_admin_grp NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;

-- ----------------------------------------------------------------------------
-- 3. CREATE LOGIN ROLES (LOGIN)
-- ----------------------------------------------------------------------------
CREATE ROLE rors_app WITH LOGIN PASSWORD 'RorsRuntimePass2026!' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION CONNECTION LIMIT 20;
CREATE ROLE rors_report WITH LOGIN PASSWORD 'RorsReportPass2026!' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION CONNECTION LIMIT 5;
CREATE ROLE rors_maint WITH LOGIN PASSWORD 'RorsMaintPass2026!' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION CONNECTION LIMIT 3;
CREATE ROLE rors_backup WITH LOGIN PASSWORD 'RorsBackupPass2026!' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION CONNECTION LIMIT 2;
CREATE ROLE rors_dba WITH LOGIN PASSWORD 'RorsDbaPass2026!' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION CONNECTION LIMIT 3;

-- ----------------------------------------------------------------------------
-- 4. ASSIGN ROLE MEMBERSHIPS & PREDEFINED SYSTEM ROLES
-- ----------------------------------------------------------------------------
GRANT rors_runtime_grp  TO rors_app;
GRANT rors_readonly_grp TO rors_report;
GRANT rors_maint_grp    TO rors_maint;
GRANT rors_backup_grp   TO rors_backup;
GRANT rors_admin_grp    TO rors_dba;

GRANT pg_monitor       TO rors_maint_grp, rors_admin_grp;
GRANT pg_read_all_data TO rors_backup_grp;
GRANT pg_maintain      TO rors_maint_grp;

-- ----------------------------------------------------------------------------
-- 5. HARDEN SESSION DEFAULTS & TIMEOUTS
-- ----------------------------------------------------------------------------
ALTER ROLE rors_app IN DATABASE grp_binarysisters_projectdb SET search_path = public;
ALTER ROLE rors_app IN DATABASE grp_binarysisters_projectdb SET statement_timeout = '30s';
ALTER ROLE rors_app IN DATABASE grp_binarysisters_projectdb SET lock_timeout = '10s';

ALTER ROLE rors_report IN DATABASE grp_binarysisters_projectdb SET search_path = public;
ALTER ROLE rors_report IN DATABASE grp_binarysisters_projectdb SET statement_timeout = '60s';
ALTER ROLE rors_report IN DATABASE grp_binarysisters_projectdb SET lock_timeout = '10s';

ALTER ROLE rors_maint IN DATABASE grp_binarysisters_projectdb SET search_path = public;
ALTER ROLE rors_backup IN DATABASE grp_binarysisters_projectdb SET search_path = public;
ALTER ROLE rors_backup IN DATABASE grp_binarysisters_projectdb SET statement_timeout = '60s';
ALTER ROLE rors_dba IN DATABASE grp_binarysisters_projectdb SET search_path = public;

-- ----------------------------------------------------------------------------
-- 6. LOCK DOWN PUBLIC PRIVILEGES
-- ----------------------------------------------------------------------------
REVOKE ALL ON DATABASE grp_binarysisters_projectdb FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;

-- ----------------------------------------------------------------------------
-- 7. GRANT DATABASE CONNECTION & SCHEMA USAGE
-- ----------------------------------------------------------------------------
GRANT CONNECT ON DATABASE grp_binarysisters_projectdb
    TO rors_runtime_grp, rors_readonly_grp, rors_maint_grp, rors_backup_grp, rors_admin_grp;

GRANT USAGE ON SCHEMA public
    TO rors_runtime_grp, rors_readonly_grp, rors_maint_grp, rors_backup_grp, rors_admin_grp;

GRANT CREATE ON SCHEMA public TO rors_admin_grp;

-- ----------------------------------------------------------------------------
-- 8. RUNTIME APPLICATION PERMISSIONS (rors_runtime_grp)
-- ----------------------------------------------------------------------------
-- Customer management: SELECT, INSERT, UPDATE. DELETE denied to protect customer identity links.
GRANT SELECT, INSERT, UPDATE ON customer TO rors_runtime_grp;

-- Orders and Payment: Lifecycle status updates allowed. DELETE strictly denied to preserve audit trail.
GRANT SELECT, INSERT, UPDATE ON orders, payment TO rors_runtime_grp;

-- Order Item: Line items are append-only. SELECT, INSERT only. UPDATE/DELETE strictly denied.
GRANT SELECT, INSERT ON order_item TO rors_runtime_grp;

-- Mutable catalog and operational resources: Full CRUD
GRANT SELECT, INSERT, UPDATE, DELETE ON menu_item, restaurant_table, reservation, staff TO rors_runtime_grp;

-- Sequences for autoincrementing IDs
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO rors_runtime_grp;

-- Operational views
GRANT SELECT ON v_order_summary, v_reservation_schedule TO rors_runtime_grp;

-- ----------------------------------------------------------------------------
-- 9. READ-ONLY / AUDITOR PERMISSIONS (rors_readonly_grp)
-- ----------------------------------------------------------------------------
-- Direct table access on operational data (customer and staff omitted to protect password hashes)
GRANT SELECT ON menu_item, restaurant_table, orders, order_item, reservation, payment TO rors_readonly_grp;

-- Sanitized directory views (password hashes masked/excluded)
GRANT SELECT ON v_customer_directory, v_staff_directory, v_order_summary, v_reservation_schedule TO rors_readonly_grp;

-- ----------------------------------------------------------------------------
-- 10. ADMINISTRATOR PERMISSIONS (rors_admin_grp)
-- ----------------------------------------------------------------------------
GRANT ALL ON ALL TABLES    IN SCHEMA public TO rors_admin_grp;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO rors_admin_grp;
