-- =============================================================================
-- CampusSafe: Campus Hazard & Safety Reporting System
-- Seed Data Script (02_seed.sql)
-- Target Database: grp07_campussafedb
--
-- Notes:
-- Standard demo password for all seed accounts: Password123!
-- Bcrypt Hash: $2y$10$nGRztYb8oyzGy3ZHsGOkgO6Wv21nFcYJ8764U8YfFZL.CN0iCgW2C
-- =============================================================================

-- Clean up any existing data in tables
TRUNCATE TABLE attachment, maintenance_action, report_status_history,
               assignment, hazard_report, campus_location,
               hazard_category, app_user, role RESTART IDENTITY CASCADE;

-- -----------------------------------------------------------------------------
-- 1. ROLES
-- -----------------------------------------------------------------------------
INSERT INTO role (role_id, role_name, description) VALUES
(1, 'Student', 'Student reporter: can submit hazards and view own report history'),
(2, 'Faculty/Staff', 'Faculty and staff reporter: can submit hazards and view own reports'),
(3, 'Maintenance', 'Maintenance technician: can view assigned reports, log actions, and mark resolved'),
(4, 'Administrator', 'Campus safety administrator: full oversight, verification, assignment, master data'),
(5, 'Auditor', 'Safety compliance auditor: read-only access to statistics and reports');

-- Reset sequence to continue after manual IDs
SELECT setval('role_role_id_seq', (SELECT MAX(role_id) FROM role));

-- -----------------------------------------------------------------------------
-- 2. APP_USERS (All demo accounts use password: Password123!)
-- -----------------------------------------------------------------------------
INSERT INTO app_user (user_id, role_id, full_name, email, username, password_hash, account_status, created_at) VALUES
(1, 4, 'Eleanor Vance (Admin)', 'admin@campussafe.edu', 'demo_admin', '$2y$10$nGRztYb8oyzGy3ZHsGOkgO6Wv21nFcYJ8764U8YfFZL.CN0iCgW2C', 'active', '2026-10-01 08:00:00'),
(2, 3, 'Alex Davis (Senior Tech)', 'davis@campussafe.edu', 'demo_maint1', '$2y$10$nGRztYb8oyzGy3ZHsGOkgO6Wv21nFcYJ8764U8YfFZL.CN0iCgW2C', 'active', '2026-10-01 08:30:00'),
(3, 3, 'Carlos Reyes (Electrician)', 'reyes@campussafe.edu', 'demo_maint2', '$2y$10$nGRztYb8oyzGy3ZHsGOkgO6Wv21nFcYJ8764U8YfFZL.CN0iCgW2C', 'active', '2026-10-01 09:00:00'),
(4, 1, 'Maria Santos (Student)', 'santos@campussafe.edu', 'demo_student', '$2y$10$nGRztYb8oyzGy3ZHsGOkgO6Wv21nFcYJ8764U8YfFZL.CN0iCgW2C', 'active', '2026-10-02 10:15:00'),
(5, 2, 'Dr. Robert Hernandez (Faculty)', 'hernandez@campussafe.edu', 'demo_faculty', '$2y$10$nGRztYb8oyzGy3ZHsGOkgO6Wv21nFcYJ8764U8YfFZL.CN0iCgW2C', 'active', '2026-10-02 11:00:00'),
(6, 5, 'Grace Kim (Safety Auditor)', 'kim@campussafe.edu', 'demo_auditor', '$2y$10$nGRztYb8oyzGy3ZHsGOkgO6Wv21nFcYJ8764U8YfFZL.CN0iCgW2C', 'active', '2026-10-02 11:30:00');

SELECT setval('app_user_user_id_seq', (SELECT MAX(user_id) FROM app_user));

