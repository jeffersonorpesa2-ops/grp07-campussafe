-- ============================================================================
-- Group 7 Evaluation of Group 5 (PUP-SPOT — Campus Lost and Found)
-- Activity 4: Database Users, Roles, Privileges, and Access Control
-- Target Database: grp05_lostandfounddb
-- Target RDBMS: PostgreSQL 18.6
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. CLEANUP PREVIOUS ROLES (IF APPLICABLE)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    -- Revoke database connects
    IF EXISTS (SELECT 1 FROM pg_database WHERE datname = 'grp05_lostandfounddb') THEN
        REVOKE CONNECT ON DATABASE grp05_lostandfounddb FROM PUBLIC;
    END IF;
END $$;

-- Drop login roles if they exist
DROP ROLE IF EXISTS lostandfound_app;
DROP ROLE IF EXISTS lostandfound_public;
DROP ROLE IF EXISTS lostandfound_backup;

-- Drop group roles if they exist
DROP ROLE IF EXISTS lostandfound_admin_grp;
DROP ROLE IF EXISTS lostandfound_public_grp;
DROP ROLE IF EXISTS lostandfound_backup_grp;

-- ----------------------------------------------------------------------------
-- 2. CREATE GROUP ROLES (NOLOGIN)
-- ----------------------------------------------------------------------------
CREATE ROLE lostandfound_admin_grp NOLOGIN;
CREATE ROLE lostandfound_public_grp NOLOGIN;
CREATE ROLE lostandfound_backup_grp NOLOGIN;

-- ----------------------------------------------------------------------------
-- 3. CREATE LOGIN ROLES (LOGIN)
-- ----------------------------------------------------------------------------
CREATE ROLE lostandfound_app WITH LOGIN PASSWORD 'AdminAppPass2026!';
CREATE ROLE lostandfound_public WITH LOGIN PASSWORD 'PublicUserPass2026!';
CREATE ROLE lostandfound_backup WITH LOGIN PASSWORD 'BackupPass2026!';

-- ----------------------------------------------------------------------------
-- 4. ASSIGN ROLE MEMBERSHIPS
-- ----------------------------------------------------------------------------
GRANT lostandfound_admin_grp TO lostandfound_app;
GRANT lostandfound_public_grp TO lostandfound_public;
GRANT lostandfound_backup_grp TO lostandfound_backup;

-- ----------------------------------------------------------------------------
-- 5. HARDEN SESSION DEFAULTS & SECURITY TIMEOUTS
-- ----------------------------------------------------------------------------
ALTER ROLE lostandfound_app IN DATABASE grp05_lostandfounddb SET search_path = public;
ALTER ROLE lostandfound_app IN DATABASE grp05_lostandfounddb SET statement_timeout = '30s';
ALTER ROLE lostandfound_app IN DATABASE grp05_lostandfounddb SET lock_timeout = '10s';

ALTER ROLE lostandfound_public IN DATABASE grp05_lostandfounddb SET search_path = public;
ALTER ROLE lostandfound_public IN DATABASE grp05_lostandfounddb SET statement_timeout = '15s';
ALTER ROLE lostandfound_public IN DATABASE grp05_lostandfounddb SET lock_timeout = '5s';

ALTER ROLE lostandfound_backup IN DATABASE grp05_lostandfounddb SET search_path = public;
ALTER ROLE lostandfound_backup IN DATABASE grp05_lostandfounddb SET statement_timeout = '60s';

-- ----------------------------------------------------------------------------
-- 6. LOCK DOWN PUBLIC PRIVILEGES
-- ----------------------------------------------------------------------------
REVOKE ALL ON DATABASE grp05_lostandfounddb FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- ----------------------------------------------------------------------------
-- 7. GRANT DATABASE CONNECTION & SCHEMA USAGE
-- ----------------------------------------------------------------------------
GRANT CONNECT ON DATABASE grp05_lostandfounddb TO lostandfound_admin_grp, lostandfound_public_grp, lostandfound_backup_grp;
GRANT USAGE ON SCHEMA public TO lostandfound_admin_grp, lostandfound_public_grp, lostandfound_backup_grp;

-- ----------------------------------------------------------------------------
-- 8. PUBLIC ROLE PERMISSIONS (lostandfound_public_grp)
-- ----------------------------------------------------------------------------
-- Can browse categories, found items, reports, claims status, matches, and public images
GRANT SELECT ON TABLE
    public.categories,
    public.items,
    public.lost_reports,
    public.claims,
    public.potential_matches,
    public.item_images,
    public.lost_report_images
TO lostandfound_public_grp;

-- Can insert lost reports, claim requests, potential matches, and verification images
GRANT INSERT ON TABLE
    public.lost_reports,
    public.claims,
    public.potential_matches,
    public.lost_report_images,
    public.claim_images
TO lostandfound_public_grp;

-- Can update ONLY report status (to cancel own report)
GRANT UPDATE (status) ON TABLE public.lost_reports TO lostandfound_public_grp;

-- Can delete potential matches during match re-evaluation
GRANT DELETE ON TABLE public.potential_matches TO lostandfound_public_grp;

-- Sequences for public submissions
GRANT USAGE, SELECT ON SEQUENCE
    public.lost_reports_report_id_seq,
    public.claims_claim_id_seq,
    public.potential_matches_match_id_seq,
    public.lost_report_images_report_image_id_seq,
    public.claim_images_claim_image_id_seq
TO lostandfound_public_grp;

-- ----------------------------------------------------------------------------
-- 9. ADMIN / CAMPUS MARSHAL ROLE PERMISSIONS (lostandfound_admin_grp)
-- ----------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO lostandfound_admin_grp;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO lostandfound_admin_grp;

-- Administrative record purging on matches and images
GRANT DELETE ON TABLE
    public.potential_matches,
    public.item_images,
    public.lost_report_images,
    public.claim_images
TO lostandfound_admin_grp;

-- ----------------------------------------------------------------------------
-- 10. BACKUP OPERATOR ROLE PERMISSIONS (lostandfound_backup_grp)
-- ----------------------------------------------------------------------------
GRANT SELECT ON ALL TABLES IN SCHEMA public TO lostandfound_backup_grp;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO lostandfound_backup_grp;
