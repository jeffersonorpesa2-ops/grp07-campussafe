-- ============================================================================
-- Group 7 Evaluation of Group HabalGo (HabalGo - Ride and Booking System)
-- Activity 6: Post-Restore Verification Suite & Recovery Simulation
-- Target Database: grp00_habalgodb_restore_test
-- Schema: habalgo
-- Target RDBMS: PostgreSQL 18.6
-- ============================================================================

-- 1. Verify All 8 Tables Exist and Check Table Ownership
SELECT 
    schemaname,
    tablename, 
    tableowner
FROM pg_tables
WHERE schemaname = 'habalgo'
ORDER BY tablename;

-- 2. Verify Record Counts Across All Restored Tables
SELECT 'customer' AS tbl, count(*) FROM habalgo.customer
UNION ALL SELECT 'driver', count(*) FROM habalgo.driver
UNION ALL SELECT 'vehicle', count(*) FROM habalgo.vehicle
UNION ALL SELECT 'driver_vehicle', count(*) FROM habalgo.driver_vehicle
UNION ALL SELECT 'location', count(*) FROM habalgo.location
UNION ALL SELECT 'booking', count(*) FROM habalgo.booking
UNION ALL SELECT 'payment', count(*) FROM habalgo.payment
UNION ALL SELECT 'rating_feedback', count(*) FROM habalgo.rating_feedback;

-- 3. Controlled Recovery Simulation Drill
-- Step 3.1: Pre-Incident Baseline State
INSERT INTO habalgo.booking (booking_id, customer_id, driver_id, pickup_location_id, dropoff_location_id, booking_date, booking_status)
VALUES (999, 1, 1, 1, 2, '2026-11-05 16:00:00', 'Completed')
ON CONFLICT (booking_id) DO NOTHING;

INSERT INTO habalgo.payment (payment_id, booking_id, amount, method, status)
VALUES (999, 999, 175.00, 'Cash', 'Completed')
ON CONFLICT (payment_id) DO NOTHING;

SELECT b.booking_id, c.name AS customer_name, d.name AS driver_name, p.amount, p.method, b.booking_status
FROM habalgo.booking b
JOIN habalgo.customer c ON b.customer_id = c.customer_id
LEFT JOIN habalgo.driver d ON b.driver_id = d.driver_id
JOIN habalgo.payment p ON b.booking_id = p.booking_id
WHERE b.booking_id = 999;

-- Step 3.2: Simulated Incident (Accidental Catastrophic Deletion)
DELETE FROM habalgo.payment WHERE payment_id = 999;
DELETE FROM habalgo.booking WHERE booking_id = 999;
SELECT count(*) AS count_payments_after_deletion FROM habalgo.payment WHERE payment_id = 999;
SELECT count(*) AS count_bookings_after_deletion FROM habalgo.booking WHERE booking_id = 999;

-- Step 3.3: Targeted Recovery
INSERT INTO habalgo.booking (booking_id, customer_id, driver_id, pickup_location_id, dropoff_location_id, booking_date, booking_status)
VALUES (999, 1, 1, 1, 2, '2026-11-05 16:00:00', 'Completed')
ON CONFLICT (booking_id) DO NOTHING;

INSERT INTO habalgo.payment (payment_id, booking_id, amount, method, status)
VALUES (999, 999, 175.00, 'Cash', 'Completed')
ON CONFLICT (payment_id) DO NOTHING;

SELECT b.booking_id, c.name AS customer_name, d.name AS driver_name, p.amount, p.method, b.booking_status
FROM habalgo.booking b
JOIN habalgo.customer c ON b.customer_id = c.customer_id
LEFT JOIN habalgo.driver d ON b.driver_id = d.driver_id
JOIN habalgo.payment p ON b.booking_id = p.booking_id
WHERE b.booking_id = 999;

-- Step 3.4: Post-Recovery Cleanup
DELETE FROM habalgo.payment WHERE payment_id = 999;
DELETE FROM habalgo.booking WHERE booking_id = 999;
