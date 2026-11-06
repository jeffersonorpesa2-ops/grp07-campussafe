-- ============================================================================
-- Group 7 Evaluation of Group 8 (bwisIT Solutions - Campus Canteen Pre-Order)
-- Activity 6: Post-Restore Verification Suite & Recovery Simulation
-- Target Database: grp08_canteendb_restore_test
-- Schema: public
-- Target RDBMS: PostgreSQL 18.6
-- ============================================================================

-- 1. Verify All 7 Tables Exist and Check Table Ownership
SELECT 
    schemaname,
    tablename, 
    tableowner
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- 2. Verify Record Counts Across All Restored Tables
SELECT 'student' AS tbl, count(*) FROM student
UNION ALL SELECT 'vendor', count(*) FROM vendor
UNION ALL SELECT 'menu_item', count(*) FROM menu_item
UNION ALL SELECT 'customer_order', count(*) FROM customer_order
UNION ALL SELECT 'order_item', count(*) FROM order_item
UNION ALL SELECT 'queue_entry', count(*) FROM queue_entry
UNION ALL SELECT 'notification', count(*) FROM notification;

-- 3. Controlled Recovery Simulation Drill
-- Step 3.1: Pre-Incident Baseline State (Insert Drill Canary Menu Item)
INSERT INTO menu_item (item_id, vendor_id, item_name, price, is_available)
VALUES (999, 1, 'DRILL_CANARY_BURGER', 120.00, TRUE)
ON CONFLICT (item_id) DO NOTHING;

SELECT item_id, vendor_id, item_name, price, is_available 
FROM menu_item 
WHERE item_id = 999;

-- Step 3.2: Simulated Incident (Accidental / Rogue Record Deletion)
DELETE FROM menu_item WHERE item_id = 999;

SELECT count(*) AS canary_count_after_deletion 
FROM menu_item 
WHERE item_id = 999;

-- Step 3.3: Targeted Recovery Insertion
INSERT INTO menu_item (item_id, vendor_id, item_name, price, is_available)
VALUES (999, 1, 'DRILL_CANARY_BURGER', 120.00, TRUE)
ON CONFLICT (item_id) DO NOTHING;

SELECT item_id, vendor_id, item_name, price, is_available 
FROM menu_item 
WHERE item_id = 999;

-- Step 3.4: Post-Drill Cleanup
DELETE FROM menu_item WHERE item_id = 999;
