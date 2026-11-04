# CampusSafe — Comprehensive System Testing Guide

**System:** CampusSafe: Campus Hazard & Safety Reporting System  
**Course:** COMP 018 Database Administration &bull; Group 7  
**Scope:** Activities 3, 4, 5, and 6 Quality Assurance, Peer Evaluation & Grading Verification  

---

## Table of Contents

1. [Quick Sanity & Environment Setup](#1-quick-sanity--environment-setup)
2. [Demo Credentials Quick Reference](#2-demo-credentials-quick-reference)
3. [End-to-End Role-Based Walkthroughs](#3-end-to-end-role-based-walkthroughs)
4. [Feature-by-Feature CRUD Testing Matrix](#4-feature-by-feature-crud-testing-matrix)
5. [Security & Negative Test Cases (Exploitation Prevention)](#5-security--negative-test-cases-exploitation-prevention)
6. [Database Constraint & Integrity Tests (SQL-Level)](#6-database-constraint--integrity-tests-sql-level)
7. [Activity 4: Access Control & Privileges Test Suite](#7-activity-4-access-control--privileges-test-suite)
8. [Activity 5: Query Performance & Maintenance Tests](#8-activity-5-query-performance--maintenance-tests)
9. [Activity 6: Backup, Restore & Recovery Simulation Tests](#9-activity-6-backup-restore--recovery-simulation-tests)

---

## 1. Quick Sanity & Environment Setup

Before running tests, verify your local environment is correctly configured:

```powershell
# 1. Verify PHP version (8.2+) and PostgreSQL extensions
php -v
php -m | Select-String "pgsql"
# Expected output: pdo_pgsql, pgsql

# 2. Check that the PostgreSQL database exists and has seed data
& "D:\Postgre\bin\psql.exe" -U postgres -h localhost -p 5432 -d grp07_campussafedb -c "\i 'E:/programming project/Data Ad/database/verify.sql'"

# 3. Start the local development server from the project root
Set-Location "E:\programming project\Data Ad"
php -S localhost:8000 -t public
```

Open your browser to: **[http://localhost:8000](http://localhost:8000)**

---

## 2. Demo Credentials Quick Reference

All demonstration accounts use the uniform password: **`Password123!`**

| User Role | Username | Email | Key Capabilities Tested |
|---|---|---|---|
| **Administrator** | `demo_admin` | `admin@campussafe.edu` | Full oversight: verification queue, technician dispatch, master data CRUD, stats |
| **Maintenance Lead** | `demo_maint1` | `davis@campussafe.edu` | Work order queue, inspection, repair logging, marking hazard resolved |
| **Maintenance Tech** | `demo_maint2` | `reyes@campussafe.edu` | Secondary technician for assignment testing |
| **Student Reporter** | `demo_student` | `santos@campussafe.edu` | File reports, upload photos, view own reports, edit pending reports |
| **Faculty Reporter** | `demo_faculty` | `hernandez@campussafe.edu` | Submit academic building hazards |
| **Safety Auditor** | `demo_auditor` | `kim@campussafe.edu` | Read-only compliance auditing, incident registry, safety analytics |

*(Tip: On `/login.php`, you can click any of the 4 quick-login buttons to auto-populate credentials).*

---

## 3. End-to-End Role-Based Walkthroughs

### Workflow Walkthrough: From Incident to Resolution
Test the complete 6-stage lifecycle using different user accounts:

```
[Student] Files Report ➔ [Admin] Verifies & Prioritizes ➔ [Admin] Dispatches Technician ➔ [Technician] Resolves ➔ [Admin] Closes
```

#### Step 1: Submit a Hazard Report (Student / Reporter)
1. Go to `http://localhost:8000/login.php` and click **🎓 Student Reporter** &rarr; click **Sign In**.
2. Click **+ Submit Hazard** in the navbar.
3. Fill out the submission form:
   - **Category:** `Electrical Hazard`
   - **Location:** `Central Library - Periodicals Wing`
   - **Description:** `"Flickering fluorescent ballast emitting burning plastic smell and sparking intermittently."`
   - **Attachment:** Choose a `.jpg` or `.png` photo (optional).
4. Click **Submit Report**.
5. **Verification:**
   - Confirm green alert appears: `"Hazard report #... has been submitted successfully"`.
   - Status badge shows: **`SUBMITTED`** (amber).
   - Priority badge shows: **`Pending Verification`** (gray italic).
   - Check the Audit Trail at the bottom: 1 event recorded (`Submitted`).

---

#### Step 2: Verify & Prioritize the Hazard (Administrator)
1. Log out and sign in as **👑 Administrator** (`demo_admin`).
2. In the navbar, click **Verify Queue** (`/admin/verify.php`).
3. Find the newly submitted report and click **Verify & Prioritize**.
4. In the verification panel:
   - **Classification Priority:** Select **`High`**.
   - **Assessment Notes:** `"Verified on-site: immediate electrical fire hazard risk. Scheduled for urgent technician dispatch."`
5. Click **Confirm Verification & Proceed to Assignment**.
6. **Verification:**
   - The report status transitions to **`VERIFIED`** (cyan).
   - Priority badge updates to **`HIGH`** (orange).
   - The system automatically forwards you to the Assignment dispatch page.

---

#### Step 3: Dispatch Maintenance Technician (Administrator)
1. On the **Dispatch Technician** page (`/admin/assign.php`):
   - **Available Technician:** Select `🔧 Alex Davis (demo_maint1)`.
   - **Work Order Instructions:** `"Replace ballast, isolate circuit breaker 4B, and verify voltage before restoring power."`
2. Click **Dispatch Work Order**.
3. **Verification:**
   - Confirm report status transitions to **`ASSIGNED`** (blue).
   - Assigned technician name shows: `Alex Davis`.
   - Audit trail appends event: `"Assigned to Alex Davis"`.

---

#### Step 4: Accept Dispatch & Execute Work (Maintenance Technician)
1. Log out and sign in as **🔧 Maintenance** (`demo_maint1`).
2. In the navbar, click **My Work Queue** (`/maintenance/index.php`).
3. Locate the newly assigned work order in the table.
4. Click **Start Work**.
   - Confirm status changes to **`IN PROGRESS`** (purple).
5. Click **Update / Resolve &rarr;** (`/maintenance/update.php`).
6. In the maintenance action form:
   - **Work Done:** `"De-energized panel 4B. Replaced defective ballast with certified Osram 2x32W ballast. Verified load at 120V with zero heating."`
   - **Equipment Used:** `"Osram Electronic Ballast model QHE 2x32T8/UNV"`.
   - Check the box: ☑ **Hazard Fully Resolved & Safe for Campus Use**.
7. Click **Submit Maintenance Log**.
8. **Verification:**
   - Report status transitions to **`RESOLVED`** (green).
   - `resolved_at` timestamp is officially stamped.
   - Assignment status marks as **`Completed`**.

---

#### Step 5: Safety Audit & Final Closure (Administrator)
1. Sign back in as **👑 Administrator** (`demo_admin`).
2. Go to **All Reports** (`/reports/list.php`) &rarr; Filter by `Status: Resolved` &rarr; Click **Inspect**.
3. In the Admin Actions panel at the bottom:
   - **Closure Notes:** `"Post-repair inspection passed. Area declared safe for library staff."`
   - Click **Officially Close Hazard Report**.
4. **Verification:**
   - Report status changes to **`CLOSED`** (slate gray).
   - The full chronological audit trail displays all 5 lifecycle transitions with author timestamps.

---

## 4. Feature-by-Feature CRUD Testing Matrix

| Test ID | Module / Feature | Test Steps | Expected Output | Status |
|---|---|---|---|---|
| **AUTH-01** | User Authentication | Login with valid username `demo_admin` and `Password123!` | Successfully authenticates, regenerates session ID, redirects to dashboard. | PASS |
| **AUTH-02** | Invalid Credentials | Attempt login with invalid password `WrongPassword!` | Displays error: *"Invalid username or password"*, denies access. | PASS |
| **AUTH-03** | Inactive User Block | Set user status to `inactive` in DB, attempt sign-in | Displays error: *"This account has been deactivated"*, rejects login. | PASS |
| **AUTH-04** | Session Logout | Click **Sign Out** from any authenticated screen | Session destroyed, session cookie cleared, redirects to `/login.php`. | PASS |
| **REP-01** | Report Filing | Fill category, location, and description (>10 chars) | Report inserted, initial history row created in atomic transaction. | PASS |
| **REP-02** | Validation Defense | Attempt report filing with empty description | Blocked by HTML5 and server-side validation; displays alert. | PASS |
| **REP-03** | Photo Attachment | Upload a `.png` file (< 5MB) during report creation | File saved under `uploads/` with randomized name; metadata logged. | PASS |
| **REP-04** | Pending Edit | Student edits own report while still in `Submitted` status | Allows update of category, location, and description. | PASS |
| **REP-05** | Locked Edit | Attempt to edit report after it has transitioned to `Verified` | System blocks edit: *"Reports in Verified status cannot be edited."* | PASS |
| **ADM-01** | Verification Queue | Admin classifies report with priority `Critical` | Updates `priority`, `verified_by_user_id`, and `verified_at` simultaneously. | PASS |
| **ADM-02** | Technician Dispatch | Admin assigns report to `demo_maint1` | Inserts into `assignment`, updates report to `Assigned`, appends history. | PASS |
| **ADM-03** | Duplicate Assignment | Admin attempts to assign the same technician twice | Handled gracefully via `ON CONFLICT (report_id, maintenance_user_id)`. | PASS |
| **MNT-01** | Technician Queue | Technician views assigned jobs | Technician only sees work orders assigned to their `user_id`. | PASS |
| **MNT-02** | Action Logging | Technician records interim repair notes without resolving | Action saved with `is_resolution = FALSE`; report remains `In Progress`. | PASS |
| **MNT-03** | Resolution Stamp | Technician checks *"Hazard Fully Resolved"* | Inserts action (`is_resolution=TRUE`), stamps `resolved_at`, status &rarr; `Resolved`. | PASS |
| **MST-01** | Category Create | Admin adds new category *"Chemical Hazard"* | Category created and immediately appears in reporting dropdown. | PASS |
| **MST-02** | Category Soft-Delete | Admin deactivates category (`is_active = FALSE`) | Hidden from report dropdown; past reports linked to it remain intact. | PASS |
| **MST-03** | Location CRUD | Admin creates and edits a campus building/floor | Saved in `campus_location`; available in reporting dropdown. | PASS |
| **MST-04** | User CRUD | Admin creates a user with role `Maintenance` | Password hashed with bcrypt; user can sign in and receive dispatches. | PASS |
| **FLT-01** | Multi-Criteria Search | Filter reports by Status, Category, and Keyword | SQL dynamically appends parameterized predicates; returns accurate subset. | PASS |
| **STA-01** | Analytics Dashboard | Visit `/admin/stats.php` | Visual KPI cards, status progress bars, and category metrics match DB counts. | PASS |

---

## 5. Security & Negative Test Cases (Exploitation Prevention)

Run these negative tests to verify that security controls cannot be bypassed:

### SEC-01: Cross-Site Request Forgery (CSRF) Protection
1. Open DevTools (`F12`) &rarr; Elements tab.
2. Inspect the form on `/reports/new.php` or `/login.php`.
3. Locate `<input type="hidden" name="csrf_token" value="...">`.
4. Tamper with the token value (e.g. change to `bad_token_12345`).
5. Submit the form.
6. **Expected Result:** Immediate **HTTP 403 Forbidden** page stating *"Invalid or expired CSRF security token."*

---

### SEC-02: Role-Based Authorization Bypass (Privilege Escalation)
1. Sign in as **🎓 Student Reporter** (`demo_student`).
2. Manually enter administrative URLs in your browser bar:
   - `http://localhost:8000/admin/users.php`
   - `http://localhost:8000/admin/categories.php`
   - `http://localhost:8000/admin/stats.php`
3. **Expected Result:** Execution terminates with **HTTP 403 Forbidden**:
   > *"You do not have administrative privilege to access this module. Your current role is Student."*

---

### SEC-03: Data Access Isolation (Student Self-Service)
1. While logged in as `demo_student`, navigate to **All Reports** (`/reports/list.php`).
2. **Expected Result:** The student sees **only their own submitted reports**. Reports submitted by other users are filtered out at the SQL query level (`WHERE r.reporter_user_id = :reporter_id`).

---

### SEC-04: Malicious File Upload Rejection
1. Create a dummy file named `exploit.php.jpg` containing `<?php phpinfo(); ?>`.
2. Attempt to upload this file during report submission.
3. **Expected Result:** PHP's `finfo(FILEINFO_MIME_TYPE)` inspects the binary content, detects that it is `text/x-php` rather than an image, and throws:
   > *"Invalid file type (text/x-php). Allowed types: JPG, PNG, WEBP, and PDF."*

---

### SEC-05: Cross-Site Scripting (XSS) Sanitization
1. Submit a report with a description containing HTML and JavaScript:
   ```html
   <script>alert('XSS-Vulnerable');</script><b>Test Bold</b>
   ```
2. Navigate to the view page (`/reports/view.php?id=...`).
3. **Expected Result:** The script does **not** execute. The raw tags are safely escaped as `&lt;script&gt;` via `e()` helper function.

---

## 6. Database Constraint & Integrity Tests (SQL-Level)

Execute these tests directly in `psql` to prove that PostgreSQL constraints enforce business rules independently of application code:

```bash
psql -U postgres -h localhost -p 5432 -d grp07_campussafedb
```

### Test DB-01: Enforcing Verification Pair (`chk_verified_pair`)
Attempt to set a verifier without setting a verification timestamp:
```sql
INSERT INTO hazard_report (reporter_user_id, location_id, category_id, description, status, verified_by_user_id, verified_at)
VALUES (4, 1, 1, 'Bad verification test', 'Verified', 1, NULL);
```
*Expected Output:*
```text
ERROR: new row for relation "hazard_report" violates check constraint "chk_verified_pair"
```

---

### Test DB-02: Enforcing Resolution Timestamp (`chk_resolved_has_date`)
Attempt to mark a report `Resolved` without supplying a `resolved_at` date:
```sql
INSERT INTO hazard_report (reporter_user_id, location_id, category_id, description, status, resolved_at)
VALUES (4, 1, 1, 'Missing resolution date test', 'Resolved', NULL);
```
*Expected Output:*
```text
ERROR: new row for relation "hazard_report" violates check constraint "chk_resolved_has_date"
```

---

### Test DB-03: Preventing Duplicate Technician Assignments
Attempt to assign the same technician to the same report twice:
```sql
INSERT INTO assignment (report_id, maintenance_user_id, assigned_by_user_id, assignment_status)
VALUES (1, 2, 1, 'Assigned');

-- Second identical assignment:
INSERT INTO assignment (report_id, maintenance_user_id, assigned_by_user_id, assignment_status)
VALUES (1, 2, 1, 'Assigned');
```
*Expected Output:*
```text
ERROR: duplicate key value violates unique constraint "assignment_report_id_maintenance_user_id_key"
```

---

## 7. Activity 4: Access Control & Privileges Test Suite

Run these tests in `psql` using the least-privilege accounts created by `database/03_roles_and_privileges.sql`:

### Test ACT4-01: Runtime Account Can SELECT & INSERT (Allowed)
```sql
\c grp07_campussafedb campussafe_app
SELECT COUNT(*) FROM hazard_report;
INSERT INTO report_status_history (report_id, changed_by_user_id, status, notes)
VALUES (1, 1, 'Submitted', 'Activity 4 permission test');
```
*Expected Result:* Both statements succeed.

---

### Test ACT4-02: Runtime Account CANNOT Delete Reports (Denied)
```sql
\c grp07_campussafedb campussafe_app
DELETE FROM hazard_report WHERE report_id = 1;
```
*Expected Result:*
```text
ERROR: permission denied for table hazard_report
```

---

### Test ACT4-03: Auditor Account CANNOT Read User Passwords (Denied)
```sql
\c grp07_campussafedb campussafe_report
SELECT user_id, username, password_hash FROM app_user;
```
*Expected Result:*
```text
ERROR: permission denied for table app_user
```

---

## 8. Activity 5: Query Performance & Maintenance Tests

### Test ACT5-01: Query Plan Analysis (`EXPLAIN ANALYZE`)
Run `EXPLAIN (ANALYZE, BUFFERS)` on the main filtered reporting query:
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT r.report_id, c.category_name, l.building, r.status
FROM hazard_report r
JOIN hazard_category c ON c.category_id = r.category_id
JOIN campus_location l ON l.location_id = r.location_id
WHERE r.status = 'In Progress';
```
*Verification Check:* Look for index usage (`idx_report_status`, `idx_report_category`, `idx_report_location`) and confirm execution time is under 5ms.

---

### Test ACT5-02: Table Maintenance
Run standard maintenance commands without `VACUUM FULL`:
```sql
ANALYZE;
VACUUM (VERBOSE, ANALYZE) public.hazard_report;
```
*Verification Check:* Confirms dead tuples are cleaned and table statistics are updated for the PostgreSQL query planner.

---

## 9. Activity 6: Backup, Restore & Recovery Simulation Tests

Execute logical backup and restoration using PostgreSQL CLI tools:

```powershell
# 1. Create a logical custom-format backup
& "D:\Postgre\bin\pg_dump.exe" -U postgres -h localhost -p 5432 -Fc -d grp07_campussafedb -f "grp07_campussafedb_activity6.dump"

# 2. Verify SHA-256 Checksum and size
Get-FileHash grp07_campussafedb_activity6.dump -Algorithm SHA256

# 3. Inspect dump archive table of contents
& "D:\Postgre\bin\pg_restore.exe" --list "grp07_campussafedb_activity6.dump"

# 4. Restore into an isolated fresh test database
& "D:\Postgre\bin\createdb.exe" -U postgres -h localhost -p 5432 grp07_campussafedb_restore_test
& "D:\Postgre\bin\pg_restore.exe" -U postgres -h localhost -p 5432 -d grp07_campussafedb_restore_test "grp07_campussafedb_activity6.dump"

# 5. Verify restored database has identical row count
& "D:\Postgre\bin\psql.exe" -U postgres -h localhost -p 5432 -d grp07_campussafedb_restore_test -c "SELECT count(*) FROM hazard_report;"
```
*Expected Output:* Row count matches original database exactly (16 reports from seed data).