-- -----------------------------------------------------------------------------
-- 3. HAZARD_CATEGORIES
-- -----------------------------------------------------------------------------
INSERT INTO hazard_category (category_id, category_name, description, is_active) VALUES
(1, 'Electrical', 'Faulty wiring, sparking outlets, exposed cables, malfunctioning breakers', TRUE),
(2, 'Structural', 'Ceiling tile damage, water seepage, cracked drywall, loose stair handrails', TRUE),
(3, 'Sanitation', 'Plumbing leaks, sewage overflow, restroom blockages, biohazardous spills', TRUE),
(4, 'Equipment', 'Broken elevators, malfunctioning HVAC ventilation, lab fume hood failure', TRUE),
(5, 'Fire Safety', 'Blocked emergency egress, uninspected fire extinguishers, faulty smoke alarms', TRUE),
(6, 'Other Safety', 'Poor pathway lighting, slippery walking surfaces, fallen debris, pest infestation', TRUE);

SELECT setval('hazard_category_category_id_seq', (SELECT MAX(category_id) FROM hazard_category));

-- -----------------------------------------------------------------------------
-- 4. CAMPUS_LOCATIONS
-- -----------------------------------------------------------------------------
INSERT INTO campus_location (location_id, building, floor, room_area, location_description, is_active) VALUES
(1, 'Science & Technology Hall', '3rd Floor', 'Room 304', 'Organic Chemistry Laboratory near fume hood station', TRUE),
(2, 'Main Academic Complex', '1st Floor', 'Room 101', 'Large lecture auditorium main entrance double-doors', TRUE),
(3, 'Engineering Wing', 'Ground Floor', 'Machine Shop 12', 'Heavy machinery and metal fabrication bay', TRUE),
(4, 'Central Library', '2nd Floor', 'Periodicals Wing', 'Quiet research tables adjacent to east exterior windows', TRUE),
(5, 'Student Activities Center', 'Ground Floor', 'West Cafeteria', 'Food preparation and student dining seating zone', TRUE),
(6, 'University Gymnasium', 'Basement', 'Locker Room B', 'Men varsity team dressing area and shower stalls', TRUE),
(7, 'Administration Pavilion', '4th Floor', 'Executive Boardroom', 'Central administration conference hall and foyer', TRUE),
(8, 'Arts & Humanities Building', '2nd Floor', 'Studio 215', 'Fine arts drawing and ceramics workspace', TRUE),
(9, 'Information Technology Center', '1st Floor', 'Server Corridor 108', 'Access corridor leading to campus network rack room', TRUE),
(10, 'North Campus Parking Structure', 'Level 2', 'Northeast Stairwell', 'Pedestrian concrete stairwell descending to ground level', TRUE);

SELECT setval('campus_location_location_id_seq', (SELECT MAX(location_id) FROM campus_location));

-- -----------------------------------------------------------------------------
-- 5. HAZARD_REPORTS (16 comprehensive reports covering all lifecycle stages)
-- -----------------------------------------------------------------------------
-- Reports 1 & 2: Status = 'Submitted' (unverified, priority NULL)
INSERT INTO hazard_report (report_id, reporter_user_id, location_id, category_id, description, priority, status, submitted_at, verified_by_user_id, verified_at, resolved_at) VALUES
(1, 4, 1, 1, 'Exposed power wiring hanging loose behind workstation 4 lab bench.', NULL, 'Submitted', '2026-10-15 09:20:00', NULL, NULL, NULL),
(2, 5, 2, 6, 'Overhead lighting fixture flickers loudly and ballast smells like burned plastic.', NULL, 'Submitted', '2026-10-15 11:45:00', NULL, NULL, NULL),

-- Reports 3 & 4: Status = 'Verified' (verified by Admin, priority set, awaiting assignment)
(3, 4, 3, 4, 'Hydraulic oil puddle leaking from CNC milling station 2 creating severe slip hazard.', 'High', 'Verified', '2026-10-16 08:15:00', 1, '2026-10-16 09:30:00', NULL),
(4, 5, 4, 2, 'Ceiling plaster tile bulging downward from rain accumulation above study desk 14.', 'Medium', 'Verified', '2026-10-16 13:00:00', 1, '2026-10-16 14:10:00', NULL),

