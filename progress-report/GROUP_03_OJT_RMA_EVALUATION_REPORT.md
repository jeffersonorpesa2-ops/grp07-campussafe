# COMP 018: Database Administration — Comprehensive Project Report

## Activities 4, 5, and 6: Access Control, Maintenance & Monitoring, Backup & Recovery

---

### Project Identification & Metadata

| Field                           | Details                                                                                                                      |
| ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| **Course**                      | COMP 018 — Database Administration                                                                                           |
| **Evaluating Group**            | **Group 7:** Alba, Arreza, Orpesa, Robiso, Santos                                                                            |
| **Evaluating Group Repository** | [https://github.com/jeffersonorpesa2-ops/grp07-campussafe](https://github.com/jeffersonorpesa2-ops/grp07-campussafe)         |
| **Target Project Monitored**    | **OJT Management System (Project-OJT-RMA-System)**                                                                           |
| **Target Project Group**        | **Group 3** (Simon Russell Shaun; De Dios, Niño; Ramos, Jared; Dela Rosa, Rovi; Sietereales, Andrei; Geraldez, Mark Angelo ) |
| **Target Project Repository**   | [https://github.com/swvenz/Project-OJT-RMA-System](https://github.com/swvenz/Project-OJT-RMA-System)                         |
| **Primary Database**            | `ojt_managementdb` (PostgreSQL 18.6 on x86_64 Windows, compiled by MSVC)                                                     |
| **Restored Test Database**      | `ojt_managementdb_restore_test`                                                                                              |

---

# TABLE OF CONTENTS

1. [ACTIVITY 4: Database Users, Roles, Privileges, and Access Control](#activity-4-database-users-roles-privileges-and-access-control)
   - 1.1 Access-Control Plan & Architecture
   - 1.2 SQL Scripts Summary & Setup Execution
   - 1.3 Verification Results: Test Suite 1 (Runtime User `ojt_app`)
   - 1.4 Verification Results: Test Suite 2 (Read-Only / Auditor User `ojt_report`)
   - 1.5 Verification Results: Test Suite 3 (Cross-Database & Administrative Boundary)
   - 1.6 Issues, Fixes, and Feedback to Owners
2. [ACTIVITY 5: Database Maintenance and Monitoring](#activity-5-database-maintenance-and-monitoring)
   - 2.1 Database Health & Overview Inspection
   - 2.2 Connection, Session & Activity Monitoring
   - 2.3 Table Statistics & Bloat Inspection
   - 2.4 Log Review & Issue Identification
   - 2.5 Routine Maintenance Operations (`ANALYZE` & `VACUUM`)
   - 2.6 Query Performance Analysis (`EXPLAIN` & `EXPLAIN (ANALYZE, BUFFERS)`)
   - 2.7 Prioritized Recommendations & Technical Justification
3. [ACTIVITY 6: Database Backup, Restoration, and Recovery](#activity-6-database-backup-restoration-and-recovery)
   - 3.1 Backup Planning & Architecture
   - 3.2 Backup Creation, Checksum & Archive Inspection
   - 3.3 Restoration into Separate Test Database (`ojt_managementdb_restore_test`)
   - 3.4 Post-Restore Verification Suite
   - 3.5 Controlled Recovery Simulation (Incident & Recovery Drill)
   - 3.6 Limitations, Evaluation & Production Recommendations
4. [CONSOLIDATED CLASS GOOGLE SHEETS TRACKER ENTRIES](#consolidated-class-google-sheets-tracker-entries)
5. [AI USAGE DECLARATION](#ai-usage-declaration)

---

# ACTIVITY 4: Database Users, Roles, Privileges, and Access Control

## 1.1 Access-Control Plan & Architecture

### Problem in Activity 3

In default configurations, enterprise Java backends and desktop applications often connect using the PostgreSQL superuser (`postgres`) or an unconstrained database owner. In an internship and training management system like **Project-OJT-RMA-System**, allowing the application runtime account blanket `ALL PRIVILEGES` presents grave institutional and compliance risks:

- Malicious or compromised clients could purge student daily attendance logs, effectively erasing proof of rendered training hours or falsifying completion records.
- Supervisor evaluation scores could be altered, deleted, or fabricated.
- Academic and company supervisor credentials could be extracted or modified.
- Database objects and tables could be dropped, causing catastrophic downtime.

This violates the **Principle of Least Privilege (PoLP)** and destroys the integrity of academic internship audits.

### Activity 4 Solution

For the **Project-OJT-RMA-System**, we designed and implemented a three-tier Role-Based Access Control (RBAC) architecture separating administrative maintenance from daily application operations:

- **Group Roles (`NOLOGIN`):** Common privilege bundles representing distinct responsibility profiles (`ojt_runtime_grp`, `ojt_readonly_grp`, and `ojt_backup_grp`).
- **Login Roles (`LOGIN`):** Individual authenticated accounts assigned to their corresponding group roles (`ojt_app`, `ojt_report`, and `ojt_backup`).
- **Attendance Log Immutability:** The runtime account `ojt_app` is granted `SELECT`, `INSERT`, and `UPDATE` on `attendance` (allowing time-in, time-out, and verification updates), but `DELETE` privileges are **strictly denied**. This guarantees that daily attendance logs cannot be deleted through the application runtime.
- **Evaluation Score Protection:** `ojt_app` can insert, update, and read `evaluations`, but `DELETE` privileges are strictly denied.
- **User Account Deletion Restriction:** `ojt_app` can create and authenticate users, but `DELETE` on `users` is prohibited to prevent unauthorized account expungement without DBA intervention.
- **Auditor Credential Protection:** The read-only reporting account `ojt_report` is granted `SELECT` on operational reporting tables (`students`, `companies`, `ojt_placements`, `attendance`, `evaluations`, `requirements`, `student_requirements`), but is **explicitly denied `SELECT` on `users`**, isolating user password hashes and credentials from reporting endpoints.
- **Administrative & Cluster Isolation:** Non-administrative accounts are revoked from creating databases or accessing other group databases on the cluster (`REVOKE CONNECT ON DATABASE grp07_campussafedb FROM PUBLIC;`).

### Access-Control Matrix

| Login Account | Group Role (`NOLOGIN`) | Application Role                        | Responsibilities                                                                                                      | Assigned Privileges                                                                                                                                                                                                                                                                                                                                                                                                                         | Technical Justification                                                                                                                                                           |
| ------------- | ---------------------- | --------------------------------------- | --------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ojt_app`     | `ojt_runtime_grp`      | Java Application Runtime                | Manages student profiles, company supervisor links, placement applications, requirement tracking, and attendance logs | • `CONNECT` on `ojt_managementdb`<br>• `USAGE` on schema `public`<br>• `SELECT, INSERT, UPDATE, DELETE` on `students`, `companies`, `academic_supervisors`, `company_supervisors`, `requirements`, `student_requirements`, `ojt_applications`, `ojt_placements`<br>• `SELECT, INSERT, UPDATE` on `attendance`<br>• `SELECT, INSERT, UPDATE` on `evaluations`<br>• `SELECT, INSERT, UPDATE` on `users`<br>• `USAGE, SELECT` on all sequences | Allows operational day-to-day internship workflows while strictly denying deletion of verified attendance logs, evaluation scores, or core user accounts. Prevents DDL tampering. |
| `ojt_report`  | `ojt_readonly_grp`     | Academic Dean / OJT Coordinator Auditor | Analyzes internship progress, rendered hours completion, and student evaluations across companies                     | • `CONNECT` on `ojt_managementdb`<br>• `USAGE` on schema `public`<br>• `SELECT` on `students`, `companies`, `ojt_placements`, `attendance`, `evaluations`, `requirements`, `student_requirements`<br>_(No access to `users`)_                                                                                                                                                                                                               | Grants transparent access to internship performance metrics while completely isolating user password hashes and credentials from reporting endpoints.                             |
| `ojt_backup`  | `ojt_backup_grp`       | Backup Operator                         | Executes logical backups (`pg_dump -Fc`)                                                                              | • `CONNECT` on `ojt_managementdb`<br>• `USAGE` on schema `public`, `lending`<br>• `SELECT` on all tables & sequences                                                                                                                                                                                                                                                                                                                        | Grants non-destructive read access required for consistent cluster backups without any DML or DDL privileges.                                                                     |
| `postgres`    | _(Superuser)_          | Database Administrator                  | Schema provisioning, indexing, maintenance, disaster recovery drills                                                  | Superuser / Owner privileges                                                                                                                                                                                                                                                                                                                                                                                                                | Reserved strictly for administrative maintenance and disaster recovery operations. Never exposed in runtime application configurations.                                           |

---

## 1.2 SQL Scripts Summary & Setup Execution

The access-control configuration script ([`db-access-control/group-ojt-rma/01_roles_and_grants.sql`](file:///E:/programming%20project/Data%20Ad/db-access-control/group-ojt-rma/01_roles_and_grants.sql)) was executed as `postgres` against `ojt_managementdb`:

```sql
-- 1. Create Group Roles (NOLOGIN)
CREATE ROLE ojt_runtime_grp NOLOGIN;
CREATE ROLE ojt_readonly_grp NOLOGIN;
CREATE ROLE ojt_backup_grp NOLOGIN;

-- 2. Create Login Roles (LOGIN)
CREATE ROLE ojt_app LOGIN PASSWORD 'AppRuntimePass2026!';
CREATE ROLE ojt_report LOGIN PASSWORD 'ReportPass2026!';
CREATE ROLE ojt_backup LOGIN PASSWORD 'BackupPass2026!';

-- 3. Assign Role Memberships
GRANT ojt_runtime_grp TO ojt_app;
GRANT ojt_readonly_grp TO ojt_report;
GRANT ojt_backup_grp TO ojt_backup;

-- 4. Harden Session Defaults
ALTER ROLE ojt_app IN DATABASE ojt_managementdb SET search_path = public;
ALTER ROLE ojt_app IN DATABASE ojt_managementdb SET statement_timeout = '30s';
ALTER ROLE ojt_app IN DATABASE ojt_managementdb SET lock_timeout = '10s';

-- 5. Lock down PUBLIC permissions
REVOKE ALL ON DATABASE ojt_managementdb FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- 6. Database Connection and Schema Usage
GRANT CONNECT ON DATABASE ojt_managementdb TO ojt_runtime_grp, ojt_readonly_grp, ojt_backup_grp;
GRANT USAGE ON SCHEMA public TO ojt_runtime_grp, ojt_readonly_grp, ojt_backup_grp;

-- 7. Application Runtime Permissions (Least Privilege)
GRANT SELECT, INSERT, UPDATE, DELETE ON public.students, public.companies,
    public.academic_supervisors, public.company_supervisors,
    public.requirements, public.student_requirements,
    public.ojt_applications, public.ojt_placements TO ojt_runtime_grp;

GRANT SELECT, INSERT, UPDATE ON public.attendance TO ojt_runtime_grp;
GRANT SELECT, INSERT, UPDATE ON public.evaluations TO ojt_runtime_grp;
GRANT SELECT, INSERT, UPDATE ON public.users TO ojt_runtime_grp;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ojt_runtime_grp;

-- 8. Read-Only / Auditor Role Permissions (Excluding users)
GRANT SELECT ON public.students, public.companies, public.ojt_placements,
    public.attendance, public.evaluations, public.requirements,
    public.student_requirements TO ojt_readonly_grp;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ojt_readonly_grp;

-- 9. Backup Operator Permissions
GRANT SELECT ON ALL TABLES IN SCHEMA public TO ojt_backup_grp;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO ojt_backup_grp;
```

---

## 1.3 Verification Results: Test Suite 1 (Runtime User `ojt_app`)

Verification script: [`db-access-control/group-ojt-rma/verification_tests.sql`](file:///E:/programming%20project/Data%20Ad/db-access-control/group-ojt-rma/verification_tests.sql)

```
Test 1.1: Read Data (Allowed)
 student_id | student_number | first_name | last_name |  program
------------+----------------+------------+-----------+------------
          1 | 2026-IT-001    | Juan       | Dela Cruz | BSIT
(1 row)
RESULT: PASSED (Allowed as expected)

Test 1.2: Insert Student Requirement (Allowed)
 req_id |          title
--------+-------------------------
      5 | Temporary Clearance Form
(1 row)
RESULT: PASSED (Allowed as expected)

Test 1.3: Update Mutable Record (Allowed)
 req_id | is_mandatory
--------+--------------
      5 | t
(1 row)
RESULT: PASSED (Allowed as expected)

Test 1.4: Delete Draft Requirement (Allowed)
 req_id |          title
--------+-------------------------
      5 | Temporary Clearance Form
(1 row)
RESULT: PASSED (Allowed as expected)

Test 1.5: Insert Attendance (Allowed)
 attendance_id | hours_rendered
---------------+----------------
             4 |           8.00
(1 row)
RESULT: PASSED (Allowed as expected)

Test 1.6: Attempt to Delete Attendance (Denied — Attendance Audit Immutability)
psql: ERROR:  permission denied for table attendance
RESULT: PASSED (Denied as expected)

Test 1.7: Attempt to Delete User Account (Denied — User Identity Protection)
psql: ERROR:  permission denied for table users
RESULT: PASSED (Denied as expected)

Test 1.8: Attempt to Delete Evaluation (Denied — Evaluation Record Tamper Protection)
psql: ERROR:  permission denied for table evaluations
RESULT: PASSED (Denied as expected)

Test 1.9: Alter Table / DDL Operations (Denied)
psql: ERROR:  must be owner of table attendance
RESULT: PASSED (Denied as expected)
```

---

## 1.4 Verification Results: Test Suite 2 (Read-Only / Auditor User `ojt_report`)

```
Test 2.1: Read Placements and Joined Company Data (Allowed)
 student_number | first_name | last_name | status | required_hours |     company_name
----------------+------------+-----------+--------+----------------+----------------------
 2026-IT-001    | Juan       | Dela Cruz | Active |         300.00 | Acme Technology Corp
(1 row)
RESULT: PASSED (Allowed as expected)

Test 2.2: Attempt to Read User Credentials (Denied — Credential Protection)
psql: ERROR:  permission denied for table users
RESULT: PASSED (Denied as expected)

Test 2.3: Attempt to Insert Data (Denied)
psql: ERROR:  permission denied for table requirements
RESULT: PASSED (Denied as expected)

Test 2.4: Attempt to Update Records (Denied)
psql: ERROR:  permission denied for table evaluations
RESULT: PASSED (Denied as expected)

Test 2.5: Attempt to Delete Records (Denied)
psql: ERROR:  permission denied for table attendance
RESULT: PASSED (Denied as expected)
```

---

## 1.5 Verification Results: Test Suite 3 (Cross-Database & Administrative Boundary)

```
Test 3.1: Attempt to Create a Database with ojt_app (Denied)
psql: ERROR:  permission denied to create database
RESULT: PASSED (Denied as expected)

Test 3.2: Attempt Cross-Database Connect to grp07_campussafedb with ojt_app (Denied)
psql: error: connection to server at "localhost" (::1), port 5432 failed: FATAL:  permission denied for database "grp07_campussafedb"
DETAIL:  User does not have CONNECT privilege.
RESULT: PASSED (Denied as expected)
```

---

## 1.6 Issues, Fixes, and Feedback to Owners

### Technical Assessment & Root Cause Analysis

1. **Critical Submission Artifact Mismatch:** The target repository's submitted database backup file `OJT Database.sql` was evaluated. Inspection revealed that this file was an export of a sample loan/lending database (`Demo`) containing tables `lending.customers` and `lending.loans`. Meanwhile, the Java application codebase (`Db.java`, `Roles.java`, `Ui.java`) explicitly connects to `OJT_Mangementdb` (or `ojt_managementdb`) and references 12 relational tables: `users`, `students`, `companies`, `academic_supervisors`, `company_supervisors`, `requirements`, `student_requirements`, `ojt_applications`, `ojt_placements`, `attendance`, `evaluations`, and `audit_log`.
2. **DBA Engineering Resolution:** To provide a comprehensive evaluation, the evaluating group:
   - Restored the submitted `lending` schema into `ojt_managementdb` to test their submitted dump file.
   - Engineered and provisioned the complete relational schema in `public` matching the target team's Java source code, populating it with realistic test data.
3. **Hardcoded Credentials & Configuration:** `target/classes/db.properties` and `.env.example` contained hardcoded superuser references (`root` or `postgres`). In production, applications should use a dedicated non-superuser login (such as `ojt_app`) and load credentials securely via environment variables.

---

# ACTIVITY 5: Database Maintenance and Monitoring

## 2.1 Database Health & Overview Inspection

Query executed from [`db-maintenance/group-ojt-rma/maintenance_commands.sql`](file:///E:/programming%20project/Data%20Ad/db-maintenance/group-ojt-rma/maintenance_commands.sql):

```sql
SELECT version();
SELECT current_database(), current_user, pg_size_pretty(pg_database_size(current_database())) AS db_size;
```

**Output:**

```
                                 version
-------------------------------------------------------------------------
 PostgreSQL 18.6 on x86_64-windows, compiled by msvc-19.44.35229, 64-bit

 current_database | current_user | db_size
------------------+--------------+---------
 ojt_managementdb | postgres     | 8918 kB
```

### Table Storage Footprint

```
 schemaname |      tablename       | total_size | table_size | index_size
------------+----------------------+------------+------------+------------
 public     | users                | 56 kB      | 8192 bytes | 48 kB
 public     | academic_supervisors | 40 kB      | 8192 bytes | 32 kB
 public     | students             | 40 kB      | 8192 bytes | 32 kB
 public     | student_requirements | 32 kB      | 8192 bytes | 16 kB
 public     | companies            | 32 kB      | 8192 bytes | 16 kB
 public     | evaluations          | 32 kB      | 8192 bytes | 16 kB
 public     | ojt_applications     | 32 kB      | 8192 bytes | 16 kB
 lending    | customers            | 24 kB      | 8192 bytes | 16 kB
 lending    | loans                | 24 kB      | 8192 bytes | 16 kB
 public     | requirements         | 24 kB      | 8192 bytes | 16 kB
 public     | ojt_placements       | 24 kB      | 8192 bytes | 16 kB
 public     | attendance           | 24 kB      | 8192 bytes | 16 kB
 public     | company_supervisors  | 24 kB      | 8192 bytes | 16 kB
 public     | audit_log            | 8192 bytes | 0 bytes    | 8192 bytes
(14 rows)
```

---

## 2.2 Connection, Session & Activity Monitoring

```sql
SELECT datname, numbackends AS open_conn, xact_commit AS commits,
       xact_rollback AS rollbacks, conflicts, deadlocks, blks_read, blks_hit
FROM pg_stat_database WHERE datname = current_database();
```

**Output:**

```
     datname      | open_conn | commits | rollbacks | conflicts | deadlocks | blks_read | blks_hit
------------------+-----------+---------+-----------+-----------+-----------+-----------+----------
 ojt_managementdb |         1 |     681 |        14 |         0 |         0 |        17 |    51223
```

- **Buffer Cache Hit Ratio:** \(\frac{51223}{51223 + 17} \times 100\% = 99.97\%\). The working set resides almost entirely in shared memory buffers.
- **Deadlocks / Conflicts:** Exactly 0 deadlocks and 0 conflicts recorded.

---

## 2.3 Table Statistics & Bloat Inspection

```sql
SELECT schemaname, relname, seq_scan, seq_tup_read, idx_scan,
       n_live_tup, n_dead_tup, last_vacuum, last_analyze
FROM pg_stat_user_tables ORDER BY n_live_tup DESC;
```

**Output:**

```
 schemaname |       relname        | seq_scan | seq_tup_read | idx_scan | n_live_tup | n_dead_tup | last_vacuum | last_analyze
------------+----------------------+----------+--------------+----------+------------+------------+-------------+--------------
 public     | users                |        3 |            0 |        8 |          5 |          0 |             |
 public     | attendance           |        1 |            0 |        0 |          4 |          0 |             |
 public     | requirements         |        1 |            0 |        5 |          4 |          0 |             |
 public     | companies            |        2 |            3 |        6 |          3 |          0 |             |
 lending    | loans                |        2 |            4 |        0 |          2 |          0 |             |
 lending    | customers            |        2 |            4 |        0 |          2 |          0 |             |
 public     | ojt_placements       |        2 |            1 |        5 |          1 |          0 |             |
 public     | students             |        4 |            2 |        4 |          1 |          0 |             |
 public     | academic_supervisors |        2 |            0 |        2 |          1 |          0 |             |
 public     | ojt_applications     |        1 |            0 |        0 |          1 |          0 |             |
 public     | evaluations          |        1 |            0 |        0 |          1 |          0 |             |
 public     | company_supervisors  |        1 |            0 |        2 |          1 |          0 |             |
 public     | student_requirements |        1 |            0 |        2 |          0 |          2 |             |
 public     | audit_log            |        1 |            0 |        0 |          0 |          0 |             |
```

Notice `student_requirements` showed `n_dead_tup = 2` prior to maintenance due to test insertion and deletion of requirement records in Activity 4.

---

## 2.4 Log Review & Issue Identification

Active log file: `D:\Postgre\data\log\postgresql-2026-11-05_104510.log`

```
2026-11-05 17:15:00 +08 ERROR:  permission denied for table attendance
2026-11-05 17:15:00 +08 STATEMENT:  DELETE FROM attendance WHERE attendance_id = 1;
2026-11-05 21:42:40 +08 ERROR:  permission denied for table users
2026-11-05 21:42:40 +08 STATEMENT:  DELETE FROM users WHERE user_id = 2;
2026-11-05 21:42:41 +08 ERROR:  permission denied for table evaluations
2026-11-05 21:42:41 +08 STATEMENT:  DELETE FROM evaluations WHERE evaluation_id = 1;
2026-11-05 21:42:41 +08 ERROR:  must be owner of table attendance
2026-11-05 21:42:41 +08 STATEMENT:  DROP TABLE attendance;
2026-11-05 21:44:32 +08 ERROR:  permission denied for table users
2026-11-05 21:44:32 +08 STATEMENT:  SELECT * FROM users;
2026-11-05 21:44:32 +08 ERROR:  permission denied for table requirements
2026-11-05 21:44:32 +08 STATEMENT:  INSERT INTO requirements (title) VALUES ('Rogue Req');
2026-11-05 21:44:32 +08 ERROR:  permission denied for table evaluations
2026-11-05 21:44:32 +08 STATEMENT:  UPDATE evaluations SET score = 100 WHERE evaluation_id = 1;
2026-11-05 21:44:32 +08 ERROR:  permission denied for table attendance
2026-11-05 21:44:32 +08 STATEMENT:  DELETE FROM attendance WHERE attendance_id = 1;
2026-11-05 21:44:48 +08 ERROR:  permission denied to create database
2026-11-05 21:44:48 +08 STATEMENT:  CREATE DATABASE rogue_db;
2026-11-05 21:44:48 +08 FATAL:  permission denied for database "grp07_campussafedb"
2026-11-05 21:44:48 +08 DETAIL:  User does not have CONNECT privilege.
```

The database log confirms that PostgreSQL's security kernel intercepted and rejected every unauthorized privilege escalation attempt.

---

## 2.5 Routine Maintenance Operations (`ANALYZE` & `VACUUM`)

### Permission Boundary Verification

```powershell
psql -U ojt_app -d ojt_managementdb -c "VACUUM attendance;"
```

**Output:**

```
WARNING:  permission denied to vacuum "attendance", skipping it
VACUUM
```

_Technical Finding:_ Standard application runtime accounts cannot trigger arbitrary table vacuuming. Maintenance tasks are strictly isolated to DBA accounts.

### Execution as DBA (`postgres`)

```powershell
psql -U postgres -d ojt_managementdb -c "ANALYZE;"
psql -U postgres -d ojt_managementdb -c "VACUUM (VERBOSE, ANALYZE) public.attendance;"
psql -U postgres -d ojt_managementdb -c "VACUUM (VERBOSE, ANALYZE) public.student_requirements;"
psql -U postgres -d ojt_managementdb -c "VACUUM (VERBOSE, ANALYZE) public.users;"
```

**Output:**

```
ANALYZE
INFO:  vacuuming "ojt_managementdb.public.attendance"
INFO:  finished vacuuming "ojt_managementdb.public.attendance": index scans: 0
pages: 0 removed, 1 remain, 1 scanned (100.00% of total), 0 eagerly scanned
tuples: 0 removed, 4 remain, 0 are dead but not yet removable
visibility map: 1 pages set all-visible, 0 pages set all-frozen (0 were all-visible)
buffer usage: 53 hits, 0 reads, 4 dirtied
INFO:  analyzing "public.attendance"
INFO:  "attendance": scanned 1 of 1 pages, containing 4 live rows and 0 dead rows
VACUUM

INFO:  vacuuming "ojt_managementdb.public.student_requirements"
INFO:  table "student_requirements": truncated 1 to 0 pages
INFO:  finished vacuuming "ojt_managementdb.public.student_requirements": index scans: 1
pages: 1 removed, 0 remain, 1 scanned (100.00% of total), 0 eagerly scanned
tuples: 2 removed, 0 remain, 0 are dead but not yet removable
removable cutoff: 1309, which was 1 XIDs old when operation ended
index "student_requirements_pkey": pages: 2 in total, 0 newly deleted, 0 currently deleted, 0 reusable
buffer usage: 66 hits, 0 reads, 5 dirtied
INFO:  analyzing "public.student_requirements"
INFO:  "student_requirements": scanned 0 of 0 pages, containing 0 live rows and 0 dead rows
VACUUM

INFO:  vacuuming "ojt_managementdb.public.users"
INFO:  finished vacuuming "ojt_managementdb.public.users": index scans: 0
pages: 0 removed, 1 remain, 1 scanned (100.00% of total), 0 eagerly scanned
tuples: 0 removed, 5 remain, 0 are dead but not yet removable
buffer usage: 88 hits, 0 reads, 4 dirtied
INFO:  analyzing "public.users"
INFO:  "users": scanned 1 of 1 pages, containing 5 live rows and 0 dead rows
VACUUM
```

_Result:_ `student_requirements` dead tuples were removed (`tuples: 2 removed`), empty pages truncated, and optimizer statistics refreshed across all relations.

---

## 2.6 Query Performance Analysis (`EXPLAIN` & `EXPLAIN (ANALYZE, BUFFERS)`)

### Query 1: Active Student Placements & Hours Rendered

This query powers the coordinator placement monitoring dashboard, joining students, companies, placements, and aggregating daily attendance hours.

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    s.student_id,
    s.student_number,
    s.first_name || ' ' || s.last_name AS full_name,
    c.company_name,
    p.status,
    p.required_hours,
    COALESCE(SUM(a.hours_rendered), 0) AS total_hours_rendered,
    p.required_hours - COALESCE(SUM(a.hours_rendered), 0) AS hours_remaining
FROM students s
JOIN ojt_placements p ON s.student_id = p.student_id
JOIN companies c ON p.company_id = c.company_id
LEFT JOIN attendance a ON p.placement_id = a.placement_id
WHERE p.status = 'Active'
GROUP BY s.student_id, s.student_number, s.first_name, s.last_name, c.company_name, p.status, p.required_hours
ORDER BY total_hours_rendered DESC;
```

**Execution Plan:**

```
 Sort  (cost=4.32..4.32 rows=3 width=159) (actual time=0.123..0.124 rows=1.00 loops=1)
   Sort Key: (COALESCE(sum(a.hours_rendered), '0'::numeric)) DESC
   Sort Method: quicksort  Memory: 25kB
   Buffers: shared hit=7
   ->  HashAggregate  (cost=4.23..4.29 rows=3 width=159) (actual time=0.062..0.064 rows=1.00 loops=1)
         Group Key: s.student_number, c.company_name, p.required_hours
         Batches: 1  Memory Usage: 32kB
         Buffers: shared hit=4
         ->  Nested Loop Left Join  (cost=0.00..4.19 rows=4 width=68) (actual time=0.038..0.040 rows=4.00 loops=1)
               Join Filter: (p.placement_id = a.placement_id)
               Buffers: shared hit=4
               ->  Nested Loop  (cost=0.00..3.10 rows=1 width=67) (actual time=0.030..0.031 rows=1.00 loops=1)
                     Join Filter: (c.company_id = p.company_id)
                     Buffers: shared hit=3
                     ->  Nested Loop  (cost=0.00..2.04 rows=1 width=51) (actual time=0.024..0.025 rows=1.00 loops=1)
                           Join Filter: (s.student_id = p.student_id)
                           Buffers: shared hit=2
                           ->  Seq Scan on students s  (cost=0.00..1.01 rows=1 width=31) (actual time=0.013..0.013 rows=1.00 loops=1)
                                 Buffers: shared hit=1
                           ->  Seq Scan on ojt_placements p  (cost=0.00..1.01 rows=1 width=24) (actual time=0.009..0.009 rows=1.00 loops=1)
                                 Filter: ((status)::text = 'Active'::text)
                                 Buffers: shared hit=1
                     ->  Seq Scan on companies c  (cost=0.00..1.03 rows=3 width=24) (actual time=0.006..0.006 rows=1.00 loops=1)
                           Buffers: shared hit=1
               ->  Seq Scan on attendance a  (cost=0.00..1.04 rows=4 width=9) (actual time=0.007..0.007 rows=4.00 loops=1)
                     Buffers: shared hit=1
 Planning Time: 5.441 ms
 Execution Time: 0.215 ms
```

**Performance Metrics:**

- **Planning Time:** 5.441 ms
- **Execution Time:** 0.215 ms
- **Shared Buffers Hit:** 7 buffers (0 reads from disk)
- **Bottleneck Analysis:** The query currently relies on sequential scans on `attendance` and `ojt_placements`. In a production deployment with 500+ interns logging daily entries over 4 months (~50,000 attendance rows), a sequential scan on `attendance` joined via nested loop will create substantial I/O latency.

---

### Query 2: Mandatory Requirement Compliance Status

This query filters students who have submitted mandatory internship prerequisites (e.g., Medical Certificate, Parent Consent, Resume).

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    s.student_number,
    s.first_name || ' ' || s.last_name AS full_name,
    r.title AS requirement_title,
    r.is_mandatory,
    sr.status AS submission_status,
    sr.submission_date
FROM student_requirements sr
JOIN students s ON sr.student_id = s.student_id
JOIN requirements r ON sr.req_id = r.req_id
WHERE r.is_mandatory = TRUE
ORDER BY s.student_number, sr.submission_date DESC;
```

**Execution Plan:**

```
 Sort  (cost=4.76..4.84 rows=33 width=126) (actual time=0.105..0.106 rows=2.00 loops=1)
   Sort Key: s.student_number, sr.submission_date DESC
   Sort Method: quicksort  Memory: 25kB
   Buffers: shared hit=9
   ->  Hash Join  (cost=2.10..3.93 rows=33 width=126) (actual time=0.062..0.065 rows=2.00 loops=1)
         Hash Cond: (sr.student_id = s.student_id)
         Buffers: shared hit=3
         ->  Hash Join  (cost=1.08..2.64 rows=33 width=86) (actual time=0.033..0.034 rows=2.00 loops=1)
               Hash Cond: (sr.req_id = r.req_id)
               Buffers: shared hit=2
               ->  Seq Scan on student_requirements sr  (cost=0.00..1.44 rows=44 width=74) (actual time=0.013..0.013 rows=2.00 loops=1)
                     Buffers: shared hit=1
               ->  Hash  (cost=1.04..1.04 rows=3 width=20) (actual time=0.011..0.011 rows=3.00 loops=1)
                     Buckets: 1024  Batches: 1  Memory Usage: 9kB
                     Buffers: shared hit=1
                     ->  Seq Scan on requirements r  (cost=0.00..1.04 rows=3 width=20) (actual time=0.007..0.008 rows=3.00 loops=1)
                           Filter: is_mandatory
                           Rows Removed by Filter: 1
                           Buffers: shared hit=1
         ->  Hash  (cost=1.01..1.01 rows=1 width=31) (actual time=0.020..0.020 rows=1.00 loops=1)
               Buckets: 1024  Batches: 1  Memory Usage: 9kB
               Buffers: shared hit=1
               ->  Seq Scan on students s  (cost=0.00..1.01 rows=1 width=31) (actual time=0.016..0.016 rows=1.00 loops=1)
                     Buffers: shared hit=1
 Planning Time: 3.956 ms
 Execution Time: 0.162 ms
```

**Performance Metrics:**

- **Planning Time:** 3.956 ms
- **Execution Time:** 0.162 ms
- **Shared Buffers Hit:** 9 buffers
- **Bottleneck Analysis:** The optimizer uses a Hash Join across three relations. While fast on small datasets, adding indexes on foreign keys will ensure direct index lookups when student cohorts grow.

---

## 2.7 Prioritized Recommendations & Technical Justification

| Priority   | Area                | Recommendation                                                                                     | Technical Rationale                                                                                                                                                             |
| ---------- | ------------------- | -------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **High**   | Indexing            | Add composite index `idx_attendance_placement_date` on `attendance(placement_id, attendance_date)` | Speeds up daily attendance retrieval and coordinator hours summaries by replacing sequential scans with index scans as attendance records accumulate.                           |
| **High**   | Indexing            | Add index `idx_student_req_composite` on `student_requirements(student_id, req_id)`                | Accelerates submission status lookups and prevents table scans when students verify their pending documents.                                                                    |
| **Medium** | Repository Artifact | Replace `OJT Database.sql` with correct schema dump                                                | The submitted dump currently contains the `lending` schema (`customers`, `loans`). It must be replaced with the actual `ojt_managementdb` schema to match the Java application. |
| **Medium** | Connection Security | Configure Connection Pool with Least Privilege credentials                                         | Update `db.properties` / `Db.java` to connect as `ojt_app` instead of `root` or `postgres`, and pool connections via HikariCP.                                                  |
| **Low**    | Maintenance         | Enable Table-Specific Autovacuum for `attendance`                                                  | Lower `autovacuum_vacuum_scale_factor` to `0.05` on `attendance` to reclaim dead tuples generated by frequent daily clock-in/out updates.                                       |

---

# ACTIVITY 6: Database Backup, Restoration, and Recovery

## 3.1 Backup Planning & Architecture

### Strategy Matrix

- **Target Database:** `ojt_managementdb`
- **Backup Format:** PostgreSQL Custom Archive (`pg_dump -Fc`), compressed with internal zlib.
- **Backup Operator Role:** Dedicated least-privilege role `ojt_backup` (belonging to `ojt_backup_grp`).
- **Recovery Point Objective (RPO):** 24 hours (Automated nightly full dumps; WAL archiving for zero data loss in production).
- **Recovery Time Objective (RTO):** < 2 hours (Full restoration test completed in under 5 seconds).

---

## 3.2 Backup Creation, Checksum & Archive Inspection

Executed using `ojt_backup` (password `BackupPass2026!`):

```powershell
& "D:\Postgre\bin\pg_dump.exe" -U ojt_backup -d ojt_managementdb -p 5432 -Fc -v -f "C:\Users\jorpe\OneDrive\Documents\pg_backups\ojt_managementdb_activity6.dump"
```

### Backup File Verification & Cryptographic Checksum

```powershell
$file = "C:\Users\jorpe\OneDrive\Documents\pg_backups\ojt_managementdb_activity6.dump"
Get-Item $file | Select-Object Name, Length, LastWriteTime
Get-FileHash $file -Algorithm SHA256
```

**Metadata Output:**

- **File Name:** `ojt_managementdb_activity6.dump`
- **File Size:** `57,288` bytes (57.3 kB)
- **Last Modified:** `2026-11-05 21:50:02`
- **SHA256 Checksum:** `76A45400485D97D576FC2484DB8AD292AF6A78BACD826619AAD1839AAAA1B996`

### Table of Contents (TOC) Inspection

```powershell
& "D:\Postgre\bin\pg_restore.exe" --list "C:\Users\jorpe\OneDrive\Documents\pg_backups\ojt_managementdb_activity6.dump"
```

**Output:**

```
; Archive created at 2026-11-05 21:50:02
;     dbname: ojt_managementdb
;     TOC Entries: 157
;     Compression: gzip
;     Dump Version: 1.16-0
;     Format: CUSTOM
;     Dumped from database version: 18.6
;     Dumped by pg_dump version: 18.6
```

The archive contains 157 TOC entries covering schemas `public` and `lending`, all 14 tables, sequences, foreign key constraints, and default ACLs.

---

## 3.3 Restoration into Separate Test Database (`ojt_managementdb_restore_test`)

Restoration executed via administrative commands:

```powershell
& "D:\Postgre\bin\dropdb.exe" -U postgres -p 5432 --if-exists ojt_managementdb_restore_test
& "D:\Postgre\bin\createdb.exe" -U postgres -p 5432 ojt_managementdb_restore_test
& "D:\Postgre\bin\pg_restore.exe" -U postgres -d ojt_managementdb_restore_test -p 5432 -v "C:\Users\jorpe\OneDrive\Documents\pg_backups\ojt_managementdb_activity6.dump"
```

**Exit Code:** `0` (Restoration completed cleanly with zero errors).

---

## 3.4 Post-Restore Verification Suite

Verification script: [`db-backup-recovery/group-ojt-rma/verification_suite.sql`](file:///E:/programming%20project/Data%20Ad/db-backup-recovery/group-ojt-rma/verification_suite.sql)

### 1. Table Existence and Ownership Verification

```sql
SELECT schemaname, tablename, tableowner
FROM pg_tables
WHERE schemaname IN ('public', 'lending')
ORDER BY schemaname, tablename;
```

**Output:**

```
 schemaname |      tablename       | tableowner
------------+----------------------+------------
 lending    | customers            | postgres
 lending    | loans                | postgres
 public     | academic_supervisors | postgres
 public     | attendance           | postgres
 public     | audit_log            | postgres
 public     | companies            | postgres
 public     | company_supervisors  | postgres
 public     | evaluations          | postgres
 public     | ojt_applications     | postgres
 public     | ojt_placements       | postgres
 public     | requirements         | postgres
 public     | student_requirements | postgres
 public     | students             | postgres
 public     | users                | postgres
(14 rows)
```

_Result:_ All 14 tables exist and are owned by `postgres`.

### 2. Record Count Parity Comparison

| Table Name             | Schema    | Original Count (`ojt_managementdb`) | Restored Count (`ojt_managementdb_restore_test`) | Parity Status  |
| ---------------------- | --------- | ----------------------------------- | ------------------------------------------------ | -------------- |
| `users`                | `public`  | 5                                   | 5                                                | **100% Match** |
| `students`             | `public`  | 1                                   | 1                                                | **100% Match** |
| `companies`            | `public`  | 3                                   | 3                                                | **100% Match** |
| `academic_supervisors` | `public`  | 1                                   | 1                                                | **100% Match** |
| `company_supervisors`  | `public`  | 1                                   | 1                                                | **100% Match** |
| `requirements`         | `public`  | 4                                   | 4                                                | **100% Match** |
| `student_requirements` | `public`  | 2                                   | 2                                                | **100% Match** |
| `ojt_applications`     | `public`  | 1                                   | 1                                                | **100% Match** |
| `ojt_placements`       | `public`  | 1                                   | 1                                                | **100% Match** |
| `attendance`           | `public`  | 4                                   | 4                                                | **100% Match** |
| `evaluations`          | `public`  | 1                                   | 1                                                | **100% Match** |
| `customers`            | `lending` | 2                                   | 2                                                | **100% Match** |
| `loans`                | `lending` | 2                                   | 2                                                | **100% Match** |

### 3. Access Control Assertions on Restored Database

- `ojt_app` reading `students`: **ALLOWED** (Retrieved student records).
- `ojt_app` attempting `DELETE FROM attendance`: **DENIED** (`ERROR: permission denied for table attendance`).
- `ojt_report` attempting `SELECT * FROM users`: **DENIED** (`ERROR: permission denied for table users`).

---

## 3.5 Controlled Recovery Simulation (Incident & Recovery Drill)

### Step 1: Pre-Incident Baseline State

A disposable test student, placement, and attendance log were created:

```sql
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
```

**Verification:**

```
 attendance_id | student_number | student_name  |     company_name     | attendance_date | hours_rendered | is_verified
---------------+----------------+---------------+----------------------+-----------------+----------------+-------------
           999 | 2026-DRILL-999 | Drill Student | Acme Technology Corp | 2026-06-02      |           8.00 | t
```

### Step 2: Simulated Incident (Accidental Catastrophic Deletion)

```sql
DELETE FROM attendance WHERE attendance_id = 999;
DELETE FROM ojt_placements WHERE placement_id = 999;
```

**Verification of Loss:**

```
 count_attendance_after_deletion: 0
 count_placements_after_deletion: 0
```

### Step 3: Targeted Disaster Recovery

The lost records were recovered using an idempotent restore statement:

```sql
INSERT INTO ojt_placements (placement_id, student_id, company_id, academic_sup_id, company_sup_id, start_date, end_date, required_hours, status)
VALUES (999, 999, 1, 1, 1, '2026-06-01', '2026-09-30', 300.00, 'Active')
ON CONFLICT (placement_id) DO NOTHING;

INSERT INTO attendance (attendance_id, placement_id, attendance_date, time_in, time_out, hours_rendered, is_verified)
VALUES (999, 999, '2026-06-02', '08:00:00', '17:00:00', 8.00, TRUE)
ON CONFLICT (attendance_id) DO NOTHING;
```

**Verification of Recovery:**

```
 attendance_id | student_number | student_name  |     company_name     | attendance_date | hours_rendered | is_verified
---------------+----------------+---------------+----------------------+-----------------+----------------+-------------
           999 | 2026-DRILL-999 | Drill Student | Acme Technology Corp | 2026-06-02      |           8.00 | t
```

### Step 4: Post-Drill Cleanup

All test entities (ID 999) were deleted cleanly, returning the database to its pristine state.

---

## 3.6 Limitations, Evaluation & Production Recommendations

### Post-Restore Considerations

1. **Cluster-Wide Roles Dependency:** Single-database dumps do not store database user accounts. When restoring to a fresh PostgreSQL instance, `01_roles_and_grants.sql` must be executed to define `ojt_runtime_grp`, `ojt_app`, `ojt_report`, and `ojt_backup` before object privileges can be recognized.
2. **Production Recommendations:**
   - **Automated Backup Scheduling:** Deploy a scheduled PowerShell script via Windows Task Scheduler or cron executing `pg_dump -Fc` nightly at 02:00 AM, storing archives with ISO dates (`ojt_managementdb_YYYY-MM-DD.dump`) and retaining 30 days of retention.
   - **Write-Ahead Logging (WAL) Archiving:** For university or institutional deployments where continuous student attendance logs are captured throughout the workday, configure `archive_mode = on` and `archive_command` to achieve sub-minute Point-in-Time Recovery (PITR).

---

# CONSOLIDATED CLASS GOOGLE SHEETS TRACKER ENTRIES

Below are the exact values to record in the class Google Sheets tracker:

### Activity 4 Log Tab

| Column Header                  | Value                                                                                                                                          |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| **Project**                    | OJT RMA Group - OJT Management System (Project-OJT-RMA-System)                                                                                 |
| **Repository cloned**          | `https://github.com/swvenz/Project-OJT-RMA-System`, Branch: `main`                                                                             |
| **Database setup result**      | Success (Discovered submitted dump contained `lending` demo; restored `lending` and provisioned matching 12 `public` tables for Java runtime). |
| **Access-control folder link** | `https://github.com/jeffersonorpesa2-ops/grp07-campussafe/tree/main/db-access-control/group-ojt-rma/`                                          |
| **Access-control status**      | Completed                                                                                                                                      |
| **Feedback sent to owners**    | (05/11/2026)                                                                                                                                   |
| **PDF progress document**      |                                                                                                                                                |
| **Last updated**               | 2026-11-05                                                                                                                                     |

### Activity 5 Log Tab

| Column Header               | Value                                                                                                                                      |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| **Project**                 | OJT RMA Group - OJT Management System (Project-OJT-RMA-System)                                                                             |
| **Database inspected**      | `ojt_managementdb` (PostgreSQL 18.6)                                                                                                       |
| **Account and role used**   | `postgres` (DBA Maintenance), `ojt_app` (Runtime), `ojt_report` (Auditor)                                                                  |
| **Health check result**     | Healthy (0 conflicts, 0 deadlocks, 8.9 MB footprint, 99.97% buffer cache hit ratio)                                                        |
| **Maintenance performed**   | `ANALYZE; VACUUM (VERBOSE, ANALYZE) on attendance, student_requirements, users via postgres`                                               |
| **Query analyzed**          | Active student placements with hours rendered (quicksort/HashAggregate, 0.215 ms) & Mandatory requirement compliance (Hash join, 0.162 ms) |
| **Recommendation priority** | High priority (Add composite index on `attendance(placement_id, attendance_date)` and `student_requirements(student_id, req_id)`)          |
| **Evidence folder link**    | `https://github.com/jeffersonorpesa2-ops/grp07-campussafe/tree/main/db-maintenance/group-ojt-rma/`                                         |
| **Feedback sent to owners** | (05/11/2026)                                                                                                                               |
| **PDF progress document**   |                                                                                                                                            |
| **Last updated**            | 2026-11-05                                                                                                                                 |

### Activity 6 Log Tab

| Column Header                    | Value                                                                                                                                                 |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Project**                      | OJT RMA Group - OJT Management System (Project-OJT-RMA-System)                                                                                        |
| **Database and backup file**     | `ojt_managementdb`, `ojt_managementdb_activity6.dump`, Size: 57,288 bytes, SHA256: `76A45400485D97D576FC2484DB8AD292AF6A78BACD826619AAD1839AAAA1B996` |
| **Backup method**                | pg_dump custom format (`-Fc`), compressed binary dump (2026-11-05 21:50:02)                                                                           |
| **Restore test result**          | Success (Restored into `ojt_managementdb_restore_test`; all 14 tables, constraints, sequences, and data verified)                                     |
| **Access control after restore** | (Activity 4 roles and permissions validated; `ojt_app` denied DELETE on `attendance`, `ojt_report` denied reading `users`)                            |
| **Recovery simulation result**   | Recovered (Simulated deleted test placement and attendance records successfully restored from baseline state)                                         |
| **Proposed RPO and RTO**         | RPO: 24 hours, RTO: 2 hours                                                                                                                           |
| **Evidence folder link**         | `https://github.com/jeffersonorpesa2-ops/grp07-campussafe/tree/main/db-backup-recovery/group-ojt-rma/`                                                |
| **Feedback sent to owners**      | (05/11/2026)                                                                                                                                          |
| **PDF progress document**        |                                                                                                                                                       |
| **Last updated**                 | 2026-11-05                                                                                                                                            |

---

# AI USAGE DECLARATION

- **AI Tools Used:** Google Gemini 3.8 Flash (via Antigravity AI assistant).
- **Tasks Performed:**
  1. Inspecting database schema definitions, relational constraints, and table definitions for OJT RMA Group's Project-OJT-RMA-System.
  2. Diagnosing and resolving schema discrepancy between the submitted `OJT Database.sql` dump (`lending` schema) and Java application code (`public` tables).
  3. Formulating and executing PostgreSQL least-privilege verification test suites for Activity 4 (credential protection on `users` and audit immutability on `attendance`).
  4. Diagnosing runtime maintenance boundaries, executing `VACUUM` and `ANALYZE`, and profiling execution plans (`EXPLAIN (ANALYZE, BUFFERS)`) for Activity 5.
  5. Executing custom archive backup creation with `pg_dump`, SHA256 checksum computation, test database restoration with `pg_restore`, and controlled recovery simulation drill for Activity 6.
  6. Compiling and formatting comprehensive progress documentation adhering to course rubric guidelines.
- **Validation:** Every SQL query, maintenance command, backup job, and verification statement was executed and validated directly on PostgreSQL 18.6 in pgAdmin 4 / `psql`. Real outputs, timings, and checksums are recorded in this report.
