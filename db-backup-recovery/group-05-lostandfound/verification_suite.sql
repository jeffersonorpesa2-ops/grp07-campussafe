-- ============================================================================
-- Group 7 Evaluation of Group 5 (PUP-SPOT — Campus Lost and Found)
-- Activity 6: Post-Restore Verification Suite & Recovery Simulation
-- Target Database: grp05_lostandfounddb_restore_test
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
SELECT 'categories' AS tbl, count(*) FROM categories
UNION ALL SELECT 'items', count(*) FROM items
UNION ALL SELECT 'lost_reports', count(*) FROM lost_reports
UNION ALL SELECT 'claims', count(*) FROM claims
UNION ALL SELECT 'potential_matches', count(*) FROM potential_matches
UNION ALL SELECT 'item_images', count(*) FROM item_images
UNION ALL SELECT 'lost_report_images', count(*) FROM lost_report_images
UNION ALL SELECT 'claim_images', count(*) FROM claim_images;

-- 3. Controlled Recovery Simulation Drill
-- Step 3.1: Pre-Incident Baseline State
INSERT INTO items (item_id, category_id, title, description, location_found, date_found, time_found, status)
VALUES (999, 1, 'DRILL Lost Wallet', 'Black leather wallet with student ID', 'Library 2nd Floor', '2026-11-05', '14:00:00', 'unclaimed')
ON CONFLICT (item_id) DO NOTHING;

INSERT INTO claims (claim_id, claim_code, item_id, full_name, student_number, email, contact_preference, status)
VALUES (999, 'DRILL-CLM-999', 999, 'Drill Student', '2023-99999-MN-0', 'drill@test.com', 'email', 'pending')
ON CONFLICT (claim_id) DO NOTHING;

SELECT c.claim_id, c.claim_code, c.full_name, i.title AS item_title, i.location_found, c.status AS claim_status
FROM claims c
JOIN items i ON c.item_id = i.item_id
WHERE c.claim_id = 999;

-- Step 3.2: Simulated Incident (Accidental Catastrophic Deletion)
DELETE FROM claims WHERE claim_id = 999;
DELETE FROM items WHERE item_id = 999;
SELECT count(*) AS count_claims_after_deletion FROM claims WHERE claim_id = 999;
SELECT count(*) AS count_items_after_deletion FROM items WHERE item_id = 999;

-- Step 3.3: Targeted Recovery
INSERT INTO items (item_id, category_id, title, description, location_found, date_found, time_found, status)
VALUES (999, 1, 'DRILL Lost Wallet', 'Black leather wallet with student ID', 'Library 2nd Floor', '2026-11-05', '14:00:00', 'unclaimed')
ON CONFLICT (item_id) DO NOTHING;

INSERT INTO claims (claim_id, claim_code, item_id, full_name, student_number, email, contact_preference, status)
VALUES (999, 'DRILL-CLM-999', 999, 'Drill Student', '2023-99999-MN-0', 'drill@test.com', 'email', 'pending')
ON CONFLICT (claim_id) DO NOTHING;

SELECT c.claim_id, c.claim_code, c.full_name, i.title AS item_title, i.location_found, c.status AS claim_status
FROM claims c
JOIN items i ON c.item_id = i.item_id
WHERE c.claim_id = 999;

-- Step 3.4: Post-Recovery Cleanup
DELETE FROM claims WHERE claim_id = 999;
DELETE FROM items WHERE item_id = 999;
