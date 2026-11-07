-- =============================================================================
-- Fix for G07-INC5: Missing Conditional Priority Requirement on Verified Reports
-- Designer Group: Group 12 | Target: grp07_campussafedb
--
-- Root Cause: priority column in hazard_report allowed NULL values without state-based
-- enforcement, permitting reports in 'Verified' status without triage priority.
-- Corrective Action: Backfill verified reports having NULL priority with default 'Medium',
-- and add conditional CHECK constraint enforcing priority upon verification.
-- =============================================================================

-- Step 1: Backfill existing NULL priority for verified or downstream statuses
UPDATE hazard_report 
SET priority = 'Medium' 
WHERE status IN ('Verified', 'Assigned', 'In Progress', 'Resolved', 'Closed') AND priority IS NULL;

-- Step 2: Add conditional CHECK constraint
ALTER TABLE hazard_report DROP CONSTRAINT IF EXISTS chk_verified_report_requires_priority;
ALTER TABLE hazard_report 
ADD CONSTRAINT chk_verified_report_requires_priority 
CHECK (status NOT IN ('Verified', 'Assigned', 'In Progress', 'Resolved', 'Closed') OR priority IS NOT NULL);

-- Verification:
-- Negative test (Must fail with check_violation SQLSTATE 23514):
-- UPDATE hazard_report SET status = 'Verified', priority = NULL WHERE report_id = 1;
--
-- Positive test (Must succeed):
-- UPDATE hazard_report SET status = 'Verified', priority = 'High' WHERE report_id = 1;
