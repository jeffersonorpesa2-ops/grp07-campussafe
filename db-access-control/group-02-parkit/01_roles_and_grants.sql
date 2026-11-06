-- ============================================================================
-- Group 7 Evaluation of Group 2 (Park-It Database Management System)
-- Activity 4: Roles, Privileges, and Role-Based Access Control Setup
-- Database: grp_parkitdb
-- Target RDBMS: PostgreSQL 18.6
-- ============================================================================

-- 1. Create Group Roles (NOLOGIN)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'parkit_runtime_grp') THEN
        CREATE ROLE parkit_runtime_grp NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'parkit_readonly_grp') THEN
        CREATE ROLE parkit_readonly_grp NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'parkit_backup_grp') THEN
        CREATE ROLE parkit_backup_grp NOLOGIN;
    END IF;
END $$;

-- 2. Create Login Roles (LOGIN)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'parkit_app') THEN
        CREATE ROLE parkit_app LOGIN PASSWORD 'AppRuntimePass2026!';
    ELSE
        ALTER ROLE parkit_app WITH LOGIN PASSWORD 'AppRuntimePass2026!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'parkit_report') THEN
        CREATE ROLE parkit_report LOGIN PASSWORD 'ReportPass2026!';
    ELSE
        ALTER ROLE parkit_report WITH LOGIN PASSWORD 'ReportPass2026!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'parkit_backup') THEN
        CREATE ROLE parkit_backup LOGIN PASSWORD 'BackupPass2026!';
    ELSE
        ALTER ROLE parkit_backup WITH LOGIN PASSWORD 'BackupPass2026!';
    END IF;
END $$;

-- 3. Assign Role Memberships
GRANT parkit_runtime_grp TO parkit_app;
GRANT parkit_readonly_grp TO parkit_report;
GRANT parkit_backup_grp TO parkit_backup;

-- 4. Harden Session Defaults
ALTER ROLE parkit_app IN DATABASE grp_parkitdb SET search_path = public;
ALTER ROLE parkit_app IN DATABASE grp_parkitdb SET statement_timeout = '30s';
ALTER ROLE parkit_app IN DATABASE grp_parkitdb SET lock_timeout = '10s';

-- 5. Lock down PUBLIC permissions
REVOKE ALL ON DATABASE grp_parkitdb FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- 6. Database Connection and Schema Usage
GRANT CONNECT ON DATABASE grp_parkitdb TO parkit_runtime_grp, parkit_readonly_grp, parkit_backup_grp;
GRANT USAGE ON SCHEMA public TO parkit_runtime_grp, parkit_readonly_grp, parkit_backup_grp;

-- 7. Reset Prior Grants on Tables and Sequences to ensure exact least privilege
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM parkit_runtime_grp, parkit_readonly_grp, parkit_backup_grp;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM parkit_runtime_grp, parkit_readonly_grp, parkit_backup_grp;

-- 8. Application Runtime Permissions (Least Privilege)
-- Parking zones and vehicles: full operational CRUD
GRANT SELECT, INSERT, UPDATE, DELETE ON public.parking_zone, public.vehicle TO parkit_runtime_grp;

-- Parking transactions: append, read, update exit time/status. Strictly NO DELETE!
GRANT SELECT, INSERT, UPDATE ON public.transaction TO parkit_runtime_grp;

-- Payments: append and read ONLY (immutable financial ledger). Strictly NO UPDATE or DELETE!
GRANT SELECT, INSERT ON public.payment TO parkit_runtime_grp;

-- Staff users: read-only for login authentication; NO insert/update/delete by application
GRANT SELECT ON public.staff_user TO parkit_runtime_grp;

-- Sequences for auto-increment PKs
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO parkit_runtime_grp;

-- 9. Read-Only / Auditor Role Permissions (Excluding staff_user to protect password hashes)
GRANT SELECT ON public.parking_zone, public.vehicle, public.transaction, public.payment TO parkit_readonly_grp;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO parkit_readonly_grp;

-- 10. Backup Operator Permissions
GRANT SELECT ON ALL TABLES IN SCHEMA public TO parkit_backup_grp;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO parkit_backup_grp;

-- 11. Default Privileges for Future Objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE ON TABLES TO parkit_runtime_grp;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO parkit_runtime_grp;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO parkit_readonly_grp;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO parkit_backup_grp;
