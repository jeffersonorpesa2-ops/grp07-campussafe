# CampusSafe: How Does It Work?

**System:** CampusSafe: Campus Hazard & Safety Reporting System  
**Course:** COMP 018 Database Administration &bull; Group 7  
**Technology Stack:** HTML5 / CSS3 / JavaScript &rarr; PHP 8.2 &rarr; PostgreSQL 14+  

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Architectural Blueprint & Layered Design](#2-architectural-blueprint--layered-design)
3. [The 6-Stage Hazard Lifecycle & State Machine](#3-the-6-stage-hazard-lifecycle--state-machine)
4. [Database Relational Integrity & Constraint Engine](#4-database-relational-integrity--constraint-engine)
5. [Security Architecture & Defense-in-Depth](#5-security-architecture--defense-in-depth)
6. [Role-Based Access Control: Application vs. Database Roles](#6-role-based-access-control-application-vs-database-roles)
7. [Step-by-Step Code Walkthrough](#7-step-by-step-code-walkthrough)
8. [Database Administration Operations (Activities 4, 5, 6)](#8-database-administration-operations-activities-4-5-6)
9. [Demonstration & Evaluation Walkthrough](#9-demonstration--evaluation-walkthrough)

---

## 1. Executive Summary

**CampusSafe** is an enterprise-grade web application engineered to solve the real-world operational challenges of managing physical safety hazards across a university campus.

In large institutions, hazards (such as exposed electrical cables, ceiling water leaks, broken stair handrails, blocked fire escapes, or broken air conditioning units) are often reported haphazardly via email, text, or word-of-mouth. This results in lost requests, zero accountability, unprioritized maintenance work, and no audit trail.

CampusSafe centralizes this entire process:
- **Reporters (Students and Faculty):** Instantly submit hazard reports from any browser, tag the exact building, floor, and room, describe the hazard, and upload photographic evidence.
- **Safety Administrators:** Review incoming reports, assess the severity, classify them into standardized priorities (`Low`, `Medium`, `High`, `Critical`), and dispatch them to qualified maintenance personnel.
- **Maintenance Technicians:** Receive dispatched work orders, inspect the site, log progress notes, and officially mark hazards as resolved once repairs are complete.
- **Safety Auditors:** Access an immutable audit history and analytical dashboards to measure resolution times, campus hotspot locations, and compliance metrics.

---

## 2. Architectural Blueprint & Layered Design

CampusSafe is built upon a hardened **MVC-Lite (Model-View-Controller)** architecture designed for maximum auditability, high performance, and zero dependency overhead.

```
                      ┌────────────────────────────────────────┐
                      │          Web Browser (Client)          │
                      └───────────────────┬────────────────────┘
                                          │
                                          │ HTTP / HTTPS (Port 8000)
                                          ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ PUBLIC WEB ROOT (`public/`)                                                            │
│                                                                                        │
│   ├── index.php             (Portal Dashboard & Landing Page)                          │
│   ├── install.php           (1-Click Web Installer & Auto-Configuration Wizard)        │
│   ├── login.php / logout.php(User Authentication & Fast Demo Switcher)                 │
│   ├── attachment.php        (Protected Evidence Viewer & Proxy Streamer)               │
│   ├── reports/              (new.php, list.php, view.php, edit.php)                    │
│   ├── admin/                (verify.php, assign.php, users.php, master data, stats)    │
│   ├── maintenance/          (index.php, assigned.php, update.php)                      │
│   └── assets/               (Custom CSS styling, client-side JS interactivity)         │
└────────────────────────────────────────┬───────────────────────────────────────────────┘
                                         │
                                         ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ PROTECTED ENGINE (`src/`) [Inaccessible directly from the browser]                    │
│                                                                                        │
│   ├── config/   ──> Env.php (.env parser), Database.php (PDO Connection Singleton)     │
│   ├── auth/     ──> Auth.php (Session RBAC Engine), Csrf.php (Security Token Validator) │
│   ├── models/   ──> Report, User, Assignment, MaintenanceAction, Attachment, Location  │
│   └── helpers/  ──> functions.php (XSS Escaping, Flash Alerts, File Upload Processing)  │
└────────────────────────────────────────┬───────────────────────────────────────────────┘
                                         │
                                         │ Parameterized Prepared Statements (PDO)
                                         │ Connected as 'campussafe_app' (Least Privilege)
                                         ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ POSTGRESQL 14+ DATABASE (`grp07_campussafedb`)                                         │
│                                                                                        │
│   ├── 9 Relational Tables with Foreign Keys & ON DELETE CASCADE Rules                  │
│   ├── Strict Database Constraints (CHECK, UNIQUE, NOT NULL)                            │
│   └── Strategic Query Performance Indexes                                              │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### Why This Directory Separation Matters:
1. **Security Isolation:** Only files inside the `public/` directory are exposed to the web server (`php -S localhost:8000 -t public`). Sensitive backend logic (`src/`), environment configuration (`.env`), database migration scripts (`database/`), and documentation (`docs/`) are located outside the document root and cannot be downloaded by unauthorized web requests.
2. **Clean Separation of Concerns:** View templates never execute raw SQL. All database interactions are strictly encapsulated within domain models in `src/models/`.

---

## 3. The 6-Stage Hazard Lifecycle & State Machine

CampusSafe implements a strictly controlled 6-stage lifecycle. Each transition enforces specific business rules, modifies report attributes, and writes an entry into the immutable audit log table `report_status_history`.

```
    [ 1. Submitted ]
           │
           │ Administrator reviews and assigns priority
           ▼
    [ 2. Verified ]
           │
           │ Administrator dispatches to technician
           ▼
    [ 3. Assigned ]
           │
           │ Maintenance technician commences work
           ▼
    [ 4. In Progress ]
           │
           │ Maintenance technician completes repair & records action
           ▼
    [ 5. Resolved ]
           │
           │ Administrator conducts safety compliance audit
           ▼
    [ 6. Closed ]
```

### Transition Matrix & Database Side Effects:

| Transition | Authorized Role | What Happens in the Database (Atomic PDO Transaction) |
|---|---|---|
| **`Submitted`** *(Initial)* | Student / Faculty | 1. Inserts into `hazard_report` with `priority = NULL`, `status = 'Submitted'`.<br>2. Inserts initial history row in `report_status_history`.<br>3. Moves uploaded file to `uploads/` and inserts into `attachment`. |
| **`Submitted` &rarr; `Verified`** | Administrator | 1. Updates `hazard_report`: sets `priority` (`Low`, `Medium`, `High`, `Critical`), `verified_by_user_id = admin_id`, `verified_at = CURRENT_TIMESTAMP`, `status = 'Verified'`.<br>2. Inserts transition row in `report_status_history`. |
| **`Verified` &rarr; `Assigned`** | Administrator | 1. Enforces Business Rule 5: Report *must* be `Verified`.<br>2. Inserts into `assignment` with `assignment_status = 'Assigned'`.<br>3. Updates `hazard_report.status = 'Assigned'`.<br>4. Inserts transition row in `report_status_history`. |
| **`Assigned` &rarr; `In Progress`** | Assigned Technician | 1. Updates `assignment.assignment_status = 'In Progress'`.<br>2. Updates `hazard_report.status = 'In Progress'`.<br>3. Inserts transition row in `report_status_history`. |
| **`In Progress` &rarr; `Resolved`** | Assigned Technician | 1. Inserts repair record into `maintenance_action` with `is_resolution = TRUE`.<br>2. Enforces Business Rules 10 & 11: Updates `hazard_report.status = 'Resolved'` and sets `resolved_at = CURRENT_TIMESTAMP`.<br>3. Updates `assignment.assignment_status = 'Completed'`.<br>4. Inserts transition row in `report_status_history`. |
| **`Resolved` &rarr; `Closed`** | Administrator | 1. Validates report is currently `Resolved`.<br>2. Updates `hazard_report.status = 'Closed'`.<br>3. Inserts final audit closure row in `report_status_history`. |

---

## 4. Database Relational Integrity & Constraint Engine

A core strength of CampusSafe is that **business rules are enforced at the database level**, not merely in PHP application logic. Even if someone writes a rogue query or connects directly through `psql`, the PostgreSQL database rejects invalid states.

### 4.1 Nullable Priority (Business Rule 12)
In the original design, priority was proposed as `NOT NULL`. However, a regular student reporting a water leak should not be forced to guess the engineering risk level. 
- In our schema, `priority` is declared as **nullable**:
  ```sql
  priority VARCHAR(20) CHECK (priority IN ('Low', 'Medium', 'High', 'Critical'))
  ```
- It remains `NULL` while in `Submitted` status, and is officially established when an Administrator inspects and verifies the report.

### 4.2 The Verification Pair Constraint (`chk_verified_pair`)
A hazard report must never have a verifier recorded without a verification timestamp, or a timestamp without a verifier:
```sql
CONSTRAINT chk_verified_pair CHECK (
    (verified_by_user_id IS NULL AND verified_at IS NULL) OR
    (verified_by_user_id IS NOT NULL AND verified_at IS NOT NULL)
)
```

### 4.3 The Resolution Timestamp Constraint (`chk_resolved_has_date`)
Enforces Business Rule 10: Any report marked `Resolved` or `Closed` **must** have an explicit `resolved_at` timestamp:
```sql
CONSTRAINT chk_resolved_has_date CHECK (
    status NOT IN ('Resolved', 'Closed') OR resolved_at IS NOT NULL
)
```

### 4.4 Duplicate Assignment Prevention
A maintenance technician cannot be assigned to the same report more than once simultaneously:
```sql
UNIQUE (report_id, maintenance_user_id)
```

### 4.5 Referential Actions (`ON DELETE` Rules)
- **Cascade Deletes:** If an incident report is deleted (e.g. during test cleanup), its child records (`assignment`, `report_status_history`, `maintenance_action`, `attachment`) are automatically cascaded (`ON DELETE CASCADE`).
- **Restrict Deletes:** Deleting a user who has authored reports or performed maintenance actions is blocked by PostgreSQL foreign key references. To disable a user, administrators use **soft deactivation** (`account_status = 'inactive'`), preserving complete audit trails.

---

## 5. Security Architecture & Defense-in-Depth

CampusSafe was developed with comprehensive defensive security mechanisms:

### 5.1 SQL Injection Prevention (100% Prepared Statements)
Every database interaction in `src/models/` uses PDO prepared statements with parameterized input bindings. User input is never concatenated into SQL strings.
```php
// Example from src/models/Report.php
$stmt = $pdo->prepare("SELECT * FROM hazard_report WHERE status = :status AND category_id = :cat_id");
$stmt->execute([':status' => $status, ':cat_id' => $catId]);
```

### 5.2 Cross-Site Request Forgery (CSRF) Defense
All state-changing operations (POST requests) require a valid CSRF token generated via `Csrf::getToken()`:
1. When a form renders, `<?= Csrf::field() ?>` injects a hidden token:
   ```html
   <input type="hidden" name="csrf_token" value="64_character_hex_token">
   ```
2. When the form is submitted, `Csrf::enforce()` validates the token against `$_SESSION['csrf_token']` using constant-time string comparison (`hash_equals()`).
3. If an attacker attempts a forged cross-site request, execution immediately terminates with HTTP `403 Forbidden`.

### 5.3 Cross-Site Scripting (XSS) Prevention
All data rendered into HTML is escaped using the `e()` helper function, which applies `htmlspecialchars($string, ENT_QUOTES, 'UTF-8')`. This neutralizes any malicious `<script>` tags or HTML attributes submitted in descriptions or notes.

### 5.4 Secure Password Hashing
Passwords are never stored in plaintext. CampusSafe uses PHP's native `password_hash($password, PASSWORD_DEFAULT)`, generating cryptographically secure bcrypt hashes with unique per-user salts. Login verification is performed using `password_verify($password, $hash)`.

### 5.5 Session Fixation & Hijacking Prevention
- When a user logs in, `session_regenerate_id(true)` is immediately invoked, invalidating the old session ID and issuing a fresh cryptographic identifier.
- Sessions are configured with `cookie_httponly = 1` (prevents JavaScript access to cookies) and `cookie_samesite = 'Lax'` (restricts cross-site cookie transmission).

### 5.6 File Upload Hardening
File uploads in `src/helpers/functions.php` undergo a four-tier validation check:
1. **Size check:** Capped at 5 megabytes.
2. **Extension allowlist:** Only `.jpg`, `.png`, `.webp`, and `.pdf` are permitted.
3. **MIME type inspection:** Uses PHP's `finfo_file(FILEINFO_MIME_TYPE)` to inspect the actual binary header of the file, rejecting files that masquerade as images.
4. **Randomized storage filenames:** Files are renamed to `hazard_{random_hex}_{timestamp}.{ext}` upon upload, preventing directory traversal and filename collision attacks.

---

## 6. Role-Based Access Control: Application vs. Database Roles

A key requirement of COMP 018 is distinguishing between **Application Roles** and **Database Roles**.

```
[ Human Users ]
  ├── Students / Faculty (Reporters)
  ├── Maintenance Technicians
  └── Campus Safety Administrators
         │
         │ Authenticate with username + password via login.php
         ▼
[ Session Role Guard (`src/auth/Auth.php`) ]
  ├── Assigns application role: 'Student', 'Maintenance', 'Administrator', 'Auditor'
  ├── Enforces route protection via Auth::requireRole(...)
  └── Filters data views (e.g. Students only see their own reports)
         │
         │ Single database connection pool via PDO
         ▼
[ PostgreSQL Runtime Account (`campussafe_app`) ]
  ├── Member of group role: app_runtime_grp (NOLOGIN)
  ├── Has SELECT, INSERT, UPDATE on operational tables
  └── Narrow DELETE: Only permitted on attachment and assignment
```

### Why Don't End Users Get Individual PostgreSQL Logins?
1. **Connection Exhaustion:** PostgreSQL creates a dedicated operating system process for each connection. If thousands of campus students had individual database accounts, the server would quickly run out of memory and file descriptors.
2. **Connection Pooling:** Web applications use persistent connection pools. The application authenticates once as `campussafe_app` and multiplexes queries on behalf of authenticated users.
3. **Data Filtering:** Application logic enforces that students can only read reports where `reporter_user_id = Auth::id()`, while administrators can view all reports.

### The Role Hierarchy (Configured in `database/03_roles_and_privileges.sql`):
- `app_runtime_grp`: Used by the web application. Has full operational CRUD, but cannot delete hazard reports or drop tables.
- `app_readonly_grp` (Account: `campussafe_report`): Used by auditors. Can read reports, history, and actions, but **has no access to `app_user`**, keeping password hashes secure.
- `app_backup_grp` (Account: `campussafe_backup`): Used by backup operators. Has read-only access to all tables and sequences for `pg_dump`.

---

## 7. Step-by-Step Code Walkthrough

Let us trace what happens under the hood during the most critical operations.

### Walkthrough 1: Submitting a Hazard Report
1. A student navigates to `/reports/new.php`.
2. `Auth::requireLogin()` verifies the user is signed in.
3. The page loads active categories from `Category::getAll(true)` and locations from `Location::getAll(true)`.
4. The user fills out the form, attaches a photo, and clicks **Submit Report**.
5. `public/reports/new.php` verifies the CSRF token via `Csrf::enforce()`.
6. If a file was attached, `handleFileUpload()` validates the MIME type and saves the file to `uploads/hazard_abcdef123456_1699000000.jpg`.
7. `Report::create()` begins a PDO transaction:
   ```php
   $pdo->beginTransaction();
   // 1. Insert hazard report (status: Submitted, priority: NULL)
   // 2. Insert first status history row (status: Submitted)
   // 3. Insert attachment metadata row
   $pdo->commit();
   ```
8. The student is redirected to `/reports/view.php?id={new_id}` with a green success alert.

### Walkthrough 2: Admin Verifying and Assigning a Report
1. The Administrator logs in as `demo_admin` and visits `/admin/verify.php`.
2. The page lists all reports currently in `Submitted` status.
3. The Admin clicks **Verify & Prioritize**, selects `High`, enters assessment notes, and submits.
4. `Report::verify()` executes inside a transaction:
   - Sets `priority = 'High'`
   - Sets `status = 'Verified'`
   - Sets `verified_by_user_id = admin_id` and `verified_at = CURRENT_TIMESTAMP`
   - Inserts audit history row: `"Verified as High priority"`
5. The Admin is automatically taken to `/admin/assign.php?id={report_id}`.
6. The Admin selects a technician (e.g. `Alex Davis`), enters work order instructions, and clicks **Dispatch Work Order**.
7. `Report::assign()` executes inside a transaction:
   - Validates that the report is currently in `Verified` status
   - Creates an `assignment` row linking `report_id` to `maintenance_user_id`
   - Updates `hazard_report.status = 'Assigned'`
   - Inserts audit history row: `"Assigned to Alex Davis (Senior Tech)"`

### Walkthrough 3: Maintenance Technician Resolving the Hazard
1. Technician logs in as `demo_maint1` and clicks **My Work Orders** (`/maintenance/index.php`).
2. The technician sees the newly assigned work order, clicks **Start Work**, which updates the status to `In Progress`.
3. After completing the physical repair on-site, the technician clicks **Update / Resolve**.
4. The technician enters the repair details:
   - *Work Done:* `"Replaced damaged 30A circuit breaker with certified Eaton BR230 unit. Load tested voltage to 120V."*
   - Checks the box: ☑ **Hazard Fully Resolved & Safe for Campus Use**
5. `Report::resolve()` executes in a single atomic transaction:
   ```sql
   -- 1. Update report status and timestamp
   UPDATE hazard_report 
   SET status = 'Resolved', resolved_at = CURRENT_TIMESTAMP 
   WHERE report_id = :id;

   -- 2. Insert resolution action log
   INSERT INTO maintenance_action (report_id, maintenance_user_id, action_details, is_resolution) 
   VALUES (:id, :maint_id, :details, TRUE);

   -- 3. Mark assignment completed
   UPDATE assignment SET assignment_status = 'Completed' WHERE report_id = :id;

   -- 4. Append status history audit
   INSERT INTO report_status_history (report_id, changed_by_user_id, status, notes) 
   VALUES (:id, :maint_id, 'Resolved', 'Hazard resolved: ...');
   ```
6. The database verifies that `chk_resolved_has_date` is satisfied because `resolved_at` is set.
7. The hazard is officially remediated!

---

## 8. Database Administration Operations (Activities 4, 5, 6)

### Activity 4: Roles & Privileges
- Execute `database/03_roles_and_privileges.sql` to establish group roles (`app_runtime_grp`, `app_readonly_grp`, `app_backup_grp`) and assign permissions.
- Test allowed operations (e.g. runtime inserting into history) vs. denied operations (e.g. runtime deleting reports, auditor reading password hashes).

### Activity 5: Health & Maintenance
- **Health Queries:** Inspect database size (`pg_database_size`), active connections (`pg_stat_activity`), and cache hit ratio (`pg_stat_database`) using `db-maintenance/README.md`.
- **Query Optimization:** Run `EXPLAIN (ANALYZE, BUFFERS)` on main queries:
  ```sql
  EXPLAIN (ANALYZE, BUFFERS) 
  SELECT * FROM hazard_report WHERE status = 'Submitted' ORDER BY submitted_at DESC;
  ```
- **Maintenance:** Run `ANALYZE;` to refresh query planner statistics, followed by `VACUUM (VERBOSE, ANALYZE) public.hazard_report;` to clean dead tuples.

### Activity 6: Backup, Restore & Recovery Simulation
- **Backup:** Execute logical custom backup:
  ```bash
  pg_dump -U campussafe_backup -h localhost -p 5432 -Fc -d grp07_campussafedb -f grp07_campussafedb_activity6.dump
  ```
- **Checksum:** Calculate SHA-256 hash using `Get-FileHash grp07_campussafedb_activity6.dump -Algorithm SHA256`.
- **Restoration Test:** Provision a fresh test database `grp07_campussafedb_restore_test` and run `pg_restore`.
- **Disaster Simulation:** Insert a `TEST-RECOVERY` report, simulate catastrophic deletion, restore the backup into a secondary recovery database, and document point-in-time recovery results.

---

## 9. Demonstration & Evaluation Walkthrough

To experience the system working end-to-end:

1. **Start Server:** Run `php -S localhost:8000 -t public` from the project root.
2. **Open Portal:** Navigate to `http://localhost:8000`.
3. **Log in as Student (`demo_student`):**
   - Click **Submit Hazard** &rarr; select *Central Library*, *Electrical*, enter description, attach an image.
   - Click **Submit Report** &rarr; Notice status is `Submitted` and Priority is `Pending Verification`.
4. **Log in as Administrator (`demo_admin`):**
   - Click **Verify Queue** &rarr; Inspect the student's report &rarr; set priority to `High`.
   - The system automatically takes you to **Assignments** &rarr; assign the report to `Alex Davis (Senior Tech)`.
5. **Log in as Maintenance Lead (`demo_maint1`):**
   - Click **My Work Queue** &rarr; Click **Start Work** &rarr; Status becomes `In Progress`.
   - Click **Update / Resolve** &rarr; Enter work done &rarr; Check **Hazard Fully Resolved** &rarr; Submit.
6. **Log in as Safety Auditor (`demo_auditor`):**
   - Click **Safety Analytics** &rarr; View real-time breakdown of all statuses, categories, and resolution metrics.
   - Click **Reports Registry** &rarr; Inspect the full chronological audit trail of the report from start to finish.

**CampusSafe is fully functional, secure, and ready for deployment and evaluation!**
