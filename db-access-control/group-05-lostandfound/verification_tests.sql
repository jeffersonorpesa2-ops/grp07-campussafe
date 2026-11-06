-- ============================================================================
-- Group 7 Evaluation of Group 5 (PUP-SPOT — Campus Lost and Found)
-- Activity 4: Access Control Verification Tests
-- Database: grp05_lostandfounddb
-- Target RDBMS: PostgreSQL 18.6
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TEST SUITE 1: Public User (lostandfound_public)
-- ----------------------------------------------------------------------------

-- Test 1.1: Read Found Items (Allowed)
SELECT item_id, title, location_found, date_found, status 
FROM items 
WHERE status = 'unclaimed' 
LIMIT 5;

-- Test 1.2: Insert a Lost Report (Allowed)
INSERT INTO lost_reports (
    report_code, category_id, title, description, location_lost,
    date_lost, full_name, student_number, email, contact_preference, status
) VALUES (
    'TEST-LR-001', 1, 'Lost Student ID Card', 'Blue lanyard with RFID card', 'Main Building 4th Floor',
    CURRENT_DATE, 'Maria Santos', '2023-00123-MN-0', 'maria@iskolarngbayan.pup.edu.ph', 'email', 'active'
) RETURNING report_id, report_code;

-- Test 1.3: Update Lost Report Status (Allowed — Cancel Own Report)
UPDATE lost_reports 
SET status = 'cancelled' 
WHERE report_code = 'TEST-LR-001' 
RETURNING report_id, status;

-- Test 1.4: Insert a Claim Request (Allowed)
INSERT INTO claims (
    claim_code, item_id, full_name, student_number, email, contact_preference, status
) VALUES (
    'TEST-CLM-001', 1, 'Maria Santos', '2023-00123-MN-0', 'maria@iskolarngbayan.pup.edu.ph', 'email', 'pending'
) RETURNING claim_id, claim_code;

-- Test 1.5: Attempt to Approve Own Claim (Denied — Claim Status Tamper Protection)
UPDATE claims SET status = 'approved' WHERE claim_code = 'TEST-CLM-001';
-- Expected: ERROR: permission denied for table claims

-- Test 1.6: Attempt to Alter Found Item Record (Denied — Found Item Integrity)
UPDATE items SET status = 'claimed' WHERE item_id = 1;
-- Expected: ERROR: permission denied for table items

-- Test 1.7: Attempt to Delete Found Item (Denied — Item Record Tamper Protection)
DELETE FROM items WHERE item_id = 1;
-- Expected: ERROR: permission denied for table items

-- Test 1.8: Attempt to Delete Claim (Denied — Audit Trail Protection)
DELETE FROM claims WHERE claim_code = 'TEST-CLM-001';
-- Expected: ERROR: permission denied for table claims

-- Test 1.9: Alter Table / DDL Operations (Denied)
DROP TABLE claims;
-- Expected: ERROR: must be owner of table claims

-- ----------------------------------------------------------------------------
-- TEST SUITE 2: Admin / Campus Marshal User (lostandfound_app)
-- ----------------------------------------------------------------------------

-- Test 2.1: Read Claims and Joined Items (Allowed)
SELECT c.claim_code, c.full_name, c.status AS claim_status, i.title AS item_title
FROM claims c
JOIN items i ON c.item_id = i.item_id
LIMIT 5;

-- Test 2.2: Admin Approve Claim (Allowed)
UPDATE claims 
SET status = 'approved' 
WHERE claim_code = 'TEST-CLM-001' 
RETURNING claim_id, status;

-- Test 2.3: Admin Update Item Status to Claimed (Allowed)
UPDATE items 
SET status = 'claimed' 
WHERE item_id = 1 
RETURNING item_id, status;

-- Test 2.4: Admin Alter Table / DDL Operations (Denied — Not Owner)
DROP TABLE items;
-- Expected: ERROR: must be owner of table items

-- ----------------------------------------------------------------------------
-- TEST SUITE 3: Cross-Database & Administrative Boundary
-- ----------------------------------------------------------------------------

-- Test 3.1: Attempt to Create a Database (Denied)
CREATE DATABASE rogue_test_db;
-- Expected: ERROR: permission denied to create database

-- Test 3.2: Attempt to Connect to Unrelated Database (Denied)
-- psql -U lostandfound_public -h localhost -p 5432 -d grp07_campussafedb -c "SELECT 1;"
-- Expected: FATAL: permission denied for database "grp07_campussafedb"