-- Reports 5, 6, 7: Status = 'Assigned' (assigned to maintenance technicians)
(5, 4, 5, 3, 'Floor drain backing up wastewater near cafeteria dishwasher prep sink.', 'High', 'Assigned', '2026-10-17 07:45:00', 1, '2026-10-17 08:15:00', NULL),
(6, 5, 6, 1, 'Shower area wall outlet cover missing with wet conductors exposed.', 'Critical', 'Assigned', '2026-10-17 10:00:00', 1, '2026-10-17 10:30:00', NULL),
(7, 4, 7, 5, 'Fire exit stair door latch stuck in locked position from inside hallway.', 'Critical', 'Assigned', '2026-10-17 14:20:00', 1, '2026-10-17 15:00:00', NULL),

-- Reports 8, 9, 10: Status = 'In Progress' (technician actively working)
(8, 4, 8, 2, 'Loose wooden step on mezzanine stairs wobbles when stepped upon.', 'Medium', 'In Progress', '2026-10-18 09:00:00', 1, '2026-10-18 10:00:00', NULL),
(9, 5, 9, 4, 'Air handling unit AHU-3 emitting grinding screech; temperature rising in server room.', 'High', 'In Progress', '2026-10-18 11:30:00', 1, '2026-10-18 12:15:00', NULL),
(10, 4, 10, 6, 'Stairwell light fixtures completely dark on northeast stair landing.', 'Medium', 'In Progress', '2026-10-18 13:40:00', 1, '2026-10-18 14:10:00', NULL),

-- Reports 11, 12, 13: Status = 'Resolved' (repaired, resolved_at set)
(11, 4, 1, 5, 'Chemical fire extinguisher inspection tag missing and gauge in recharge red zone.', 'High', 'Resolved', '2026-10-19 08:30:00', 1, '2026-10-19 09:00:00', '2026-10-19 14:00:00'),
(12, 5, 3, 1, 'Circuit breaker tripping repeatedly when air compressor engages.', 'High', 'Resolved', '2026-10-19 10:15:00', 1, '2026-10-19 11:00:00', '2026-10-20 11:30:00'),
(13, 4, 5, 3, 'Broken soap dispenser dripping liquid onto smooth tile entryway.', 'Low', 'Resolved', '2026-10-20 09:10:00', 1, '2026-10-20 10:00:00', '2026-10-20 15:45:00'),

-- Reports 14, 15, 16: Status = 'Closed' (audited and closed by Admin)
(14, 5, 2, 2, 'Handrail bracket detached on west entrance handicap access ramp.', 'High', 'Closed', '2026-10-21 08:00:00', 1, '2026-10-21 08:45:00', '2026-10-21 16:30:00'),
(15, 4, 4, 4, 'Window latch broken, allowing rain water to blow onto power strips.', 'Medium', 'Closed', '2026-10-22 13:10:00', 1, '2026-10-22 13:50:00', '2026-10-23 10:20:00'),
(16, 5, 6, 6, 'Water fountain spout pressure excessive, spraying water 3 feet onto walkway.', 'Low', 'Closed', '2026-10-22 15:00:00', 1, '2026-10-22 15:30:00', '2026-10-23 14:15:00');

SELECT setval('hazard_report_report_id_seq', (SELECT MAX(report_id) FROM hazard_report));

