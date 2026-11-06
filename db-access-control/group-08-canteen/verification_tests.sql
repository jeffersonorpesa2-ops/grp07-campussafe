-- ============================================================================
-- Group 7 Evaluation of Group 8 (bwisIT Solutions - Campus Canteen Pre-Order)
-- Activity 4: Access Control Verification Tests
-- Database: grp08_canteendb
-- Schema: public
-- Target RDBMS: PostgreSQL 18.6
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TEST SUITE 1: Runtime User (canteen_app)
-- ----------------------------------------------------------------------------

-- Test 1.1: Read Data (Allowed)
SELECT student_id, full_name, email, role FROM student LIMIT 5;
SELECT vendor_id, vendor_name, email, is_active FROM vendor LIMIT 5;
SELECT item_id, item_name, price, is_available FROM menu_item LIMIT 5;

-- Test 1.2: Insert Student & Vendor (Allowed)
INSERT INTO student (full_name, email, password_hash, role)
VALUES ('Test Student 888', 'test888@student.test', '$2a$10$Dd4c/DygMs67cbKZBnJaZuwylEUDVxrMoauTh1BazaJ.mfh0Kc6y.', 'STUDENT')
RETURNING student_id, full_name;

INSERT INTO vendor (vendor_name, contact_number, email, password_hash, is_active)
VALUES ('Test Vendor Stall', '09991234567', 'teststall@vendor.test', '$2a$10$Dd4c/DygMs67cbKZBnJaZuwylEUDVxrMoauTh1BazaJ.mfh0Kc6y.', TRUE)
RETURNING vendor_id, vendor_name;

-- Test 1.3: Insert Menu Item and Delete It (Allowed for Menu Lifecycle)
INSERT INTO menu_item (vendor_id, item_name, price, is_available)
VALUES ((SELECT vendor_id FROM vendor WHERE email = 'teststall@vendor.test'), 'Temporary Snack', 35.00, TRUE)
RETURNING item_id, item_name;

DELETE FROM menu_item 
WHERE item_name = 'Temporary Snack' AND vendor_id = (SELECT vendor_id FROM vendor WHERE email = 'teststall@vendor.test')
RETURNING item_id, item_name;

-- Test 1.4: Place Customer Order and Append Order Item (Allowed)
INSERT INTO customer_order (student_id, vendor_id, order_date, pickup_time, status)
VALUES (
    (SELECT student_id FROM student WHERE email = 'test888@student.test'),
    (SELECT vendor_id FROM vendor WHERE email = 'teststall@vendor.test'),
    NOW(),
    '15:00',
    'pending'
) RETURNING order_id, status;

INSERT INTO order_item (order_id, item_id, quantity, price_at_order)
VALUES (
    (SELECT max(order_id) FROM customer_order),
    (SELECT min(item_id) FROM menu_item),
    2,
    85.00
) RETURNING order_item_id, quantity, price_at_order;

-- Test 1.5: Advance Order Lifecycle (Allowed)
UPDATE customer_order 
SET status = 'preparing' 
WHERE order_id = (SELECT max(order_id) FROM customer_order)
RETURNING order_id, status;

-- Test 1.6: Attempt to Update Order Item (Denied — Immutability of Financial Line Items)
UPDATE order_item SET price_at_order = 10.00 WHERE order_id = (SELECT max(order_id) FROM customer_order);
-- Expected: ERROR: permission denied for table order_item

-- Test 1.7: Attempt to Delete Order Item (Denied — Immutability of Financial Line Items)
DELETE FROM order_item WHERE order_id = (SELECT max(order_id) FROM customer_order);
-- Expected: ERROR: permission denied for table order_item

-- Test 1.8: Attempt to Delete Customer Order (Denied — Audit Trail Protection)
DELETE FROM customer_order WHERE order_id = (SELECT max(order_id) FROM customer_order);
-- Expected: ERROR: permission denied for table customer_order

-- Test 1.9: Attempt to Delete Student Identity (Denied — Account Integrity)
DELETE FROM student WHERE email = 'test888@student.test';
-- Expected: ERROR: permission denied for table student

-- Test 1.10: Attempt DDL Drop Table (Denied — Schema Protection)
DROP TABLE customer_order;
-- Expected: ERROR: must be owner of table customer_order

-- ----------------------------------------------------------------------------
-- TEST SUITE 2: Read-Only / Auditor User (canteen_report)
-- ----------------------------------------------------------------------------

-- Test 2.1: Read Orders and Joined Line Items (Allowed)
SELECT co.order_id, s.full_name AS student_name, v.vendor_name, co.status, oi.quantity, oi.price_at_order
FROM customer_order co
JOIN student s ON co.student_id = s.student_id
JOIN vendor v ON co.vendor_id = v.vendor_id
JOIN order_item oi ON co.order_id = oi.order_id
LIMIT 5;

-- Test 2.2: Attempt to Insert Student (Denied — Read-Only Role)
INSERT INTO student (full_name, email, password_hash, role)
VALUES ('Rogue Student', 'rogue@student.test', 'hash', 'STUDENT');
-- Expected: ERROR: permission denied for table student

-- Test 2.3: Attempt to Update Order Status (Denied — Read-Only Role)
UPDATE customer_order SET status = 'completed' WHERE order_id = 1;
-- Expected: ERROR: permission denied for table customer_order

-- Test 2.4: Attempt to Delete Menu Item (Denied — Read-Only Role)
DELETE FROM menu_item WHERE item_id = 1;
-- Expected: ERROR: permission denied for table menu_item

-- ----------------------------------------------------------------------------
-- TEST SUITE 3: Cross-Database & Administrative Boundary
-- ----------------------------------------------------------------------------

-- Test 3.1: Attempt to Create a Database (Denied)
CREATE DATABASE canteen_rogue_db;
-- Expected: ERROR: permission denied to create database

-- Test 3.2: Attempt to Connect to Unrelated Database (Denied)
-- psql -U canteen_app -h localhost -p 5432 -d grp07_campussafedb -c "SELECT 1;"
-- Expected: FATAL: permission denied for database "grp07_campussafedb"
