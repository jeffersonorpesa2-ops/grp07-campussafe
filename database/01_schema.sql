-- =============================================================================
-- CampusSafe: Campus Hazard & Safety Reporting System
-- Database Schema Definition (PostgreSQL 14+)
-- Database Name: grp07_campussafedb
-- =============================================================================

-- Drop tables if re-running (in reverse dependency order)
DROP TABLE IF EXISTS attachment CASCADE;
DROP TABLE IF EXISTS maintenance_action CASCADE;
DROP TABLE IF EXISTS report_status_history CASCADE;
DROP TABLE IF EXISTS assignment CASCADE;
DROP TABLE IF EXISTS hazard_report CASCADE;
DROP TABLE IF EXISTS campus_location CASCADE;
DROP TABLE IF EXISTS hazard_category CASCADE;
DROP TABLE IF EXISTS app_user CASCADE;
DROP TABLE IF EXISTS role CASCADE;

-- -----------------------------------------------------------------------------
-- 1. ROLE
-- System authorization roles
-- -----------------------------------------------------------------------------
CREATE TABLE role (
    role_id     SERIAL PRIMARY KEY,
    role_name   VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);

-- -----------------------------------------------------------------------------
-- 2. APP_USER
-- Campus community members, staff, maintenance technicians, and administrators
-- Named app_user to avoid conflict with PostgreSQL reserved word 'user'
-- -----------------------------------------------------------------------------
CREATE TABLE app_user (
    user_id        SERIAL PRIMARY KEY,
    role_id        INT NOT NULL REFERENCES role(role_id),
    full_name      VARCHAR(150) NOT NULL,
    email          VARCHAR(255) NOT NULL UNIQUE,
    username       VARCHAR(100) NOT NULL UNIQUE,
    password_hash  TEXT NOT NULL,
    account_status VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (account_status IN ('active', 'inactive', 'suspended')),
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 3. HAZARD_CATEGORY
-- Classification categories for physical safety hazards
-- -----------------------------------------------------------------------------
CREATE TABLE hazard_category (
    category_id   SERIAL PRIMARY KEY,
    category_name VARCHAR(80) NOT NULL UNIQUE,
    description   TEXT,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE
);

-- -----------------------------------------------------------------------------
-- 4. CAMPUS_LOCATION
-- Master table for physical campus locations (buildings, floors, rooms/areas)
-- -----------------------------------------------------------------------------
CREATE TABLE campus_location (
    location_id          SERIAL PRIMARY KEY,
    building             VARCHAR(120) NOT NULL,
    floor                VARCHAR(30),
    room_area            VARCHAR(120) NOT NULL,
    location_description TEXT,
    is_active            BOOLEAN NOT NULL DEFAULT TRUE
);

-- -----------------------------------------------------------------------------
-- 5. HAZARD_REPORT
-- Core incident reports filed by campus reporters
-- Priority is NULL until verified by an Administrator
-- Enforces verification pair consistency and resolved timestamp rule
-- -----------------------------------------------------------------------------
CREATE TABLE hazard_report (
    report_id           SERIAL PRIMARY KEY,
    reporter_user_id    INT NOT NULL REFERENCES app_user(user_id),
    location_id         INT NOT NULL REFERENCES campus_location(location_id),
    category_id         INT NOT NULL REFERENCES hazard_category(category_id),
    description         TEXT NOT NULL,
    priority            VARCHAR(20)
        CHECK (priority IN ('Low', 'Medium', 'High', 'Critical')),
    status              VARCHAR(30) NOT NULL DEFAULT 'Submitted'
        CHECK (status IN ('Submitted', 'Verified', 'Assigned', 'In Progress', 'Resolved', 'Closed')),
    submitted_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    verified_by_user_id INT REFERENCES app_user(user_id),
    verified_at         TIMESTAMP,
    resolved_at         TIMESTAMP,
    CONSTRAINT chk_verified_pair CHECK (
        (verified_by_user_id IS NULL AND verified_at IS NULL) OR
        (verified_by_user_id IS NOT NULL AND verified_at IS NOT NULL)
    ),
    CONSTRAINT chk_resolved_has_date CHECK (
        status NOT IN ('Resolved', 'Closed') OR resolved_at IS NOT NULL
    )
);

-- -----------------------------------------------------------------------------
-- 6. ASSIGNMENT
-- Dispatch of verified hazard reports to maintenance personnel
-- -----------------------------------------------------------------------------
CREATE TABLE assignment (
    assignment_id       SERIAL PRIMARY KEY,
    report_id           INT NOT NULL REFERENCES hazard_report(report_id) ON DELETE CASCADE,
    maintenance_user_id INT NOT NULL REFERENCES app_user(user_id),
    assigned_by_user_id INT NOT NULL REFERENCES app_user(user_id),
    assigned_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    assignment_status   VARCHAR(20) NOT NULL DEFAULT 'Assigned'
        CHECK (assignment_status IN ('Assigned', 'In Progress', 'Completed', 'Cancelled')),
    UNIQUE (report_id, maintenance_user_id)
);

-- -----------------------------------------------------------------------------
-- 7. REPORT_STATUS_HISTORY
-- Immutable audit log of all report status transitions
-- -----------------------------------------------------------------------------
CREATE TABLE report_status_history (
    history_id         SERIAL PRIMARY KEY,
    report_id          INT NOT NULL REFERENCES hazard_report(report_id) ON DELETE CASCADE,
    changed_by_user_id INT NOT NULL REFERENCES app_user(user_id),
    status             VARCHAR(30) NOT NULL
        CHECK (status IN ('Submitted', 'Verified', 'Assigned', 'In Progress', 'Resolved', 'Closed')),
    changed_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes              TEXT
);

-- -----------------------------------------------------------------------------
-- 8. MAINTENANCE_ACTION
-- Actions, physical repairs, and resolution logs recorded by technicians
-- -----------------------------------------------------------------------------
CREATE TABLE maintenance_action (
    action_id           SERIAL PRIMARY KEY,
    report_id           INT NOT NULL REFERENCES hazard_report(report_id) ON DELETE CASCADE,
    maintenance_user_id INT NOT NULL REFERENCES app_user(user_id),
    action_details      TEXT NOT NULL,
    action_date         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_resolution       BOOLEAN NOT NULL DEFAULT FALSE,
    notes               TEXT
);

-- -----------------------------------------------------------------------------
-- 9. ATTACHMENT
-- Evidence files, incident photos, and inspection documentation
-- -----------------------------------------------------------------------------
CREATE TABLE attachment (
    attachment_id       SERIAL PRIMARY KEY,
    report_id           INT NOT NULL REFERENCES hazard_report(report_id) ON DELETE CASCADE,
    uploaded_by_user_id INT NOT NULL REFERENCES app_user(user_id),
    file_name           VARCHAR(255) NOT NULL,
    file_path_or_url    TEXT NOT NULL,
    mime_type           VARCHAR(100),
    uploaded_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- INDEXES
-- Index foreign keys and search filter predicates for query performance
-- =============================================================================
CREATE INDEX idx_report_reporter   ON hazard_report(reporter_user_id);
CREATE INDEX idx_report_location   ON hazard_report(location_id);
CREATE INDEX idx_report_category   ON hazard_report(category_id);
CREATE INDEX idx_report_status     ON hazard_report(status);
CREATE INDEX idx_report_submitted  ON hazard_report(submitted_at);
CREATE INDEX idx_assign_report     ON assignment(report_id);
CREATE INDEX idx_assign_maint      ON assignment(maintenance_user_id);
CREATE INDEX idx_history_report    ON report_status_history(report_id);
CREATE INDEX idx_action_report     ON maintenance_action(report_id);
CREATE INDEX idx_attach_report     ON attachment(report_id);