-- -----------------------------------------------------------------------------
-- 6. ASSIGNMENTS
-- -----------------------------------------------------------------------------
INSERT INTO assignment (assignment_id, report_id, maintenance_user_id, assigned_by_user_id, assigned_at, assignment_status) VALUES
-- Assigned
(1, 5, 2, 1, '2026-10-17 08:30:00', 'Assigned'),
(2, 6, 3, 1, '2026-10-17 10:45:00', 'Assigned'),
(3, 7, 2, 1, '2026-10-17 15:15:00', 'Assigned'),
-- In Progress
(4, 8, 2, 1, '2026-10-18 10:15:00', 'In Progress'),
(5, 9, 3, 1, '2026-10-18 12:30:00', 'In Progress'),
(6, 10, 3, 1, '2026-10-18 14:30:00', 'In Progress'),
-- Resolved
(7, 11, 2, 1, '2026-10-19 09:15:00', 'Completed'),
(8, 12, 3, 1, '2026-10-19 11:15:00', 'Completed'),
(9, 13, 2, 1, '2026-10-20 10:15:00', 'Completed'),
-- Closed
(10, 14, 2, 1, '2026-10-21 09:00:00', 'Completed'),
(11, 15, 2, 1, '2026-10-22 14:00:00', 'Completed'),
(12, 16, 3, 1, '2026-10-22 15:45:00', 'Completed');

SELECT setval('assignment_assignment_id_seq', (SELECT MAX(assignment_id) FROM assignment));

-- -----------------------------------------------------------------------------
-- 7. REPORT_STATUS_HISTORY (Detailed transitions for complete audit trail)
-- -----------------------------------------------------------------------------
INSERT INTO report_status_history (report_id, changed_by_user_id, status, changed_at, notes) VALUES
-- Report 1 & 2 (Submitted)
(1, 4, 'Submitted', '2026-10-15 09:20:00', 'Initial report submitted by student.'),
(2, 5, 'Submitted', '2026-10-15 11:45:00', 'Initial report submitted by faculty member.'),

-- Report 3 (Verified)
(3, 4, 'Submitted', '2026-10-16 08:15:00', 'Report submitted.'),
(3, 1, 'Verified', '2026-10-16 09:30:00', 'Inspected photo. High risk of slipping around machinery. Prioritized High.'),

-- Report 4 (Verified)
(4, 5, 'Submitted', '2026-10-16 13:00:00', 'Report submitted.'),
(4, 1, 'Verified', '2026-10-16 14:10:00', 'Verified ceiling damage. Prioritized Medium.'),

-- Report 5 (Assigned)
(5, 4, 'Submitted', '2026-10-17 07:45:00', 'Report submitted.'),
(5, 1, 'Verified', '2026-10-17 08:15:00', 'Verified plumbing hazard.'),
(5, 1, 'Assigned', '2026-10-17 08:30:00', 'Assigned to Alex Davis (Lead Tech).'),

-- Report 6 (Assigned)
(6, 5, 'Submitted', '2026-10-17 10:00:00', 'Report submitted.'),
(6, 1, 'Verified', '2026-10-17 10:30:00', 'Critical electrical risk in damp locker room environment.'),
(6, 1, 'Assigned', '2026-10-17 10:45:00', 'Dispatched to Carlos Reyes (Certified Electrician).'),

-- Report 7 (Assigned)
(7, 4, 'Submitted', '2026-10-17 14:20:00', 'Report submitted.'),
(7, 1, 'Verified', '2026-10-17 15:00:00', 'Life safety emergency exit violation verified.'),
(7, 1, 'Assigned', '2026-10-17 15:15:00', 'Assigned urgent priority to Alex Davis.'),

-- Report 8 (In Progress)
(8, 4, 'Submitted', '2026-10-18 09:00:00', 'Report submitted.'),
(8, 1, 'Verified', '2026-10-18 10:00:00', 'Verified stair step stability concern.'),
(8, 1, 'Assigned', '2026-10-18 10:15:00', 'Assigned to Alex Davis.'),
(8, 2, 'In Progress', '2026-10-18 11:00:00', 'On-site assessing stair stringer and tread anchors.'),

-- Report 9 (In Progress)
(9, 5, 'Submitted', '2026-10-18 11:30:00', 'Report submitted.'),
(9, 1, 'Verified', '2026-10-18 12:15:00', 'Verified HVAC cooling failure in server room.'),
(9, 1, 'Assigned', '2026-10-18 12:30:00', 'Assigned to Carlos Reyes.'),
(9, 3, 'In Progress', '2026-10-18 13:00:00', 'Inspecting blower bearings and drive belt assembly.'),

