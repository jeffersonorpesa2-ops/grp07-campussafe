-- =============================================================================
-- CampusSafe: Campus Hazard & Safety Reporting System
-- Activity 4: Roles, Users, and Privileges Specification (03_roles_and_privileges.sql)
--
-- Execute as PostgreSQL Superuser or Database Owner (campussafe_owner)
-- Run while connected to grp07_campussafedb
-- =============================================================================

-- Clean re-run helper: Revoke privileges before recreating roles
DO $$
BEGIN
    -- 1. Create Group Roles (NOLOGIN)
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_runtime_grp') THEN
        CREATE ROLE app_runtime_grp NOLOGIN;
    END IF;

    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_readonly_grp') THEN
        CREATE ROLE app_readonly_grp NOLOGIN;
    END IF;

    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_backup_grp') THEN
        CREATE ROLE app_backup_grp NOLOGIN;
    END IF;

    -- 2. Create Login Roles with temporary local passwords
    -- IMPORTANT: Change placeholder passwords in production / local evaluation
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'campussafe_app') THEN
        CREATE ROLE campussafe_app LOGIN PASSWORD 'change_me_locally';
    END IF;

    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'campussafe_report') THEN
        CREATE ROLE campussafe_report LOGIN PASSWORD 'change_me_locally';
    END IF;

    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'campussafe_backup') THEN
        CREATE ROLE campussafe_backup LOGIN PASSWORD 'change_me_locally';
    END IF;
END $$;

-- 3. Assign Role Memberships
GRANT app_runtime_grp  TO campussafe_app;
GRANT app_readonly_grp TO campussafe_report;
GRANT app_backup_grp   TO campussafe_backup;

-- 4. Lock down PUBLIC permissions
REVOKE ALL ON DATABASE grp07_campussafedb FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- 5. Database Connection and Schema Usage
GRANT CONNECT ON DATABASE grp07_campussafedb TO app_runtime_grp, app_readonly_grp, app_backup_grp;
GRANT USAGE ON SCHEMA public TO app_runtime_grp, app_readonly_grp, app_backup_grp;

-- 6. Application Runtime Permissions (Least-Privilege Principle)
-- Runtime requires SELECT, INSERT, UPDATE across operational tables
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO app_runtime_grp;

-- Narrow DELETE: Never allow deleting users or hazard reports directly (deactivation / audit preservation)
-- Only attachments and assignment records may be unlinked
GRANT DELETE ON attachment, assignment TO app_runtime_grp;

-- Sequences access (needed for auto-incrementing SERIAL keys)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_runtime_grp;

-- 7. Read-Only / Auditor Role Permissions
-- Auditor needs visibility into safety operations, but app_user (containing password_hash) is strictly excluded
GRANT SELECT ON hazard_report, hazard_category, campus_location,
                report_status_history, maintenance_action, assignment, attachment
    TO app_readonly_grp;

-- 8. Backup Operator Permissions (Activity 6 pg_dump)
-- Needs read access to all schema tables and sequences for complete logical backup
GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_backup_grp;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO app_backup_grp;

-- 9. Default Privileges for Future Tables & Sequences
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE ON TABLES TO app_runtime_grp;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO app_runtime_grp;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO app_backup_grp;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON SEQUENCES TO app_backup_grp;

-- Display configured roles and verification confirmation
SELECT rolname, rolcanlogin, rolsuper FROM pg_roles 
WHERE rolname IN ('app_runtime_grp', 'app_readonly_grp', 'app_backup_grp',
                  'campussafe_app', 'campussafe_report', 'campussafe_backup');
