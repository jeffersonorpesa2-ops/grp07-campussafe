-- ============================================================================
-- Group 7 Evaluation of Group 4 (BrewPOS)
-- Activity 4: Roles, Privileges, and Role-Based Access Control Setup
-- Database: grp_brewposdb
-- Target RDBMS: PostgreSQL 18.6
-- ============================================================================

-- 1. Create Group Roles (NOLOGIN)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'brewpos_runtime_grp') THEN
        CREATE ROLE brewpos_runtime_grp NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'brewpos_readonly_grp') THEN
        CREATE ROLE brewpos_readonly_grp NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'brewpos_backup_grp') THEN
        CREATE ROLE brewpos_backup_grp NOLOGIN;
    END IF;
END $$;

-- 2. Create Login Roles (LOGIN)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'brewpos_app') THEN
        CREATE ROLE brewpos_app LOGIN PASSWORD 'AppRuntimePass2026!';
    ELSE
        ALTER ROLE brewpos_app WITH LOGIN PASSWORD 'AppRuntimePass2026!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'brewpos_auditor') THEN
        CREATE ROLE brewpos_auditor LOGIN PASSWORD 'AuditorPass2026!';
    ELSE
        ALTER ROLE brewpos_auditor WITH LOGIN PASSWORD 'AuditorPass2026!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'brewpos_backup') THEN
        CREATE ROLE brewpos_backup LOGIN PASSWORD 'BackupPass2026!';
    ELSE
        ALTER ROLE brewpos_backup WITH LOGIN PASSWORD 'BackupPass2026!';
    END IF;
END $$;

-- 3. Assign Role Memberships
GRANT brewpos_runtime_grp TO brewpos_app;
GRANT brewpos_readonly_grp TO brewpos_auditor;
GRANT brewpos_backup_grp TO brewpos_backup;

-- 4. Harden Session Defaults
ALTER ROLE brewpos_app IN DATABASE grp_brewposdb SET search_path = public;
ALTER ROLE brewpos_app IN DATABASE grp_brewposdb SET statement_timeout = '30s';
ALTER ROLE brewpos_app IN DATABASE grp_brewposdb SET lock_timeout = '10s';

-- 5. Lock down PUBLIC permissions
REVOKE ALL ON DATABASE grp_brewposdb FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- 6. Database Connection and Schema Usage
GRANT CONNECT ON DATABASE grp_brewposdb TO brewpos_runtime_grp, brewpos_readonly_grp, brewpos_backup_grp;
GRANT USAGE ON SCHEMA public TO brewpos_runtime_grp, brewpos_readonly_grp, brewpos_backup_grp;

-- 7. Reset Prior Grants on Tables and Sequences to ensure exact least privilege
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM brewpos_runtime_grp, brewpos_readonly_grp, brewpos_backup_grp;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM brewpos_runtime_grp, brewpos_readonly_grp, brewpos_backup_grp;

-- 8. Application Runtime Permissions (Least Privilege)
-- Staff: Read-only for the application; HR/DBA managed only
GRANT SELECT ON public.staff TO brewpos_runtime_grp;

-- Menu Category & Item: Operational catalog management (CRUD allowed)
GRANT SELECT, INSERT, UPDATE, DELETE ON public.menu_category, public.menu_item TO brewpos_runtime_grp;

-- Sales Transactions: Append & Read ONLY (No UPDATE, No DELETE to protect audit trail)
GRANT SELECT, INSERT ON public.order_ticket, public.order_line_item TO brewpos_runtime_grp;

-- Primary Key Sequences
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO brewpos_runtime_grp;

-- 9. Read-Only / Auditor Role Permissions
GRANT SELECT ON ALL TABLES IN SCHEMA public TO brewpos_readonly_grp;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO brewpos_readonly_grp;

-- 10. Backup Operator Permissions
GRANT SELECT ON ALL TABLES IN SCHEMA public TO brewpos_backup_grp;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO brewpos_backup_grp;

-- 11. Default Privileges for Future Objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT ON TABLES TO brewpos_runtime_grp;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO brewpos_runtime_grp;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO brewpos_readonly_grp;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO brewpos_backup_grp;
