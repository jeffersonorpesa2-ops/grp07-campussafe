-- ============================================================================
-- Group 7 Evaluation of Group 4 (BrewPOS)
-- Activity 6: Post-Restore Verification Suite & Recovery Simulation
-- Target Database: grp_brewposdb_restore_test
-- Target RDBMS: PostgreSQL 18.6
-- ============================================================================

-- 1. Verify All 5 Tables Exist and Check Table Ownership
SELECT 
    table_name, 
    table_type,
    (SELECT tableowner FROM pg_tables WHERE tablename = t.table_name) AS owner
FROM information_schema.tables t
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- 2. Verify Record Counts Across All Tables
SELECT 'staff' AS tbl, count(*) FROM staff
UNION ALL SELECT 'menu_category', count(*) FROM menu_category
UNION ALL SELECT 'menu_item', count(*) FROM menu_item
UNION ALL SELECT 'order_ticket', count(*) FROM order_ticket
UNION ALL SELECT 'order_line_item', count(*) FROM order_line_item;

-- 3. Controlled Recovery Simulation Drill
-- Step 3.1: Pre-Incident Baseline State
INSERT INTO order_ticket (order_id, staff_id, order_timestamp, payment_method)
VALUES (999, 1, CURRENT_TIMESTAMP, 'CASH');

INSERT INTO order_line_item (order_id, item_id, quantity, sold_price)
VALUES (999, 2, 3, 80.00);

SELECT o.order_id, o.order_timestamp, o.payment_method, l.item_id, l.quantity, l.sold_price
FROM order_ticket o
JOIN order_line_item l ON o.order_id = l.order_id
WHERE o.order_id = 999;

-- Step 3.2: Simulated Incident (Accidental Catastrophic Deletion)
DELETE FROM order_line_item WHERE order_id = 999;
DELETE FROM order_ticket WHERE order_id = 999;
SELECT count(*) AS count_after_deletion FROM order_ticket WHERE order_id = 999;

-- Step 3.3: Targeted Recovery
INSERT INTO order_ticket (order_id, staff_id, order_timestamp, payment_method)
VALUES (999, 1, '2026-11-05 16:29:13.543537', 'CASH')
ON CONFLICT (order_id) DO NOTHING;

INSERT INTO order_line_item (order_id, item_id, quantity, sold_price)
VALUES (999, 2, 3, 80.00)
ON CONFLICT (order_id, item_id) DO NOTHING;

SELECT o.order_id, o.order_timestamp, o.payment_method, l.item_id, l.quantity, l.sold_price
FROM order_ticket o
JOIN order_line_item l ON o.order_id = l.order_id
WHERE o.order_id = 999;

-- Step 3.4: Post-Recovery Cleanup
DELETE FROM order_line_item WHERE order_id = 999;
DELETE FROM order_ticket WHERE order_id = 999;
