-- =============================================================================
-- CampusSafe: Database Complete Reset Script (99_reset.sql)
-- Drops all project tables, triggers, and sequences, then clears the schema.
-- =============================================================================

DROP TABLE IF EXISTS attachment CASCADE;
DROP TABLE IF EXISTS maintenance_action CASCADE;
DROP TABLE IF EXISTS report_status_history CASCADE;
DROP TABLE IF EXISTS assignment CASCADE;
DROP TABLE IF EXISTS hazard_report CASCADE;
DROP TABLE IF EXISTS campus_location CASCADE;
DROP TABLE IF EXISTS hazard_category CASCADE;
DROP TABLE IF EXISTS app_user CASCADE;
DROP TABLE IF EXISTS role CASCADE;

-- Drop sequences if any remained orphaned
DROP SEQUENCE IF EXISTS attachment_attachment_id_seq CASCADE;
DROP SEQUENCE IF EXISTS maintenance_action_action_id_seq CASCADE;
DROP SEQUENCE IF EXISTS report_status_history_history_id_seq CASCADE;
DROP SEQUENCE IF EXISTS assignment_assignment_id_seq CASCADE;
DROP SEQUENCE IF EXISTS hazard_report_report_id_seq CASCADE;
DROP SEQUENCE IF EXISTS campus_location_location_id_seq CASCADE;
DROP SEQUENCE IF EXISTS hazard_category_category_id_seq CASCADE;
DROP SEQUENCE IF EXISTS app_user_user_id_seq CASCADE;
DROP SEQUENCE IF EXISTS role_role_id_seq CASCADE;

SELECT 'CampusSafe schema reset completed successfully.' AS status;
