-- =============================================================================
-- Fix for G07-INC3: Missing Database Trigger for Status History Auditing
-- Designer Group: Group 12 | Target: grp07_campussafedb
--
-- Root Cause: System relied solely on application PHP controller logic to insert
-- records into report_status_history. Direct SQL updates and external tooling
-- bypassed history tracking completely.
-- Corrective Action: Create an AFTER UPDATE OF status trigger on hazard_report
-- that automatically records status transitions into report_status_history.
-- =============================================================================

CREATE OR REPLACE FUNCTION trg_log_hazard_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.status IS DISTINCT FROM NEW.status) THEN
        INSERT INTO report_status_history (
            report_id, 
            changed_by_user_id,
            status, 
            changed_at, 
            notes
        ) VALUES (
            NEW.report_id, 
            COALESCE(NEW.verified_by_user_id, 1),
            NEW.status, 
            NOW(), 
            'Automated database trigger status transition audit: ' || OLD.status || ' -> ' || NEW.status
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_hazard_report_status_audit ON hazard_report;
CREATE TRIGGER trg_hazard_report_status_audit
AFTER UPDATE OF status ON hazard_report
FOR EACH ROW
EXECUTE FUNCTION trg_log_hazard_status_change();

-- Verification Queries:
-- UPDATE hazard_report SET status = 'Verified', verified_by_user_id = 1, verified_at = NOW(), priority = 'Medium' WHERE report_id = 1;
-- SELECT * FROM report_status_history WHERE report_id = 1 ORDER BY changed_at DESC LIMIT 1;
