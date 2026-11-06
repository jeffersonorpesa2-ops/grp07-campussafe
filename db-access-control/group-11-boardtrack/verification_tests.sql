-- =============================================================================
-- Database Administration (COMP 018) — Activity 4: Verification Test Suite
-- Target Project: Group 11 — BoardTrack (Boarding House & Rental Management System)
-- Evaluating Group: Group 7 (Alba, Arreza, Orpesa, Robiso, Santos)
-- Database Engine: PostgreSQL 18.6 on x86_64 Windows
-- Target Database: grp11_boardtrackdb
-- File: verification_tests.sql
-- =============================================================================

-- =============================================================================
-- TEST SUITE 1: Runtime User Verification (`boardtrack_app`)
-- =============================================================================

-- T1.1: Verification of Table Read Access
SELECT 'T1.1_SELECT_PROPERTY' AS test_name, count(*) AS result FROM property;
SELECT 'T1.1_SELECT_ROOM' AS test_name, count(*) AS result FROM room;
SELECT 'T1.1_SELECT_TENANT' AS test_name, count(*) AS result FROM tenant;
SELECT 'T1.1_SELECT_LEASE' AS test_name, count(*) AS result FROM lease;
SELECT 'T1.1_SELECT_PAYMENT' AS test_name, count(*) AS result FROM payment;
SELECT 'T1.1_SELECT_UTILITY' AS test_name, count(*) AS result FROM utility_bill;
SELECT 'T1.1_SELECT_VIEW_SUMMARY' AS test_name, count(*) AS result FROM v_lease_summary;

-- T1.2: Insertion of New Tenant and Room (Valid Operation)
INSERT INTO tenant (full_name, contact_number, email, valid_id_number)
VALUES ('Test Tenant Alpha', '09991112233', 'alpha_test@example.com', 'ID-TEST-001')
RETURNING tenant_id, full_name, email;

INSERT INTO room (property_id, room_number, monthly_rate, status)
VALUES (1, '999', 4200.00, 'AVAILABLE')
RETURNING room_id, room_number, status;

-- T1.3: Update Operation (Valid Operation)
UPDATE tenant
SET contact_number = '09998887766'
WHERE email = 'alpha_test@example.com'
RETURNING tenant_id, full_name, contact_number;

-- T1.4: Payment Ledger Tamper Prevention (DELETE Must Be Prohibited)
-- Expected: ERROR: permission denied for table payment
DELETE FROM payment WHERE payment_id = 1;

-- T1.5: Lease History Tamper Prevention (DELETE Must Be Prohibited)
-- Expected: ERROR: permission denied for table lease
DELETE FROM lease WHERE lease_id = 1;

-- T1.6: DDL Schema Alteration Lockdown (DROP TABLE Must Be Prohibited)
-- Expected: ERROR: must be owner of table property
DROP TABLE property;

-- Cleanup temporary test tenant and room (using DBA in teardown)

-- =============================================================================
-- TEST SUITE 2: Read-Only / Auditor User Verification (`boardtrack_report`)
-- =============================================================================

-- T2.1: Verification of Read Access Across Operational Entities
SELECT 'T2.1_REPORT_PROPERTY' AS test_name, count(*) AS result FROM property;
SELECT 'T2.1_REPORT_PAYMENT' AS test_name, count(*) AS result FROM payment;
SELECT 'T2.1_REPORT_VIEW_SUMMARY' AS test_name, count(*) AS result FROM v_lease_summary;
SELECT 'T2.1_REPORT_USER_DIR' AS test_name, count(*) AS result FROM v_user_directory;

-- T2.2: Data Mutation Prevention (INSERT Must Be Prohibited)
-- Expected: ERROR: permission denied for table property
INSERT INTO property (property_name, address) VALUES ('Unauthorized Property', 'Nowhere');

-- T2.3: Data Mutation Prevention (UPDATE Must Be Prohibited)
-- Expected: ERROR: permission denied for table payment
UPDATE payment SET amount = 99999.00 WHERE payment_id = 1;

-- T2.4: Data Mutation Prevention (DELETE Must Be Prohibited)
-- Expected: ERROR: permission denied for table tenant
DELETE FROM tenant WHERE tenant_id = 1;

-- T2.5: Credential Shielding & Password Hash Privacy
-- Direct SELECT on app_user must be DENIED to prevent dumping password_hash
-- Expected: ERROR: permission denied for table app_user
SELECT user_id, username, password_hash FROM app_user;

-- =============================================================================
-- TEST SUITE 3: Cross-Database & Administrative Boundary Verification
-- =============================================================================

-- T3.1: Cross-Database Boundary Isolation
-- Running under `boardtrack_app` or `boardtrack_report`:
-- Attempt to connect to `grp07_campussafedb`
-- Expected: FATAL: permission denied for database "grp07_campussafedb"

-- T3.2: Sequence Privilege Check
-- `boardtrack_app` can advance sequences
SELECT nextval(pg_get_serial_sequence('tenant', 'tenant_id'));

-- T3.3: Backup User Verification (`boardtrack_backup`)
-- `boardtrack_backup` can read all tables via pg_read_all_data
SELECT count(*) FROM app_user;
SELECT count(*) FROM payment;
