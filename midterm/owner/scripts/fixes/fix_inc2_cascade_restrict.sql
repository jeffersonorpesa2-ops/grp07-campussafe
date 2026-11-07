-- =============================================================================
-- Fix for G07-INC2: Cascading Deletions Purging Audit & Compliance History
-- Designer Group: Group 12 | Target: grp07_campussafedb
--
-- Root Cause: Foreign keys on dependent tables (report_status_history,
-- maintenance_action, assignment, attachment) used ON DELETE CASCADE, destroying
-- immutable compliance and audit logs when a hazard report was deleted.
-- Corrective Action: Alter foreign keys to ON DELETE RESTRICT and implement
-- soft-deletion support (is_deleted, deleted_at) on hazard_report.
-- =============================================================================

-- Step 1: Restrict deletions on dependent audit and history tables
ALTER TABLE report_status_history DROP CONSTRAINT IF EXISTS fk_status_history_report;
ALTER TABLE report_status_history DROP CONSTRAINT IF EXISTS report_status_history_report_id_fkey;
ALTER TABLE report_status_history ADD CONSTRAINT fk_status_history_report 
    FOREIGN KEY (report_id) REFERENCES hazard_report(report_id) ON DELETE RESTRICT;

ALTER TABLE maintenance_action DROP CONSTRAINT IF EXISTS fk_maintenance_report;
ALTER TABLE maintenance_action DROP CONSTRAINT IF EXISTS maintenance_action_report_id_fkey;
ALTER TABLE maintenance_action ADD CONSTRAINT fk_maintenance_report 
    FOREIGN KEY (report_id) REFERENCES hazard_report(report_id) ON DELETE RESTRICT;

ALTER TABLE assignment DROP CONSTRAINT IF EXISTS fk_assignment_report;
ALTER TABLE assignment DROP CONSTRAINT IF EXISTS assignment_report_id_fkey;
ALTER TABLE assignment ADD CONSTRAINT fk_assignment_report 
    FOREIGN KEY (report_id) REFERENCES hazard_report(report_id) ON DELETE RESTRICT;

ALTER TABLE attachment DROP CONSTRAINT IF EXISTS fk_attachment_report;
ALTER TABLE attachment DROP CONSTRAINT IF EXISTS attachment_report_id_fkey;
ALTER TABLE attachment ADD CONSTRAINT fk_attachment_report 
    FOREIGN KEY (report_id) REFERENCES hazard_report(report_id) ON DELETE RESTRICT;

-- Step 2: Implement soft deletion columns on hazard_report
ALTER TABLE hazard_report ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE;
ALTER TABLE hazard_report ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- Verification Queries:
-- Negative test (Hard delete must fail when child records exist):
-- DELETE FROM hazard_report WHERE report_id = 1; -- ERROR 23503 foreign key violation
--
-- Positive test (Soft delete succeeds while preserving history):
-- UPDATE hazard_report SET is_deleted = TRUE, deleted_at = NOW() WHERE report_id = 1;
