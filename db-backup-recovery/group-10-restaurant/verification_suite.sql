-- ============================================================================
-- Group 7 Evaluation of Group 10 (Binary Sisters - Restaurant Ordering & Reservation)
-- Activity 6: Post-Restore Verification Suite & Recovery Simulation
-- Target Database: grp_binarysisters_projectdb_restore_test
-- Schema: public
-- Target RDBMS: PostgreSQL 18.6
-- ============================================================================

-- 1. Verify All 8 Tables Exist and Check Table Ownership
SELECT 
    schemaname,
    tablename, 
    tableowner
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- 2. Verify Record Counts Across All Restored Tables
SELECT 'customer' AS tbl, count(*) FROM customer
UNION ALL SELECT 'staff', count(*) FROM staff
UNION ALL SELECT 'menu_item', count(*) FROM menu_item
UNION ALL SELECT 'restaurant_table', count(*) FROM restaurant_table
UNION ALL SELECT 'orders', count(*) FROM orders
UNION ALL SELECT 'order_item', count(*) FROM order_item
UNION ALL SELECT 'payment', count(*) FROM payment
UNION ALL SELECT 'reservation', count(*) FROM reservation;

-- 3. Controlled Recovery Simulation Drill
-- Step 3.1: Pre-Incident Baseline State (Insert Drill Canary Menu Item)
INSERT INTO menu_item (menu_item_id, item_name, category, price, availability)
VALUES (999, 'DRILL_CANARY_BULALO', 'Main Course', 450.00, TRUE)
ON CONFLICT (menu_item_id) DO NOTHING;

SELECT menu_item_id, item_name, category, price, availability 
FROM menu_item 
WHERE menu_item_id = 999;

-- Step 3.2: Simulated Incident (Accidental / Rogue Record Deletion)
DELETE FROM menu_item WHERE menu_item_id = 999;

SELECT count(*) AS canary_count_after_deletion 
FROM menu_item 
WHERE menu_item_id = 999;

-- Step 3.3: Targeted Recovery Insertion
INSERT INTO menu_item (menu_item_id, item_name, category, price, availability)
VALUES (999, 'DRILL_CANARY_BULALO', 'Main Course', 450.00, TRUE)
ON CONFLICT (menu_item_id) DO NOTHING;

SELECT menu_item_id, item_name, category, price, availability 
FROM menu_item 
WHERE menu_item_id = 999;

-- Step 3.4: Post-Drill Cleanup
DELETE FROM menu_item WHERE menu_item_id = 999;
