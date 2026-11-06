-- ============================================================================
-- Group 7 Evaluation of Group 2 (Park-It Database Management System)
-- Activity 4: Access Control Verification Tests
-- Database: grp_parkitdb
-- Target RDBMS: PostgreSQL 18.6
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TEST SUITE 1: Runtime User (parkit_app)
-- ----------------------------------------------------------------------------

-- Test 1.1: Read Data (Allowed)
SELECT zone_id, zone_name, max_capacity, current_active_count FROM parking_zone LIMIT 5;

-- Test 1.2: Insert a Parking Zone (Allowed)
INSERT INTO parking_zone (zone_name, max_capacity, current_active_count)
VALUES ('West Test Lot', 60, 0)
RETURNING zone_id, zone_name;

-- Test 1.3: Update Mutable Record (Allowed)
UPDATE parking_zone SET current_active_count = 5 WHERE zone_name = 'West Test Lot'
RETURNING zone_id, current_active_count;

-- Test 1.4: Delete Unreferenced Parking Zone (Allowed)
DELETE FROM parking_zone WHERE zone_name = 'West Test Lot'
RETURNING zone_id, zone_name;

-- Test 1.5: Insert a Transaction & Payment (Allowed)
INSERT INTO transaction (vehicle_id, zone_id, entry_time, status)
VALUES (1, 1, CURRENT_TIMESTAMP, 'Active') RETURNING transaction_id;

INSERT INTO payment (transaction_id, amount, payment_method, payment_time)
VALUES ((SELECT max(transaction_id) FROM transaction), 50.00, 'Cash', CURRENT_TIMESTAMP)
RETURNING payment_id, amount;

-- Test 1.6: Attempt to Update Payment (Denied — Financial Ledger Immutability)
UPDATE payment SET amount = 0.00 WHERE transaction_id = 1;
-- Expected: ERROR: permission denied for table payment

-- Test 1.7: Attempt to Delete Payment (Denied — Payment Record Tamper Protection)
DELETE FROM payment WHERE payment_id = 1;
-- Expected: ERROR: permission denied for table payment

-- Test 1.8: Attempt to Delete Parking Transaction (Denied — Audit Trail Protection)
DELETE FROM transaction WHERE transaction_id = 1;
-- Expected: ERROR: permission denied for table transaction

-- Test 1.9: Alter Table / DDL Operations (Denied)
DROP TABLE payment;
-- Expected: ERROR: must be owner of table payment

-- ----------------------------------------------------------------------------
-- TEST SUITE 2: Read-Only / Auditor User (parkit_report)
-- ----------------------------------------------------------------------------

-- Test 2.1: Read Transactions and Joined Data (Allowed)
SELECT t.transaction_id, v.license_plate, z.zone_name, t.status, p.amount, p.payment_method
FROM transaction t
JOIN vehicle v ON t.vehicle_id = v.vehicle_id
JOIN parking_zone z ON t.zone_id = z.zone_id
LEFT JOIN payment p ON t.transaction_id = p.transaction_id
ORDER BY t.transaction_id LIMIT 5;

-- Test 2.2: Attempt to Read User Credentials (Denied — Credential Protection)
SELECT * FROM staff_user;
-- Expected: ERROR: permission denied for table staff_user

-- Test 2.3: Attempt to Insert Data (Denied)
INSERT INTO parking_zone (zone_name, max_capacity, current_active_count) VALUES ('Auditor Rogue Zone', 10, 0);
-- Expected: ERROR: permission denied for table parking_zone

-- Test 2.4: Attempt to Update Records (Denied)
UPDATE parking_zone SET max_capacity = 999 WHERE zone_id = 1;
-- Expected: ERROR: permission denied for table parking_zone

-- Test 2.5: Attempt to Delete Records (Denied)
DELETE FROM transaction WHERE transaction_id = 1;
-- Expected: ERROR: permission denied for table transaction

-- ----------------------------------------------------------------------------
-- TEST SUITE 3: Cross-Database & Administrative Boundary
-- ----------------------------------------------------------------------------

-- Test 3.1: Attempt to Create a Database (Denied)
CREATE DATABASE rogue_test_db;
-- Expected: ERROR: permission denied to create database

-- Test 3.2: Attempt to Connect to Unrelated Database (Denied)
-- psql -U parkit_app -h localhost -p 5432 -d grp07_campussafedb -c "SELECT 1;"
-- Expected: FATAL: permission denied for database "grp07_campussafedb"
