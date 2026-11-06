-- ============================================================================
-- Group 7 Evaluation of Group OJT-RMA (Project-OJT-RMA-System)
-- Activity 6: Post-Restore Verification Suite & Recovery Simulation
-- Target Database: ojt_managementdb_restore_test
-- Target RDBMS: PostgreSQL 18.6
-- ============================================================================

-- 1. Verify All 14 Tables Exist and Check Table Ownership
SELECT 
    schemaname,
    tablename, 
    tableowner
FROM pg_tables
WHERE schemaname IN ('public', 'lending')
ORDER BY schemaname, tablename;

-- 2. Verify Record Counts Across All Restored Tables
SELECT 'users' AS tbl, count(*) FROM users
UNION ALL SELECT 'students', count(*) FROM students
UNION ALL SELECT 'companies', count(*) FROM companies
UNION ALL SELECT 'academic_supervisors', count(*) FROM academic_supervisors
UNION ALL SELECT 'company_supervisors', count(*) FROM company_supervisors
UNION ALL SELECT 'requirements', count(*) FROM requirements
UNION ALL SELECT 'student_requirements', count(*) FROM student_requirements
UNION ALL SELECT 'ojt_applications', count(*) FROM ojt_applications
UNION ALL SELECT 'ojt_placements', count(*) FROM ojt_placements
UNION ALL SELECT 'attendance', count(*) FROM attendance
UNION ALL SELECT 'evaluations', count(*) FROM evaluations
UNION ALL SELECT 'customers (lending)', count(*) FROM lending.customers
UNION ALL SELECT 'loans (lending)', count(*) FROM lending.loans;

-- 3. Controlled Recovery Simulation Drill
-- Step 3.1: Pre-Incident Baseline State
INSERT INTO users (user_id, username, password_hash, email, role) 
VALUES (999, 'drill_user_999', 'drill_hash_999', 'drill999@test.com', 'Student')
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO students (student_id, user_id, student_number, first_name, last_name, course, year_level)
VALUES (999, 999, '2026-DRILL-999', 'Drill', 'Student', 'BSIT', 4)
ON CONFLICT (student_id) DO NOTHING;

INSERT INTO ojt_placements (placement_id, student_id, company_id, academic_sup_id, company_sup_id, start_date, end_date, required_hours, status)
VALUES (999, 999, 1, 1, 1, '2026-06-01', '2026-09-30', 300.00, 'Active')
ON CONFLICT (placement_id) DO NOTHING;

INSERT INTO attendance (attendance_id, placement_id, attendance_date, time_in, time_out, hours_rendered, is_verified)
VALUES (999, 999, '2026-06-02', '08:00:00', '17:00:00', 8.00, TRUE)
ON CONFLICT (attendance_id) DO NOTHING;

SELECT a.attendance_id, s.student_number, s.first_name || ' ' || s.last_name AS student_name, c.company_name, a.attendance_date, a.hours_rendered, a.is_verified
FROM attendance a
JOIN ojt_placements p ON a.placement_id = p.placement_id
JOIN students s ON p.student_id = s.student_id
JOIN companies c ON p.company_id = c.company_id
WHERE a.attendance_id = 999;

-- Step 3.2: Simulated Incident (Accidental Catastrophic Deletion)
DELETE FROM attendance WHERE attendance_id = 999;
DELETE FROM ojt_placements WHERE placement_id = 999;
SELECT count(*) AS count_attendance_after_deletion FROM attendance WHERE attendance_id = 999;
SELECT count(*) AS count_placements_after_deletion FROM ojt_placements WHERE placement_id = 999;

-- Step 3.3: Targeted Recovery
INSERT INTO ojt_placements (placement_id, student_id, company_id, academic_sup_id, company_sup_id, start_date, end_date, required_hours, status)
VALUES (999, 999, 1, 1, 1, '2026-06-01', '2026-09-30', 300.00, 'Active')
ON CONFLICT (placement_id) DO NOTHING;

INSERT INTO attendance (attendance_id, placement_id, attendance_date, time_in, time_out, hours_rendered, is_verified)
VALUES (999, 999, '2026-06-02', '08:00:00', '17:00:00', 8.00, TRUE)
ON CONFLICT (attendance_id) DO NOTHING;

SELECT a.attendance_id, s.student_number, s.first_name || ' ' || s.last_name AS student_name, c.company_name, a.attendance_date, a.hours_rendered, a.is_verified
FROM attendance a
JOIN ojt_placements p ON a.placement_id = p.placement_id
JOIN students s ON p.student_id = s.student_id
JOIN companies c ON p.company_id = c.company_id
WHERE a.attendance_id = 999;

-- Step 3.4: Post-Recovery Cleanup
DELETE FROM attendance WHERE attendance_id = 999;
DELETE FROM ojt_placements WHERE placement_id = 999;
DELETE FROM students WHERE student_id = 999;
DELETE FROM users WHERE user_id = 999;
