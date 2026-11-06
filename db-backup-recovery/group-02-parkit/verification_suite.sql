-- ============================================================================
-- Group 7 Evaluation of Group 2 (Park-It Database Management System)
-- Activity 6: Post-Restore Verification Suite & Recovery Simulation
-- Target Database: grp_parkitdb_restore_test
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
SELECT 'parking_zone' AS tbl, count(*) FROM parking_zone
UNION ALL SELECT 'vehicle', count(*) FROM vehicle
UNION ALL SELECT 'staff_user', count(*) FROM staff_user
UNION ALL SELECT 'transaction', count(*) FROM transaction
UNION ALL SELECT 'payment', count(*) FROM payment;

-- 3. Controlled Recovery Simulation Drill
-- Step 3.1: Pre-Incident Baseline State
INSERT INTO vehicle (vehicle_id, license_plate, vehicle_type) VALUES (999, 'DRILL-999', 'Coupe');
INSERT INTO transaction (transaction_id, vehicle_id, zone_id, entry_time, status)
VALUES (999, 999, 1, CURRENT_TIMESTAMP, 'Active');
INSERT INTO payment (payment_id, transaction_id, amount, payment_method, payment_time)
VALUES (999, 999, 95.00, 'Cash', CURRENT_TIMESTAMP);

SELECT t.transaction_id, v.license_plate, z.zone_name, p.amount, p.payment_method, t.entry_time
FROM transaction t
JOIN vehicle v ON t.vehicle_id = v.vehicle_id
JOIN parking_zone z ON t.zone_id = z.zone_id
JOIN payment p ON t.transaction_id = p.transaction_id
WHERE t.transaction_id = 999;

-- Step 3.2: Simulated Incident (Accidental Catastrophic Deletion)
DELETE FROM payment WHERE payment_id = 999;
DELETE FROM transaction WHERE transaction_id = 999;
DELETE FROM vehicle WHERE vehicle_id = 999;
SELECT count(*) AS count_after_deletion FROM transaction WHERE transaction_id = 999;

-- Step 3.3: Targeted Recovery
INSERT INTO vehicle (vehicle_id, license_plate, vehicle_type) VALUES (999, 'DRILL-999', 'Coupe')
ON CONFLICT (vehicle_id) DO NOTHING;

INSERT INTO transaction (transaction_id, vehicle_id, zone_id, entry_time, status)
VALUES (999, 999, 1, '2026-11-05 16:56:39.027748', 'Active')
ON CONFLICT (transaction_id) DO NOTHING;

INSERT INTO payment (payment_id, transaction_id, amount, payment_method, payment_time)
VALUES (999, 999, 95.00, 'Cash', '2026-11-05 16:56:39.027748')
ON CONFLICT (payment_id) DO NOTHING;

SELECT t.transaction_id, v.license_plate, z.zone_name, p.amount, p.payment_method, t.entry_time
FROM transaction t
JOIN vehicle v ON t.vehicle_id = v.vehicle_id
JOIN parking_zone z ON t.zone_id = z.zone_id
JOIN payment p ON t.transaction_id = p.transaction_id
WHERE t.transaction_id = 999;

-- Step 3.4: Post-Recovery Cleanup
DELETE FROM payment WHERE payment_id = 999;
DELETE FROM transaction WHERE transaction_id = 999;
DELETE FROM vehicle WHERE vehicle_id = 999;
