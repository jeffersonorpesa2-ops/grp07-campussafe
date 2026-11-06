-- ============================================================================
-- Group 7 Evaluation of Group 10 (Binary Sisters - Restaurant Ordering & Reservation)
-- Activity 4: Access Control Verification Tests
-- Database: grp_binarysisters_projectdb
-- Schema: public
-- Target RDBMS: PostgreSQL 18.6
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TEST SUITE 1: Runtime User (rors_app)
-- ----------------------------------------------------------------------------

-- Test 1.1: Read Data (Allowed)
SELECT menu_item_id, item_name, category, price, availability FROM menu_item LIMIT 5;
SELECT table_id, table_number, capacity, status FROM restaurant_table LIMIT 5;
SELECT reservation_id, customer_id, table_id, reservation_date, reservation_time, reservation_status FROM reservation LIMIT 5;

-- Test 1.2: Register Customer, Place Order with Items & Payment (Allowed in Transaction)
BEGIN;
INSERT INTO customer (customer_id, first_name, last_name, email, phone, password)
VALUES (999, 'TestCustomer', 'Suite', 'testsuite999@rors.test', '09998887766', 'hashed_pass')
RETURNING customer_id, email;

INSERT INTO orders (order_id, customer_id, order_status)
VALUES (999, 999, 'pending')
RETURNING order_id, order_status;

INSERT INTO order_item (order_id, menu_item_id, quantity, unit_price, subtotal)
VALUES (999, 1, 2, 280.00, 560.00)
RETURNING order_id, menu_item_id, subtotal;

INSERT INTO payment (payment_id, order_id, payment_method, amount, payment_status)
VALUES (999, 999, 'gcash', 560.00, 'pending')
RETURNING payment_id, amount, payment_status;
COMMIT;

-- Test 1.3: Advance Order Lifecycle (Allowed)
UPDATE orders 
SET order_status = 'confirmed' 
WHERE order_id = 999 
RETURNING order_id, order_status;

-- Test 1.4: Manage Menu Item Lifecycle (Insert & Delete Allowed)
INSERT INTO menu_item (menu_item_id, item_name, category, price, availability)
VALUES (999, 'Temporary Drill Dessert', 'Dessert', 150.00, TRUE)
RETURNING menu_item_id, item_name;

DELETE FROM menu_item WHERE menu_item_id = 999 RETURNING menu_item_id, item_name;

-- Test 1.5: Attempt to Update Order Item (Denied — Immutability of Financial Line Items)
UPDATE order_item SET unit_price = 10.00 WHERE order_id = 999;
-- Expected: ERROR: permission denied for table order_item

-- Test 1.6: Attempt to Delete Order Item (Denied — Immutability of Financial Line Items)
DELETE FROM order_item WHERE order_id = 999;
-- Expected: ERROR: permission denied for table order_item

-- Test 1.7: Attempt to Delete Order (Denied — Audit Trail Protection)
DELETE FROM orders WHERE order_id = 999;
-- Expected: ERROR: permission denied for table orders

-- Test 1.8: Attempt to Delete Payment (Denied — Financial Ledger Tamper Protection)
DELETE FROM payment WHERE payment_id = 999;
-- Expected: ERROR: permission denied for table payment

-- Test 1.9: Attempt to Delete Customer Identity (Denied — Account Integrity)
DELETE FROM customer WHERE customer_id = 999;
-- Expected: ERROR: permission denied for table customer

-- Test 1.10: Attempt DDL Drop Table (Denied — Schema Protection)
DROP TABLE orders;
-- Expected: ERROR: must be owner of table orders

-- ----------------------------------------------------------------------------
-- TEST SUITE 2: Read-Only / Auditor User (rors_report)
-- ----------------------------------------------------------------------------

-- Test 2.1: Read Orders and Joined Financial Line Items (Allowed)
SELECT o.order_id, c.first_name || ' ' || c.last_name AS customer_name, o.order_status, o.total_amount, p.payment_method, p.payment_status
FROM orders o
JOIN customer c ON o.customer_id = c.customer_id
LEFT JOIN payment p ON o.order_id = p.order_id
LIMIT 5;

-- Test 2.2: Read Sanitized Reporting Views (Allowed)
SELECT * FROM v_order_summary LIMIT 3;
SELECT * FROM v_customer_directory LIMIT 3;

-- Test 2.3: Attempt to Read Direct Customer Password Hash (Denied — Credential Protection)
SELECT password FROM customer LIMIT 1;
-- Expected: ERROR: permission denied for table customer

-- Test 2.4: Attempt to Insert Menu Item (Denied — Read-Only Role)
INSERT INTO menu_item (item_name, category, price) VALUES ('Rogue Item', 'Dessert', 50.00);
-- Expected: ERROR: permission denied for table menu_item

-- Test 2.5: Attempt to Update Order Status (Denied — Read-Only Role)
UPDATE orders SET order_status = 'completed' WHERE order_id = 1;
-- Expected: ERROR: permission denied for table orders

-- Test 2.6: Attempt to Delete Reservation (Denied — Read-Only Role)
DELETE FROM reservation WHERE reservation_id = 1;
-- Expected: ERROR: permission denied for table reservation

-- ----------------------------------------------------------------------------
-- TEST SUITE 3: Cross-Database & Administrative Boundary
-- ----------------------------------------------------------------------------

-- Test 3.1: Attempt to Create a Database (Denied)
CREATE DATABASE rors_rogue_db;
-- Expected: ERROR: permission denied to create database

-- Test 3.2: Attempt to Connect to Unrelated Database (Denied)
-- psql -U rors_app -h localhost -p 5432 -d grp07_campussafedb -c "SELECT 1;"
-- Expected: FATAL: permission denied for database "grp07_campussafedb"
