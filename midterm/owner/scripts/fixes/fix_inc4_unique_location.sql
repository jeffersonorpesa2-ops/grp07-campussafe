-- =============================================================================
-- Fix for G07-INC4: Missing Composite Unique Constraint on Physical Locations
-- Designer Group: Group 12 | Target: grp07_campussafedb
--
-- Root Cause: campus_location possessed only surrogate primary key location_id,
-- lacking candidate natural key constraint on (building, floor, room_area).
-- Corrective Action: Cleanse existing duplicate locations, re-point dependent
-- foreign keys in hazard_report, and enforce UNIQUE (building, floor, room_area).
-- =============================================================================

-- Step 1: Re-point foreign keys in hazard_report to the primary location_id
WITH ranked_locations AS (
    SELECT location_id, 
           FIRST_VALUE(location_id) OVER (PARTITION BY building, floor, room_area ORDER BY location_id) as keep_id,
           ROW_NUMBER() OVER (PARTITION BY building, floor, room_area ORDER BY location_id) as rn
    FROM campus_location
)
UPDATE hazard_report hr
SET location_id = rl.keep_id
FROM ranked_locations rl
WHERE hr.location_id = rl.location_id AND rl.rn > 1;

-- Step 2: Delete redundant duplicate location rows
WITH duplicates AS (
    SELECT location_id, 
           ROW_NUMBER() OVER (PARTITION BY building, floor, room_area ORDER BY location_id) as rn
    FROM campus_location
)
DELETE FROM campus_location
WHERE location_id IN (SELECT location_id FROM duplicates WHERE rn > 1);

-- Step 3: Add composite UNIQUE constraint
ALTER TABLE campus_location DROP CONSTRAINT IF EXISTS uq_campus_location_bldg_floor_room;
ALTER TABLE campus_location 
ADD CONSTRAINT uq_campus_location_bldg_floor_room 
UNIQUE (building, floor, room_area);

-- Verification:
-- Inserting an identical building, floor, and room_area must fail with SQLSTATE 23505:
-- INSERT INTO campus_location (building, floor, room_area) VALUES ('Science Hall', '2nd Floor', 'Room 201');
