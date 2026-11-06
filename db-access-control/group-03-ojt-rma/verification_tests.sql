-- ============================================================================
-- Group 7 Evaluation of Group OJT-RMA (Project-OJT-RMA-System)
-- Activity 4: Access Control Verification Tests
-- Database: ojt_managementdb
-- Target RDBMS: PostgreSQL 18.6
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TEST SUITE 1: Runtime User (ojt_app)
-- ----------------------------------------------------------------------------

-- Test 1.1: Read Data (Allowed)
SELECT student_id, student_number, first_name, last_name, program FROM students LIMIT 5;

-- Test 1.2: Insert Student Requirement (Allowed)
INSERT INTO requirements (title, is_mandatory)
VALUES ('Temporary Clearance Form', FALSE)
RETURNING req_id, title;

-- Test 1.3: Update Mutable Record (Allowed)
UPDATE requirements SET is_mandatory = TRUE
WHERE title = 'Temporary Clearance Form'
RETURNING req_id, is_mandatory;

-- Test 1.4: Delete Draft Requirement (Allowed)
DELETE FROM requirements WHERE title = 'Temporary Clearance Form'
RETURNING req_id, title;

-- Test 1.5: Insert Attendance (Allowed)
INSERT INTO attendance (placement_id, attendance_date, time_in, time_out, hours_rendered, is_verified)
VALUES (1, CURRENT_DATE, '08:00:00', '17:00:00', 8.00, TRUE)
RETURNING attendance_id, hours_rendered;

-- Test 1.6: Attempt to Delete Attendance (Denied — Attendance Audit Immutability)
DELETE FROM attendance WHERE attendance_id = 1;
-- Expected: ERROR: permission denied for table attendance

-- Test 1.7: Attempt to Delete User Account (Denied — User Identity Protection)
DELETE FROM users WHERE user_id = 1;
-- Expected: ERROR: permission denied for table users

-- Test 1.8: Attempt to Delete Evaluation (Denied — Evaluation Record Tamper Protection)
DELETE FROM evaluations WHERE evaluation_id = 1;
-- Expected: ERROR: permission denied for table evaluations

-- Test 1.9: Alter Table / DDL Operations (Denied)
DROP TABLE attendance;
-- Expected: ERROR: must be owner of table attendance

-- ----------------------------------------------------------------------------
-- TEST SUITE 2: Read-Only / Auditor User (ojt_report)
-- ----------------------------------------------------------------------------

-- Test 2.1: Read Placements and Joined Company Data (Allowed)
SELECT s.student_number, s.first_name, s.last_name, p.status, p.required_hours, c.company_name
FROM students s
JOIN ojt_placements p ON s.student_id = p.student_id
JOIN companies c ON p.company_id = c.company_id;

-- Test 2.2: Attempt to Read User Credentials (Denied — Credential Protection)
SELECT * FROM users;
-- Expected: ERROR: permission denied for table users

-- Test 2.3: Attempt to Insert Data (Denied)
INSERT INTO requirements (title) VALUES ('Rogue Req');
-- Expected: ERROR: permission denied for table requirements

-- Test 2.4: Attempt to Update Records (Denied)
UPDATE evaluations SET score = 100 WHERE evaluation_id = 1;
-- Expected: ERROR: permission denied for table evaluations

-- Test 2.5: Attempt to Delete Records (Denied)
DELETE FROM attendance WHERE attendance_id = 1;
-- Expected: ERROR: permission denied for table attendance

-- ----------------------------------------------------------------------------
-- TEST SUITE 3: Cross-Database & Administrative Boundary
-- ----------------------------------------------------------------------------

-- Test 3.1: Attempt to Create a Database (Denied)
CREATE DATABASE rogue_test_db;
-- Expected: ERROR: permission denied to create database

-- Test 3.2: Attempt to Connect to Unrelated Database (Denied)
-- psql -U ojt_app -h localhost -p 5432 -d grp07_campussafedb -c "SELECT 1;"
-- Expected: FATAL: permission denied for database "grp07_campussafedb"
