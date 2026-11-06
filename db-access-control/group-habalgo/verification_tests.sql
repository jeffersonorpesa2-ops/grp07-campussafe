-- ============================================================================
-- Group 7 Evaluation of Group HabalGo (HabalGo - Ride and Booking System)
-- Activity 4: Access Control Verification Tests
-- Database: grp00_habalgodb
-- Schema: habalgo
-- Target RDBMS: PostgreSQL 18.6
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TEST SUITE 1: Runtime User (habalgo_app)
-- ----------------------------------------------------------------------------

-- Test 1.1: Read Data (Allowed)
SELECT customer_id, name, phone, email FROM customer LIMIT 5;

-- Test 1.2: Insert Customer (Allowed)
INSERT INTO customer (name, phone, email) 
VALUES ('Pedro Penduko', '09191234567', 'pedro@example.com') 
RETURNING customer_id, name;

-- Test 1.3: Update Mutable Record (Allowed)
UPDATE customer 
SET phone = '09197654321' 
WHERE email = 'pedro@example.com' 
RETURNING customer_id, phone;

-- Test 1.4: Delete Customer (Allowed)
DELETE FROM customer 
WHERE email = 'pedro@example.com' 
RETURNING customer_id, name;

-- Test 1.5: Insert Booking & Payment (Allowed)
INSERT INTO booking (customer_id, driver_id, pickup_location_id, dropoff_location_id, booking_status) 
VALUES (1, 1, 1, 2, 'Pending') 
RETURNING booking_id, booking_status;

INSERT INTO payment (booking_id, amount, method, status) 
VALUES ((SELECT max(booking_id) FROM booking), 150.00, 'Cash', 'Pending') 
RETURNING payment_id, amount;

-- Test 1.6: Attempt to Update Payment (Denied — Financial Ledger Immutability)
UPDATE payment SET amount = 0.00 WHERE payment_id = 1;
-- Expected: ERROR: permission denied for table payment

-- Test 1.7: Attempt to Delete Payment (Denied — Payment Record Tamper Protection)
DELETE FROM payment WHERE payment_id = 1;
-- Expected: ERROR: permission denied for table payment

-- Test 1.8: Attempt to Delete Booking (Denied — Audit Trail Protection)
DELETE FROM booking WHERE booking_id = 1;
-- Expected: ERROR: permission denied for table booking

-- Test 1.9: Alter Table / DDL Operations (Denied)
DROP TABLE payment;
-- Expected: ERROR: must be owner of table payment

-- ----------------------------------------------------------------------------
-- TEST SUITE 2: Read-Only / Auditor User (habalgo_report)
-- ----------------------------------------------------------------------------

-- Test 2.1: Read Bookings and Joined Data (Allowed)
SELECT b.booking_id, c.name AS customer_name, d.name AS driver_name, p.amount, p.method, b.booking_status 
FROM booking b 
JOIN customer c ON b.customer_id = c.customer_id 
LEFT JOIN driver d ON b.driver_id = d.driver_id 
LEFT JOIN payment p ON b.booking_id = p.booking_id 
LIMIT 5;

-- Test 2.2: Attempt to Insert Data (Denied)
INSERT INTO location (address, city) VALUES ('Auditor Rogue Location', 'Manila');
-- Expected: ERROR: permission denied for table location

-- Test 2.3: Attempt to Update Records (Denied)
UPDATE booking SET booking_status = 'Completed' WHERE booking_id = 1;
-- Expected: ERROR: permission denied for table booking

-- Test 2.4: Attempt to Delete Records (Denied)
DELETE FROM customer WHERE customer_id = 1;
-- Expected: ERROR: permission denied for table customer

-- ----------------------------------------------------------------------------
-- TEST SUITE 3: Cross-Database & Administrative Boundary
-- ----------------------------------------------------------------------------

-- Test 3.1: Attempt to Create a Database (Denied)
CREATE DATABASE rogue_test_db;
-- Expected: ERROR: permission denied to create database

-- Test 3.2: Attempt to Connect to Unrelated Database (Denied)
-- psql -U habalgo_app -h localhost -p 5432 -d grp07_campussafedb -c "SELECT 1;"
-- Expected: FATAL: permission denied for database "grp07_campussafedb"
