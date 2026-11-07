-- =============================================================================
-- Fix for G07-INC1: Excessive UPDATE Privileges on app_user Table
-- Designer Group: Group 12 | Target: grp07_campussafedb
--
-- Root Cause: Runtime role (app_runtime_grp) had table-wide UPDATE on app_user,
-- allowing unprivileged modification of sensitive role and account_status columns.
-- Corrective Action: Revoke table-wide UPDATE and grant column-level UPDATE
-- strictly on non-sensitive profile columns (full_name, email, password_hash).
-- =============================================================================

-- Step 1: Revoke full-table UPDATE privilege
REVOKE UPDATE ON app_user FROM app_runtime_grp;

-- Step 2: Grant column-level UPDATE on non-sensitive columns only
GRANT UPDATE (full_name, email, password_hash) ON app_user TO app_runtime_grp;

-- Verification Queries:
-- Negative test (Must fail under campussafe_app):
-- SET ROLE campussafe_app;
-- UPDATE app_user SET account_status = 'suspended' WHERE user_id = 2; -- ERROR 42501
--
-- Positive test (Must succeed under campussafe_app):
-- UPDATE app_user SET full_name = 'Verified Name Change' WHERE user_id = 2; -- SUCCESS
-- RESET ROLE;