-- Report 10 (In Progress)
(10, 4, 'Submitted', '2026-10-18 13:40:00', 'Report submitted.'),
(10, 1, 'Verified', '2026-10-18 14:10:00', 'Verified dark stairwell hazard.'),
(10, 1, 'Assigned', '2026-10-18 14:30:00', 'Assigned to Carlos Reyes.'),
(10, 3, 'In Progress', '2026-10-18 15:00:00', 'Testing emergency battery backup driver circuit.'),

-- Report 11 (Resolved)
(11, 4, 'Submitted', '2026-10-19 08:30:00', 'Report submitted.'),
(11, 1, 'Verified', '2026-10-19 09:00:00', 'Verified fire extinguisher pressure discharge.'),
(11, 1, 'Assigned', '2026-10-19 09:15:00', 'Assigned to Alex Davis.'),
(11, 2, 'In Progress', '2026-10-19 10:00:00', 'Retrieved replacement 10lb ABC dry chemical cylinder.'),
(11, 2, 'Resolved', '2026-10-19 14:00:00', 'Swapped with certified, freshly tagged unit. Inspected bracket.'),

-- Report 12 (Resolved)
(12, 5, 'Submitted', '2026-10-19 10:15:00', 'Report submitted.'),
(12, 1, 'Verified', '2026-10-19 11:00:00', 'Verified electrical tripping hazard.'),
(12, 1, 'Assigned', '2026-10-19 11:15:00', 'Assigned to Carlos Reyes.'),
(12, 3, 'In Progress', '2026-10-19 13:00:00', 'Running megohmmeter insulation resistance test.'),
(12, 3, 'Resolved', '2026-10-20 11:30:00', 'Replaced faulty 30A thermal-magnetic breaker and tightened terminal lugs.'),

-- Report 13 (Resolved)
(13, 4, 'Submitted', '2026-10-20 09:10:00', 'Report submitted.'),
(13, 1, 'Verified', '2026-10-20 10:00:00', 'Verified dispenser leak.'),
(13, 1, 'Assigned', '2026-10-20 10:15:00', 'Assigned to Alex Davis.'),
(13, 2, 'In Progress', '2026-10-20 11:00:00', 'Secured area, wiping spilled soap solution.'),
(13, 2, 'Resolved', '2026-10-20 15:45:00', 'Installed new wall-mounted touchless soap dispenser.'),

-- Report 14 (Closed)
(14, 5, 'Submitted', '2026-10-21 08:00:00', 'Report submitted.'),
(14, 1, 'Verified', '2026-10-21 08:45:00', 'Verified loose ramp handrail.'),
(14, 1, 'Assigned', '2026-10-21 09:00:00', 'Assigned to Alex Davis.'),
(14, 2, 'In Progress', '2026-10-21 10:30:00', 'Drilling new expansion anchors into concrete.'),
(14, 2, 'Resolved', '2026-10-21 16:30:00', 'Handrail securely anchored with epoxy bolts. Tested for 250lb load.'),
(14, 1, 'Closed', '2026-10-22 08:30:00', 'Post-repair safety audit confirmed ADA compliance. Closed.'),

-- Report 15 (Closed)
(15, 4, 'Submitted', '2026-10-22 13:10:00', 'Report submitted.'),
(15, 1, 'Verified', '2026-10-22 13:50:00', 'Verified broken window sash latch.'),
(15, 1, 'Assigned', '2026-10-22 14:00:00', 'Assigned to Alex Davis.'),
(15, 2, 'In Progress', '2026-10-22 15:00:00', 'Temporary weatherproofing seal applied.'),
(15, 2, 'Resolved', '2026-10-23 10:20:00', 'Replaced dual cam sash lock and weatherstripping.'),
(15, 1, 'Closed', '2026-10-23 11:00:00', 'Inspected watertight closure. Closed.'),

