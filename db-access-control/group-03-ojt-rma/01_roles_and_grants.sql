-- ============================================================================
-- Group 7 Evaluation of Project-OJT-RMA-System
-- Activity 4: Roles, Privileges, and Role-Based Access Control Setup
-- Database: ojt_managementdb
-- Target RDBMS: PostgreSQL 18.6
-- ============================================================================

-- 1. Create Group Roles (NOLOGIN)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ojt_runtime_grp') THEN
        CREATE ROLE ojt_runtime_grp NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ojt_readonly_grp') THEN
        CREATE ROLE ojt_readonly_grp NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ojt_backup_grp') THEN
        CREATE ROLE ojt_backup_grp NOLOGIN;
    END IF;
END $$;

-- 2. Create Login Roles (LOGIN)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ojt_app') THEN
        CREATE ROLE ojt_app LOGIN PASSWORD 'AppRuntimePass2026!';
    ELSE
        ALTER ROLE ojt_app WITH LOGIN PASSWORD 'AppRuntimePass2026!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ojt_report') THEN
        CREATE ROLE ojt_report LOGIN PASSWORD 'ReportPass2026!';
    ELSE
        ALTER ROLE ojt_report WITH LOGIN PASSWORD 'ReportPass2026!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ojt_backup') THEN
        CREATE ROLE ojt_backup LOGIN PASSWORD 'BackupPass2026!';
    ELSE
        ALTER ROLE ojt_backup WITH LOGIN PASSWORD 'BackupPass2026!';
    END IF;
END $$;

-- 3. Assign Role Memberships
GRANT ojt_runtime_grp TO ojt_app;
GRANT ojt_readonly_grp TO ojt_report;
GRANT ojt_backup_grp TO ojt_backup;

-- 4. Harden Session Defaults
ALTER ROLE ojt_app IN DATABASE ojt_managementdb SET search_path = public, lending;
ALTER ROLE ojt_app IN DATABASE ojt_managementdb SET statement_timeout = '30s';
ALTER ROLE ojt_app IN DATABASE ojt_managementdb SET lock_timeout = '10s';

-- 5. Lock down PUBLIC permissions
REVOKE ALL ON DATABASE ojt_managementdb FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- 6. Database Connection and Schema Usage
GRANT CONNECT ON DATABASE ojt_managementdb TO ojt_runtime_grp, ojt_readonly_grp, ojt_backup_grp;
GRANT USAGE ON SCHEMA public, lending TO ojt_runtime_grp, ojt_readonly_grp, ojt_backup_grp;

-- 7. Reset Prior Grants on Tables and Sequences to ensure exact least privilege
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public, lending FROM ojt_runtime_grp, ojt_readonly_grp, ojt_backup_grp;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public, lending FROM ojt_runtime_grp, ojt_readonly_grp, ojt_backup_grp;

-- 8. Application Runtime Permissions (Least Privilege)
-- Operational tables: SELECT, INSERT, UPDATE
GRANT SELECT, INSERT, UPDATE ON public.users, public.companies, public.students,
                                public.academic_supervisors, public.company_supervisors,
                                public.requirements, public.student_requirements,
                                public.ojt_applications, public.ojt_placements
    TO ojt_runtime_grp;

-- Delete allowed ONLY on unreferenced/draft applications and student requirements
GRANT DELETE ON public.ojt_applications, public.student_requirements TO ojt_runtime_grp;

-- Attendance & Evaluations: Append and read only (No DELETE to preserve legal training records)
GRANT SELECT, INSERT, UPDATE ON public.attendance TO ojt_runtime_grp;
GRANT SELECT, INSERT ON public.evaluations TO ojt_runtime_grp;

-- Audit log: Append and read ONLY (Immutable audit ledger)
GRANT SELECT, INSERT ON public.audit_log TO ojt_runtime_grp;

-- Lending schema (from uploaded dump): Full operational access
GRANT SELECT, INSERT, UPDATE ON lending.customers, lending.loans TO ojt_runtime_grp;

-- Sequences for auto-increment PKs
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public, lending TO ojt_runtime_grp;

-- 9. Read-Only / Auditor Role Permissions (Excluding users to protect password hashes)
GRANT SELECT ON public.companies, public.students, public.academic_supervisors,
                public.company_supervisors, public.requirements, public.student_requirements,
                public.ojt_applications, public.ojt_placements, public.attendance,
                public.evaluations, public.audit_log, lending.customers, lending.loans
    TO ojt_readonly_grp;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public, lending TO ojt_readonly_grp;

-- 10. Backup Operator Permissions
GRANT SELECT ON ALL TABLES IN SCHEMA public, lending TO ojt_backup_grp;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public, lending TO ojt_backup_grp;

-- 11. Default Privileges for Future Objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE ON TABLES TO ojt_runtime_grp;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO ojt_runtime_grp;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO ojt_readonly_grp;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO ojt_backup_grp;
