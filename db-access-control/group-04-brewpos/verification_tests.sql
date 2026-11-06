-- ============================================================================
-- Group 7 Evaluation of Group 4 (BrewPOS)
-- Activity 4: Access Control Verification Tests
-- Database: grp_brewposdb
-- Target RDBMS: PostgreSQL 18.6
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TEST SUITE 1: Runtime User (brewpos_app)
-- ----------------------------------------------------------------------------

-- Test 1.1: Read Data (Allowed)
SELECT item_id, item_name, price, is_active FROM menu_item LIMIT 5;

-- Test 1.2: Insert a Menu Item (Allowed)
INSERT INTO menu_item (category_id, item_name, price, is_active)
VALUES (1, 'Test Cinnamon Latte', 135.00, true)
RETURNING item_id, item_name;

-- Test 1.3: Update Mutable Record (Allowed)
UPDATE menu_item SET price = 140.00 WHERE item_id = 23 RETURNING item_id, price;

-- Test 1.4: Delete Unreferenced Menu Item (Allowed)
DELETE FROM menu_item WHERE item_id = 23 RETURNING item_id, item_name;

-- Test 1.5: Insert an Order Ticket & Line Item (Allowed)
INSERT INTO order_ticket (staff_id, payment_method) VALUES (1, 'CASH') RETURNING order_id;
INSERT INTO order_line_item (order_id, item_id, quantity, sold_price)
VALUES (10, 2, 2, 80.00) RETURNING order_id, item_id, quantity, sold_price;

-- Test 1.6: Attempt to Update Order Ticket (Denied - Narrow Immutability Enforcement)
UPDATE order_ticket SET payment_method = 'ONLINE' WHERE order_id = 10;
-- Expected: ERROR: permission denied for table order_ticket

-- Test 1.7: Attempt to Delete Order Ticket (Denied - Sales Record Tamper Protection)
DELETE FROM order_ticket WHERE order_id = 10;
-- Expected: ERROR: permission denied for table order_ticket

-- Test 1.8: Attempt to Delete Order Line Item (Denied)
DELETE FROM order_line_item WHERE order_id = 10;
-- Expected: ERROR: permission denied for table order_line_item

-- Test 1.9: Alter Table / DDL Operations (Denied)
DROP TABLE order_line_item;
-- Expected: ERROR: must be owner of table order_line_item

-- ----------------------------------------------------------------------------
-- TEST SUITE 2: Read-Only / Auditor User (brewpos_auditor)
-- ----------------------------------------------------------------------------

-- Test 2.1: Read Orders and Joined Data (Allowed)
SELECT o.order_id, o.order_timestamp, o.payment_method, s.full_name,
       count(l.item_id) AS line_count, sum(l.quantity * l.sold_price) AS order_total
FROM order_ticket o
JOIN staff s ON o.staff_id = s.staff_id
JOIN order_line_item l ON o.order_id = l.order_id
GROUP BY o.order_id, o.order_timestamp, o.payment_method, s.full_name
ORDER BY o.order_id LIMIT 5;

-- Test 2.2: Attempt to Insert Data (Denied)
INSERT INTO menu_category (category_name) VALUES ('Rogue Category');
-- Expected: ERROR: permission denied for table menu_category

-- Test 2.3: Attempt to Update Records (Denied)
UPDATE menu_item SET price = 999.00 WHERE item_id = 2;
-- Expected: ERROR: permission denied for table menu_item

-- Test 2.4: Attempt to Delete Records (Denied)
DELETE FROM order_ticket WHERE order_id = 1;
-- Expected: ERROR: permission denied for table order_ticket

-- ----------------------------------------------------------------------------
-- TEST SUITE 3: Cross-Database & Administrative Boundary
-- ----------------------------------------------------------------------------

-- Test 3.1: Attempt to Create a Database (Denied)
CREATE DATABASE rogue_test_db;
-- Expected: ERROR: permission denied to create database

-- Test 3.2: Attempt to Connect to Unrelated Database (Denied)
-- psql -U brewpos_app -h localhost -p 5432 -d grp07_campussafedb -c "SELECT 1;"
-- Expected: FATAL: permission denied for database "grp07_campussafedb"