-- Report 16 (Closed)
(16, 5, 'Submitted', '2026-10-22 15:00:00', 'Report submitted.'),
(16, 1, 'Verified', '2026-10-22 15:30:00', 'Verified drinking fountain pressure issue.'),
(16, 1, 'Assigned', '2026-10-22 15:45:00', 'Assigned to Carlos Reyes.'),
(16, 3, 'In Progress', '2026-10-23 09:00:00', 'Disassembling regulator cartridge.'),
(16, 3, 'Resolved', '2026-10-23 14:15:00', 'Replaced pressure regulator valve and calibrated nozzle arc.'),
(16, 1, 'Closed', '2026-10-23 15:00:00', 'Audited water stream height. Satisfactory and closed.');

-- -----------------------------------------------------------------------------
-- 8. MAINTENANCE_ACTIONS
-- -----------------------------------------------------------------------------
INSERT INTO maintenance_action (report_id, maintenance_user_id, action_details, action_date, is_resolution, notes) VALUES
(8, 2, 'Constructed temporary barricade tape around damaged mezzanine step; measuring replacement lumber.', '2026-10-18 11:30:00', FALSE, 'Procured 2x10 oak tread piece.'),
(9, 3, 'Lubricated pillow block bearings; detected severe metal fatigue on blower fan motor belt.', '2026-10-18 13:45:00', FALSE, 'Ordered cogged v-belt #AX48.'),
(10, 3, 'Tested ballast and confirmed internal capacitor open circuit. Ordered LED driver unit.', '2026-10-18 15:30:00', FALSE, 'Replaced bulb tube as intermediate test.'),
(11, 2, 'De-installed discharged fire extinguisher and mounted tested Class ABC fire suppression cylinder #FE-8812.', '2026-10-19 14:00:00', TRUE, 'Inspection tag signed and dated.'),
(12, 3, 'Swapped fatigued 30A circuit breaker with certified Eaton BR230 breaker; confirmed 0.2 ohm ground impedance.', '2026-10-20 11:30:00', TRUE, 'Load tested with dual air compressors running.'),
(13, 2, 'Uninstalled defective dispenser housing, cleaned wall tile, and mounted new commercial dispenser unit.', '2026-10-20 15:45:00', TRUE, 'Filled with antibacterial foam soap.'),
(14, 2, 'Fastened heavy-duty stainless steel anchor plates using Hilti adhesive anchor studs.', '2026-10-21 16:30:00', TRUE, 'Meets structural building code requirements.'),
(15, 2, 'Fitted heavy zinc die-cast window locking mechanism and adjusted counterbalance springs.', '2026-10-23 10:20:00', TRUE, 'Window opens and seals properly.'),
(16, 3, 'Adjusted flow restrictor orifice and renewed rubber diaphragm inside fountain valve body.', '2026-10-23 14:15:00', TRUE, 'Stream now stays safely inside basin basin.');

-- -----------------------------------------------------------------------------
-- 9. ATTACHMENTS
-- -----------------------------------------------------------------------------
INSERT INTO attachment (attachment_id, report_id, uploaded_by_user_id, file_name, file_path_or_url, mime_type, uploaded_at) VALUES
(1, 1, 4, 'exposed_cable_photo.jpg', 'uploads/exposed_cable_photo.jpg', 'image/jpeg', '2026-10-15 09:20:00'),
(2, 3, 4, 'oil_spill_cnc.jpg', 'uploads/oil_spill_cnc.jpg', 'image/jpeg', '2026-10-16 08:15:00'),
(3, 4, 5, 'ceiling_leak_bulge.png', 'uploads/ceiling_leak_bulge.png', 'image/png', '2026-10-16 13:00:00'),
(4, 7, 4, 'jammed_exit_door.jpg', 'uploads/jammed_exit_door.jpg', 'image/jpeg', '2026-10-17 14:20:00'),
(5, 11, 4, 'discharged_extinguisher.jpg', 'uploads/discharged_extinguisher.jpg', 'image/jpeg', '2026-10-19 08:30:00');

SELECT setval('attachment_attachment_id_seq', (SELECT MAX(attachment_id) FROM attachment));
