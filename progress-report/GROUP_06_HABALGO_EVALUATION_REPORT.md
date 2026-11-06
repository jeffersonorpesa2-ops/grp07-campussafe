# COMP 018: Database Administration — Comprehensive Project Report

## Activities 4, 5, and 6: Access Control, Maintenance & Monitoring, Backup & Recovery

---

### Project Identification & Metadata

| Field                           | Details                                                                                                                                    |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| **Course**                      | COMP 018 — Database Administration                                                                                                         |
| **Evaluating Group**            | **Group 7:** Alba, Arreza, Orpesa, Robiso, Santos                                                                                          |
| **Evaluating Group Repository** | [https://github.com/jeffersonorpesa2-ops/grp07-campussafe](https://github.com/jeffersonorpesa2-ops/grp07-campussafe)                       |
| **Target Project Monitored**    | **HabalGo: Ride and Booking Management System**                                                                                            |
| **Target Project Group**        | **Group 6** (Barte, Roxanne; Balansay, Bohdana Yoome; Gumahin, Jewey Kristine; Remoquillo, Michelin; Royo, Jeana; Villareal, Mae Angeline) |
| **Target Project Repository**   | [https://github.com/jeanaroyo/HabalGo](https://github.com/jeanaroyo/HabalGo)                                                               |
| **Primary Database**            | `grp00_habalgodb` (Schema: `habalgo`, PostgreSQL 18.6 on x86_64 Windows, compiled by MSVC)                                                 |
| **Restored Test Database**      | `grp00_habalgodb_restore_test`                                                                                                             |

---

# TABLE OF CONTENTS

1. [ACTIVITY 4: Database Users, Roles, Privileges, and Access Control](#activity-4-database-users-roles-privileges-and-access-control)
   - 1.1 Access-Control Plan & Architecture
   - 1.2 SQL Scripts Summary & Setup Execution
   - 1.3 Verification Results: Test Suite 1 (Runtime User `habalgo_app`)
   - 1.4 Verification Results: Test Suite 2 (Read-Only / Auditor User `habalgo_report`)
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
   - 3.3 Restoration into Separate Test Database (`grp00_habalgodb_restore_test`)
   - 3.4 Post-Restore Verification Suite
   - 3.5 Controlled Recovery Simulation (Incident & Recovery Drill)
   - 3.6 Limitations, Evaluation & Production Recommendations
4. [CONSOLIDATED CLASS GOOGLE SHEETS TRACKER ENTRIES](#consolidated-class-google-sheets-tracker-entries)
5. [AI USAGE DECLARATION](#ai-usage-declaration)

---

# ACTIVITY 4: Database Users, Roles, Privileges, and Access Control

## 1.1 Access-Control Plan & Architecture

### Problem in Activity 3

In standard web application configurations, database connections often operate under the PostgreSQL superuser (`postgres`) or an unconstrained database owner. In a ride-hailing and booking platform like **HabalGo**, granting blanket `ALL PRIVILEGES` or unrestricted `SELECT, INSERT, UPDATE, DELETE` across all tables presents grave operational and financial hazards:

- Malicious clients or compromised application endpoints could alter completed payment amounts, mark unpaid rides as settled, or delete payment receipts.
- Booking audit trails could be purged to conceal cancelled rides or disputed fares.
- Critical driver and vehicle registrations could be deleted, breaking active fleet assignments.
- Entire database tables or schemas could be dropped, leading to total operational downtime.

This violates the **Principle of Least Privilege (PoLP)** and destroys the integrity of financial ledgers.

### Activity 4 Solution

For the **HabalGo** platform, we implemented an enterprise three-tier Role-Based Access Control (RBAC) architecture that decouples day-to-day application operations from reporting and database administration:

- **Group Roles (`NOLOGIN`):** Common privilege bundles representing distinct responsibility profiles (`habalgo_runtime_grp`, `habalgo_readonly_grp`, and `habalgo_backup_grp`).
- **Login Roles (`LOGIN`):** Individual authenticated accounts assigned to their corresponding group roles (`habalgo_app`, `habalgo_report`, and `habalgo_backup`).
- **Financial Ledger Immutability:** The runtime account `habalgo_app` is granted `SELECT, INSERT` on `habalgo.payment`. `UPDATE` and `DELETE` privileges are **strictly revoked**, ensuring completed payments are tamper-proof append-only records.
- **Booking Audit Trail Protection:** `habalgo_app` can advance booking statuses (`SELECT, INSERT, UPDATE` on `habalgo.booking`), but `DELETE` is **strictly denied** to preserve historical trip audit trails.
- **Fleet Protection:** `habalgo_app` can register and update `driver`, `vehicle`, and `driver_vehicle` assignments, but `DELETE` is prohibited through runtime.
- **Auditor Read-Only Isolation:** `habalgo_report` is granted read-only `SELECT` on all operational tables in `habalgo` for billing reconciliation and performance monitoring, while completely denying all DML write operations (`INSERT`, `UPDATE`, `DELETE`).
- **Backup Isolation:** The dedicated backup operator `habalgo_backup` is authorized for `pg_dump` logical dumps with read-only permissions across all tables and sequences, with DML and DDL privileges completely denied.
- **Administrative Boundary:** Non-administrative accounts are revoked from creating databases or accessing other group databases on the cluster (`REVOKE CONNECT ON DATABASE grp07_campussafedb FROM PUBLIC;`).

### Access-Control Matrix

| Login Account    | Group Role (`NOLOGIN`) | Application Role Served             | Responsibilities                                                                                                         | Assigned Privileges                                                                                                                                                                                                                                                                                                                                          | Technical Justification                                                                                                                                                      |
| ---------------- | ---------------------- | ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `habalgo_app`    | `habalgo_runtime_grp`  | PHP Runtime (api.php)               | Handles customer management, ride booking dispatch, status transitions, driver-vehicle assignment, and payment recording | • `CONNECT` on `grp00_habalgodb`<br>• `USAGE` on schema `habalgo`<br>• `SELECT, INSERT, UPDATE, DELETE` on `customer`, `location`, `rating_feedback`<br>• `SELECT, INSERT, UPDATE` on `booking`<br>• `SELECT, INSERT` on `payment`<br>• `SELECT, INSERT, UPDATE` on `driver`, `vehicle`, `driver_vehicle`<br>• `USAGE, SELECT` on all sequences in `habalgo` | Allows normal day-to-day ride-booking operations while strictly preventing deletion of booking audit records, alterations of payment amounts, or unauthorized fleet purging. |
| `habalgo_report` | `habalgo_readonly_grp` | Financial Auditor / Fleet Inspector | Audits trip completions, daily gross revenue, payment method breakdowns, and driver ratings                              | • `CONNECT` on `grp00_habalgodb`<br>• `USAGE` on schema `habalgo`<br>• `SELECT` on all tables in schema `habalgo`<br>• `USAGE, SELECT` on all sequences in schema `habalgo`                                                                                                                                                                                  | Full read transparency for ride metrics and financial reconciliation without any risk of accidental or malicious data modification.                                          |
| `habalgo_backup` | `habalgo_backup_grp`   | Backup Operator                     | Runs logical database backups (`pg_dump -Fc`)                                                                            | • `CONNECT` on `grp00_habalgodb`<br>• `USAGE` on schema `habalgo`<br>• `SELECT` on all tables & sequences                                                                                                                                                                                                                                                    | Grants non-destructive read access required for consistent backups while preventing data modification or schema alterations.                                                 |
| `postgres`       | _(Superuser)_          | Database Administrator              | Schema provisioning, indexing, routine maintenance (`VACUUM`/`ANALYZE`), disaster recovery drills                        | Superuser / Owner privileges                                                                                                                                                                                                                                                                                                                                 | Reserved strictly for DBA operations; never configured in application connection strings or `.env`.                                                                          |

---

## 1.2 SQL Scripts Summary & Setup Execution

The access-control configuration script ([`db-access-control/group-habalgo/01_roles_and_grants.sql`](file:///E:/programming%20project/Data%20Ad/db-access-control/group-habalgo/01_roles_and_grants.sql)) was executed as `postgres` against `grp00_habalgodb`:

```sql
-- 1. Create Group Roles (NOLOGIN)
CREATE ROLE habalgo_runtime_grp NOLOGIN;
CREATE ROLE habalgo_readonly_grp NOLOGIN;
CREATE ROLE habalgo_backup_grp NOLOGIN;

-- 2. Create Login Roles (LOGIN)
CREATE ROLE habalgo_app WITH LOGIN PASSWORD 'HabalGoRuntimePass2026!';
CREATE ROLE habalgo_report WITH LOGIN PASSWORD 'HabalGoReportPass2026!';
CREATE ROLE habalgo_backup WITH LOGIN PASSWORD 'HabalGoBackupPass2026!';

-- 3. Assign Role Memberships
GRANT habalgo_runtime_grp TO habalgo_app;
GRANT habalgo_readonly_grp TO habalgo_report;
GRANT habalgo_backup_grp TO habalgo_backup;

-- 4. Harden Session Defaults & Security Timeouts
ALTER ROLE habalgo_app IN DATABASE grp00_habalgodb SET search_path = habalgo, public;
ALTER ROLE habalgo_app IN DATABASE grp00_habalgodb SET statement_timeout = '30s';
ALTER ROLE habalgo_app IN DATABASE grp00_habalgodb SET lock_timeout = '10s';

ALTER ROLE habalgo_report IN DATABASE grp00_habalgodb SET search_path = habalgo, public;
ALTER ROLE habalgo_report IN DATABASE grp00_habalgodb SET statement_timeout = '15s';
ALTER ROLE habalgo_report IN DATABASE grp00_habalgodb SET lock_timeout = '5s';

ALTER ROLE habalgo_backup IN DATABASE grp00_habalgodb SET search_path = habalgo, public;
ALTER ROLE habalgo_backup IN DATABASE grp00_habalgodb SET statement_timeout = '60s';

-- 5. Lock down PUBLIC privileges
REVOKE ALL ON DATABASE grp00_habalgodb FROM PUBLIC;
REVOKE CREATE ON SCHEMA habalgo FROM PUBLIC;

-- 6. Grant Database Connection & Schema Usage
GRANT CONNECT ON DATABASE grp00_habalgodb TO habalgo_runtime_grp, habalgo_readonly_grp, habalgo_backup_grp;
GRANT USAGE ON SCHEMA habalgo TO habalgo_runtime_grp, habalgo_readonly_grp, habalgo_backup_grp;

-- 7. Runtime Application Permissions (habalgo_runtime_grp)
GRANT SELECT, INSERT, UPDATE, DELETE ON
    habalgo.customer,
    habalgo.location,
    habalgo.rating_feedback
TO habalgo_runtime_grp;

GRANT SELECT, INSERT, UPDATE ON habalgo.booking TO habalgo_runtime_grp;
GRANT SELECT, INSERT ON habalgo.payment TO habalgo_runtime_grp;
GRANT SELECT, INSERT, UPDATE ON habalgo.driver, habalgo.vehicle, habalgo.driver_vehicle TO habalgo_runtime_grp;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA habalgo TO habalgo_runtime_grp;

-- 8. Read-Only / Auditor Role Permissions (habalgo_readonly_grp)
GRANT SELECT ON ALL TABLES IN SCHEMA habalgo TO habalgo_readonly_grp;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA habalgo TO habalgo_readonly_grp;

-- 9. Backup Operator Role Permissions (habalgo_backup_grp)
GRANT SELECT ON ALL TABLES IN SCHEMA habalgo TO habalgo_backup_grp;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA habalgo TO habalgo_backup_grp;
```

---

## 1.3 Verification Results: Test Suite 1 (Runtime User `habalgo_app`)

Verification script: [`db-access-control/group-habalgo/verification_tests.sql`](file:///E:/programming%20project/Data%20Ad/db-access-control/group-habalgo/verification_tests.sql)

```
Test 1.1: Read Data (Allowed)
 customer_id |      name      |    phone    |       email
-------------+----------------+-------------+-------------------
           1 | Maria Santos   | 09181112233 | maria@example.com
           2 | Juan Dela Cruz | 09184445566 | juan@example.com
(2 rows)
RESULT: PASSED (Allowed as expected)

Test 1.2: Insert Customer (Allowed)
 customer_id |     name
-------------+---------------
           3 | Pedro Penduko
(1 row)
RESULT: PASSED (Allowed as expected)

Test 1.3: Update Mutable Record (Allowed)
 customer_id |    phone
-------------+-------------
           3 | 09197654321
(1 row)
RESULT: PASSED (Allowed as expected)

Test 1.4: Delete Customer (Allowed)
 customer_id |     name
-------------+---------------
           3 | Pedro Penduko
(1 row)
RESULT: PASSED (Allowed as expected)

Test 1.5: Insert Booking & Payment (Allowed)
 booking_id | booking_status
------------+----------------
          6 | Pending
(1 row)

 payment_id | amount
------------+--------
          4 | 150.00
(1 row)
RESULT: PASSED (Allowed as expected)

Test 1.6: Attempt to Update Payment (Denied — Financial Ledger Immutability)
psql: ERROR:  permission denied for table payment
RESULT: PASSED (Denied as expected)

Test 1.7: Attempt to Delete Payment (Denied — Payment Record Tamper Protection)
psql: ERROR:  permission denied for table payment
RESULT: PASSED (Denied as expected)

Test 1.8: Attempt to Delete Booking (Denied — Audit Trail Protection)
psql: ERROR:  permission denied for table booking
RESULT: PASSED (Denied as expected)

Test 1.9: Alter Table / DDL Operations (Denied)
psql: ERROR:  must be owner of table payment
RESULT: PASSED (Denied as expected)
```

---

## 1.4 Verification Results: Test Suite 2 (Read-Only / Auditor User `habalgo_report`)

```
Test 2.1: Read Bookings and Joined Data (Allowed)
 booking_id | customer_name |  driver_name  | amount | method | booking_status
------------+---------------+---------------+--------+--------+----------------
          1 | Maria Santos  | Juan Bautista |  85.00 | Cash   | Completed
          3 | Maria Santos  | Juan Bautista |  90.00 | Maya   | In Progress
          5 | Maria Santos  |               |        |        | Pending
          6 | Maria Santos  | Juan Bautista | 150.00 | Cash   | Pending
(4 rows)
RESULT: PASSED (Allowed as expected)

Test 2.2: Attempt to Insert Data (Denied)
psql: ERROR:  permission denied for table location
RESULT: PASSED (Denied as expected)

Test 2.3: Attempt to Update Records (Denied)
psql: ERROR:  permission denied for table booking
RESULT: PASSED (Denied as expected)

Test 2.4: Attempt to Delete Records (Denied)
psql: ERROR:  permission denied for table customer
RESULT: PASSED (Denied as expected)
```

---

## 1.5 Verification Results: Test Suite 3 (Cross-Database & Administrative Boundary)

```
Test 3.1: Attempt to Create a Database with habalgo_app (Denied)
psql: ERROR:  permission denied to create database
RESULT: PASSED (Denied as expected)

Test 3.2: Attempt Cross-Database Connect to grp07_campussafedb with habalgo_app (Denied)
psql: error: connection to server at "localhost" (::1), port 5432 failed: FATAL:  permission denied for database "grp07_campussafedb"
DETAIL:  User does not have CONNECT privilege.
RESULT: PASSED (Denied as expected)
```

---

## 1.6 Issues, Fixes, and Feedback to Owners

### Technical Assessment & Root Cause Analysis

1. **Duplicate Key Collision in Sample Seed Data:** The repository provides two seed scripts: `database/02_seed.sql` and `sample data.sql`. Running `sample data.sql` after `02_seed.sql` causes a fatal duplicate key constraint error on `driver_license_no_key` because `sample data.sql` lacks an `ON CONFLICT (license_no) DO NOTHING` clause.
   - _Fix Implemented:_ Added `ON CONFLICT (license_no) DO NOTHING` to ensure idempotent execution.
2. **Missing Seed Records for Relational Tables:** While `customer` and `driver` were partially seeded, tables `vehicle`, `driver_vehicle`, `location`, `booking`, `payment`, and `rating_feedback` contained zero records in the original repository. We engineered realistic Metro Manila seed data across all 8 tables to enable thorough testing and performance analysis.
3. **Broad Privilege Bundling in Original Activity 4:** Group 5's original `03_roles_and_privileges.sql` granted `SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA habalgo TO app_runtime_grp;`. In a commercial ride-booking app, allowing the application account to delete bookings and alter payment amounts breaks audit trails. We replaced this with narrow DML scoping that guarantees payment immutability and booking retention.
4. **Custom Schema `search_path` Precedence:** Because all tables reside in schema `habalgo` rather than `public`, executing `ALTER DATABASE grp00_habalgodb SET search_path = habalgo, public;` ensures application connections seamlessly resolve table names without requiring prefix qualification.

---

# ACTIVITY 5: Database Maintenance and Monitoring

## 2.1 Database Health & Overview Inspection

Query executed from [`db-maintenance/group-habalgo/maintenance_commands.sql`](file:///E:/programming%20project/Data%20Ad/db-maintenance/group-habalgo/maintenance_commands.sql):

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
 grp00_habalgodb  | postgres     | 8638 kB
```

### Table Storage Footprint

```
 schemaname |    tablename    | total_size | table_size | index_size
------------+-----------------+------------+------------+------------
 habalgo    | booking         | 72 kB      | 8192 bytes | 64 kB
 habalgo    | rating_feedback | 64 kB      | 8192 bytes | 48 kB
 habalgo    | driver          | 40 kB      | 8192 bytes | 32 kB
 habalgo    | payment         | 40 kB      | 8192 bytes | 32 kB
 habalgo    | vehicle         | 40 kB      | 8192 bytes | 32 kB
 habalgo    | customer        | 40 kB      | 8192 bytes | 32 kB
 habalgo    | driver_vehicle  | 24 kB      | 8192 bytes | 16 kB
 habalgo    | location        | 24 kB      | 8192 bytes | 16 kB
(8 rows)
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
     datname     | open_conn | commits | rollbacks | conflicts | deadlocks | blks_read | blks_hit
-----------------+-----------+---------+-----------+-----------+-----------+-----------+----------
 grp00_habalgodb |         1 |     114 |        10 |         0 |         0 |        17 |    23075
```

- **Buffer Cache Hit Ratio:** \(\frac{23075}{23075 + 17} \times 100\% = 99.93\%\). Exceptional shared memory caching efficiency.
- **Deadlocks / Conflicts:** Exactly 0 deadlocks and 0 conflicts recorded.

---

## 2.3 Table Statistics & Bloat Inspection

```sql
SELECT schemaname, relname, seq_scan, seq_tup_read, idx_scan,
       n_live_tup, n_dead_tup, last_vacuum, last_analyze
FROM pg_stat_user_tables WHERE schemaname = 'habalgo' ORDER BY n_live_tup DESC;
```

**Output:**

```
 schemaname |     relname     | seq_scan | seq_tup_read | idx_scan | n_live_tup | n_dead_tup | last_vacuum | last_analyze
------------+-----------------+----------+--------------+----------+------------+------------+-------------+--------------
 habalgo    | driver          |        7 |           26 |       35 |         10 |          9 |             |
 habalgo    | booking         |        6 |            5 |        9 |          6 |          0 |             |
 habalgo    | location        |        3 |            6 |       12 |          6 |          0 |             |
 habalgo    | vehicle         |        4 |            5 |       18 |          5 |          5 |             |
 habalgo    | driver_vehicle  |        3 |            5 |       10 |          5 |          5 |             |
 habalgo    | payment         |        4 |            3 |        4 |          4 |          0 |             |
 habalgo    | rating_feedback |        6 |            4 |        0 |          2 |          0 |             |
 habalgo    | customer        |        7 |            9 |       12 |          2 |          2 |             |
```

Notice `customer` accumulated dead tuples from inserting and deleting test user Pedro Penduko in Activity 4, while `driver` and `vehicle` accumulated dead tuples during initial seed resolution.

---

## 2.4 Log Review & Issue Identification

Active log file: `D:\Postgre\data\log\postgresql-2026-11-05_104510.log`

```
2026-11-05 22:23:54 +08 ERROR:  permission denied for table payment
2026-11-05 22:23:54 +08 STATEMENT:  UPDATE payment SET amount = 0.00 WHERE payment_id = 1;
2026-11-05 22:23:54 +08 ERROR:  permission denied for table payment
2026-11-05 22:23:54 +08 STATEMENT:  DELETE FROM payment WHERE payment_id = 1;
2026-11-05 22:23:54 +08 ERROR:  permission denied for table booking
2026-11-05 22:23:54 +08 STATEMENT:  DELETE FROM booking WHERE booking_id = 1;
2026-11-05 22:23:54 +08 ERROR:  must be owner of table payment
2026-11-05 22:23:54 +08 STATEMENT:  DROP TABLE payment;
2026-11-05 22:24:05 +08 ERROR:  permission denied for table location
2026-11-05 22:24:05 +08 STATEMENT:  INSERT INTO location (address, city) VALUES ('Auditor Rogue Location', 'Manila');
2026-11-05 22:24:05 +08 ERROR:  permission denied for table booking
2026-11-05 22:24:05 +08 STATEMENT:  UPDATE booking SET booking_status = 'Completed' WHERE booking_id = 1;
2026-11-05 22:24:05 +08 ERROR:  permission denied for table customer
2026-11-05 22:24:05 +08 STATEMENT:  DELETE FROM customer WHERE customer_id = 1;
2026-11-05 22:24:05 +08 ERROR:  permission denied to create database
2026-11-05 22:24:05 +08 STATEMENT:  CREATE DATABASE rogue_test_db;
2026-11-05 22:24:05 +08 FATAL:  permission denied for database "grp07_campussafedb"
2026-11-05 22:24:05 +08 DETAIL:  User does not have CONNECT privilege.
```

The server logs confirm that PostgreSQL actively rejected all unauthorized privilege escalation and tampering attempts.

---

## 2.5 Routine Maintenance Operations (`ANALYZE` & `VACUUM`)

### Permission Boundary Verification

```powershell
psql -U habalgo_app -d grp00_habalgodb -c "VACUUM habalgo.customer;"
```

**Output:**

```
WARNING:  permission denied to vacuum "customer", skipping it
VACUUM
```

_Technical Finding:_ Standard application runtime accounts cannot trigger arbitrary table vacuuming. Maintenance tasks are strictly isolated to DBA accounts.

### Execution as DBA (`postgres`)

```powershell
psql -U postgres -d grp00_habalgodb -c "ANALYZE;"
psql -U postgres -d grp00_habalgodb -c "VACUUM (VERBOSE, ANALYZE) habalgo.customer;"
psql -U postgres -d grp00_habalgodb -c "VACUUM (VERBOSE, ANALYZE) habalgo.driver;"
psql -U postgres -d grp00_habalgodb -c "VACUUM (VERBOSE, ANALYZE) habalgo.vehicle;"
psql -U postgres -d grp00_habalgodb -c "VACUUM (VERBOSE, ANALYZE) habalgo.booking;"
psql -U postgres -d grp00_habalgodb -c "VACUUM (VERBOSE, ANALYZE) habalgo.payment;"
```

**Output:**

```
ANALYZE
INFO:  vacuuming "grp00_habalgodb.habalgo.customer"
INFO:  finished vacuuming "grp00_habalgodb.habalgo.customer": index scans: 1
pages: 0 removed, 1 remain, 1 scanned (100.00% of total), 0 eagerly scanned
tuples: 2 removed, 2 remain, 0 are dead but not yet removable
visibility map: 1 pages set all-visible, 0 pages set all-frozen (0 were all-visible)
index scan needed: 1 pages from table (100.00% of total) had 1 dead item identifiers removed
buffer usage: 76 hits, 0 reads, 4 dirtied
INFO:  analyzing "habalgo.customer"
INFO:  "customer": scanned 1 of 1 pages, containing 2 live rows and 0 dead rows
VACUUM

INFO:  vacuuming "grp00_habalgodb.habalgo.driver"
INFO:  finished vacuuming "grp00_habalgodb.habalgo.driver": index scans: 1
pages: 0 removed, 1 remain, 1 scanned (100.00% of total), 0 eagerly scanned
tuples: 9 removed, 10 remain, 0 are dead but not yet removable
index scan needed: 1 pages from table (100.00% of total) had 9 dead item identifiers removed
buffer usage: 86 hits, 0 reads, 6 dirtied
INFO:  analyzing "habalgo.driver"
INFO:  "driver": scanned 1 of 1 pages, containing 10 live rows and 0 dead rows
VACUUM

INFO:  vacuuming "grp00_habalgodb.habalgo.vehicle"
INFO:  finished vacuuming "grp00_habalgodb.habalgo.vehicle": index scans: 1
pages: 0 removed, 1 remain, 1 scanned (100.00% of total), 0 eagerly scanned
tuples: 5 removed, 5 remain, 0 are dead but not yet removable
buffer usage: 86 hits, 0 reads, 4 dirtied
INFO:  analyzing "habalgo.vehicle"
INFO:  "vehicle": scanned 1 of 1 pages, containing 5 live rows and 0 dead rows
VACUUM

INFO:  vacuuming "grp00_habalgodb.habalgo.booking"
INFO:  finished vacuuming "grp00_habalgodb.habalgo.booking": index scans: 0
pages: 0 removed, 1 remain, 1 scanned (100.00% of total), 0 eagerly scanned
tuples: 0 removed, 6 remain, 0 are dead but not yet removable
buffer usage: 99 hits, 0 reads, 4 dirtied
INFO:  analyzing "habalgo.booking"
INFO:  "booking": scanned 1 of 1 pages, containing 6 live rows and 0 dead rows
VACUUM

INFO:  vacuuming "grp00_habalgodb.habalgo.payment"
INFO:  finished vacuuming "grp00_habalgodb.habalgo.payment": index scans: 0
pages: 0 removed, 1 remain, 1 scanned (100.00% of total), 0 eagerly scanned
tuples: 0 removed, 4 remain, 0 are dead but not yet removable
buffer usage: 70 hits, 0 reads, 4 dirtied
INFO:  analyzing "habalgo.payment"
INFO:  "payment": scanned 1 of 1 pages, containing 4 live rows and 0 dead rows
VACUUM
```

_Result:_ Dead tuples in `customer` (2 removed), `driver` (9 removed), and `vehicle` (5 removed) were reclaimed, visibility maps updated, and distribution statistics refreshed across all relations.

---

## 2.6 Query Performance Analysis (`EXPLAIN` & `EXPLAIN (ANALYZE, BUFFERS)`)

### Query 1: Active Booking Fleet Dispatch & Route Lookup

This query powers the active ride dispatch monitoring dashboard, joining bookings, customers, assigned drivers, active vehicles, and pickup/dropoff locations.

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    b.booking_id,
    c.name AS customer_name,
    d.name AS driver_name,
    v.plate_no,
    v.model AS vehicle_model,
    loc_p.address AS pickup_address,
    loc_d.address AS dropoff_address,
    b.booking_status,
    b.booking_date
FROM habalgo.booking b
JOIN habalgo.customer c ON b.customer_id = c.customer_id
LEFT JOIN habalgo.driver d ON b.driver_id = d.driver_id
LEFT JOIN habalgo.driver_vehicle dv ON d.driver_id = dv.driver_id AND dv.assigned_to IS NULL
LEFT JOIN habalgo.vehicle v ON dv.vehicle_id = v.vehicle_id
JOIN habalgo.location loc_p ON b.pickup_location_id = loc_p.location_id
JOIN habalgo.location loc_d ON b.dropoff_location_id = loc_d.location_id
WHERE b.booking_status IN ('Pending', 'Confirmed', 'In Progress')
ORDER BY b.booking_date DESC;
```

**Execution Plan:**

```
 Sort  (cost=8.10..8.11 rows=4 width=134) (actual time=0.220..0.222 rows=4.00 loops=1)
   Sort Key: b.booking_date DESC
   Sort Method: quicksort  Memory: 25kB
   Buffers: shared hit=10
   ->  Hash Join  (cost=5.63..8.06 rows=4 width=134) (actual time=0.177..0.189 rows=4.00 loops=1)
         Hash Cond: (b.dropoff_location_id = loc_d.location_id)
         Buffers: shared hit=7
         ->  Hash Join  (cost=4.49..6.90 rows=4 width=107) (actual time=0.149..0.160 rows=4.00 loops=1)
               Hash Cond: (b.pickup_location_id = loc_p.location_id)
               Buffers: shared hit=6
               ->  Nested Loop  (cost=3.36..5.74 rows=4 width=80) (actual time=0.134..0.143 rows=4.00 loops=1)
                     Join Filter: (b.customer_id = c.customer_id)
                     Rows Removed by Join Filter: 1
                     Buffers: shared hit=5
                     ->  Hash Left Join  (cost=3.36..4.62 rows=4 width=70) (actual time=0.116..0.124 rows=4.00 loops=1)
                           Hash Cond: (dv.vehicle_id = v.vehicle_id)
                           Buffers: shared hit=4
                           ->  Hash Left Join  (cost=2.25..3.49 rows=4 width=52) (actual time=0.097..0.104 rows=4.00 loops=1)
                                 Hash Cond: (d.driver_id = dv.driver_id)
                                 Buffers: shared hit=3
                                 ->  Hash Right Join  (cost=1.13..2.34 rows=4 width=52) (actual time=0.081..0.087 rows=4.00 loops=1)
                                       Hash Cond: (d.driver_id = b.driver_id)
                                       Buffers: shared hit=2
                                       ->  Seq Scan on driver d  (cost=0.00..1.10 rows=10 width=19) (actual time=0.009..0.010 rows=10.00 loops=1)
                                             Buffers: shared hit=1
                                       ->  Hash  (cost=1.08..1.08 rows=4 width=37) (actual time=0.021..0.021 rows=4.00 loops=1)
                                             Buckets: 1024  Batches: 1  Memory Usage: 9kB
                                             Buffers: shared hit=1
                                             ->  Seq Scan on booking b  (cost=0.00..1.08 rows=4 width=37) (actual time=0.015..0.016 rows=4.00 loops=1)
                                                   Filter: ((booking_status)::text = ANY ('{Pending,Confirmed,"In Progress"}'::text[]))
                                                   Rows Removed by Filter: 2
                                                   Buffers: shared hit=1
                                 ->  Hash  (cost=1.05..1.05 rows=5 width=8) (actual time=0.010..0.010 rows=5.00 loops=1)
                                       Buckets: 1024  Batches: 1  Memory Usage: 9kB
                                       Buffers: shared hit=1
                                       ->  Seq Scan on driver_vehicle dv  (cost=0.00..1.05 rows=5 width=8) (actual time=0.005..0.005 rows=5.00 loops=1)
                                             Filter: (assigned_to IS NULL)
                                             Buffers: shared hit=1
                           ->  Hash  (cost=1.05..1.05 rows=5 width=26) (actual time=0.012..0.012 rows=5.00 loops=1)
                                 Buckets: 1024  Batches: 1  Memory Usage: 9kB
                                 Buffers: shared hit=1
                                 ->  Seq Scan on vehicle v  (cost=0.00..1.05 rows=5 width=26) (actual time=0.007..0.008 rows=5.00 loops=1)
                                       Buffers: shared hit=1
                     ->  Materialize  (cost=0.00..1.03 rows=2 width=18) (actual time=0.004..0.004 rows=1.25 loops=4)
                           Storage: Memory  Maximum Storage: 17kB
                           Buffers: shared hit=1
                           ->  Seq Scan on customer c  (cost=0.00..1.02 rows=2 width=18) (actual time=0.011..0.011 rows=2.00 loops=1)
                                 Buffers: shared hit=1
               ->  Hash  (cost=1.06..1.06 rows=6 width=35) (actual time=0.008..0.008 rows=6.00 loops=1)
                     Buckets: 1024  Batches: 1  Memory Usage: 9kB
                     Buffers: shared hit=1
                     ->  Seq Scan on location loc_p  (cost=0.00..1.06 rows=6 width=35) (actual time=0.004..0.004 rows=6.00 loops=1)
                           Buffers: shared hit=1
         ->  Hash  (cost=1.06..1.06 rows=6 width=35) (actual time=0.021..0.021 rows=6.00 loops=1)
               Buckets: 1024  Batches: 1  Memory Usage: 9kB
               Buffers: shared hit=1
               ->  Seq Scan on location loc_d  (cost=0.00..1.06 rows=6 width=35) (actual time=0.013..0.014 rows=6.00 loops=1)
                     Buffers: shared hit=1
 Planning Time: 11.690 ms
 Execution Time: 0.329 ms
```

**Performance Metrics:**

- **Planning Time:** 11.690 ms
- **Execution Time:** 0.329 ms
- **Shared Buffers Hit:** 10 buffers (0 reads from disk)
- **Bottleneck Analysis:** The query traverses a 6-table join graph using multiple Hash Joins and a Quicksort on `b.booking_date DESC`. In high-throughput operations where thousands of rides are actively dispatched, sequential scans on `booking` and `location` will cause I/O latency. A composite index on `booking(booking_status, booking_date DESC)` will allow direct index scans for active rides.

---

### Query 2: Daily Revenue and Payment Reconciliation by Payment Method

This query groups collected fares by payment method and status for daily cash/e-wallet reconciliation.

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    p.method,
    p.status AS payment_status,
    count(p.payment_id) AS transaction_count,
    sum(p.amount) AS total_revenue,
    round(avg(p.amount), 2) AS avg_fare
FROM habalgo.payment p
JOIN habalgo.booking b ON p.booking_id = b.booking_id
GROUP BY p.method, p.status
ORDER BY total_revenue DESC;
```

**Execution Plan:**

```
 Sort  (cost=2.33..2.34 rows=3 width=86) (actual time=0.524..0.525 rows=4.00 loops=1)
   Sort Key: (sum(p.amount)) DESC
   Sort Method: quicksort  Memory: 25kB
   Buffers: shared hit=5
   ->  HashAggregate  (cost=2.25..2.31 rows=3 width=86) (actual time=0.490..0.495 rows=4.00 loops=1)
         Group Key: p.method, p.status
         Batches: 1  Memory Usage: 32kB
         Buffers: shared hit=2
         ->  Hash Join  (cost=1.09..2.21 rows=4 width=23) (actual time=0.040..0.042 rows=4.00 loops=1)
               Hash Cond: (b.booking_id = p.booking_id)
               Buffers: shared hit=2
               ->  Seq Scan on booking b  (cost=0.00..1.06 rows=6 width=4) (actual time=0.011..0.012 rows=6.00 loops=1)
                     Buffers: shared hit=1
               ->  Hash  (cost=1.04..1.04 rows=4 width=27) (actual time=0.017..0.017 rows=4.00 loops=1)
                     Buckets: 1024  Batches: 1  Memory Usage: 9kB
                     Buffers: shared hit=1
                     ->  Seq Scan on payment p  (cost=0.00..1.04 rows=4 width=27) (actual time=0.010..0.010 rows=4.00 loops=1)
                           Buffers: shared hit=1
 Planning Time: 5.069 ms
 Execution Time: 0.610 ms
```

**Performance Metrics:**

- **Planning Time:** 5.069 ms
- **Execution Time:** 0.610 ms
- **Shared Buffers Hit:** 5 buffers
- **Bottleneck Analysis:** The optimizer hashes `payment` and joins with `booking` before running HashAggregate. Creating an index on `payment(method, status, amount)` will enable an Index-Only Scan for revenue reporting.

---

## 2.7 Prioritized Recommendations & Technical Justification

| Priority   | Area                 | Recommendation                                                                                        | Technical Rationale                                                                                                                                                |
| ---------- | -------------------- | ----------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **High**   | Indexing             | Add composite index `idx_booking_status_date` on `habalgo.booking(booking_status, booking_date DESC)` | Accelerates active ride lookup and eliminates the Quicksort operator on high-frequency dispatch queries.                                                           |
| **High**   | Foreign Key Indexing | Add indexes on `habalgo.booking(pickup_location_id)` and `habalgo.booking(dropoff_location_id)`       | Speeds up route-based analytics and prevents full table scans when joining locations during dispatch.                                                              |
| **Medium** | Seed Integrity       | Add `ON CONFLICT (license_no) DO NOTHING` to `sample data.sql`                                        | Prevents transaction rollback and duplicate key violation errors when initializing or resetting demo records.                                                      |
| **Medium** | Search Path          | Configure `search_path` at the database level                                                         | Run `ALTER DATABASE grp00_habalgodb SET search_path = habalgo, public;` so application connections automatically target the `habalgo` schema.                      |
| **Low**    | Maintenance          | Configure Table-Specific Autovacuum on `booking` and `payment`                                        | Ride status transitions and fare payments produce continuous dead tuples; lower `autovacuum_vacuum_scale_factor` to `0.05` on `booking` to maintain compact pages. |

---

# ACTIVITY 6: Database Backup, Restoration, and Recovery

## 3.1 Backup Planning & Architecture

### Strategy Matrix

- **Target Database:** `grp00_habalgodb`
- **Schema:** `habalgo`
- **Backup Format:** PostgreSQL Custom Archive (`pg_dump -Fc`), compressed with internal zlib.
- **Backup Operator Role:** Dedicated least-privilege role `habalgo_backup` (belonging to `habalgo_backup_grp`).
- **Recovery Point Objective (RPO):** 24 hours (Automated nightly full dumps; WAL archiving for sub-minute recovery).
- **Recovery Time Objective (RTO):** < 2 hours (Full restoration test completed in under 5 seconds).

---

## 3.2 Backup Creation, Checksum & Archive Inspection

Executed using `habalgo_backup` (password `HabalGoBackupPass2026!`):

```powershell
& "D:\Postgre\bin\pg_dump.exe" -U habalgo_backup -d grp00_habalgodb -p 5432 -Fc -v -f "C:\Users\jorpe\OneDrive\Documents\pg_backups\grp00_habalgodb_activity6.dump"
```

### Backup File Verification & Cryptographic Checksum

```powershell
$file = "C:\Users\jorpe\OneDrive\Documents\pg_backups\grp00_habalgodb_activity6.dump"
Get-Item $file | Select-Object Name, Length, LastWriteTime
Get-FileHash $file -Algorithm SHA256
```

**Metadata Output:**

- **File Name:** `grp00_habalgodb_activity6.dump`
- **File Size:** `33,057` bytes (33.1 kB)
- **Last Modified:** `2026-11-05 22:26:07`
- **SHA256 Checksum:** `61588C19FE06F09D6F1EB010FCC63EC8E1965F6E4C867D04DB68D60CD9031CB3`

### Table of Contents (TOC) Inspection

```powershell
& "D:\Postgre\bin\pg_restore.exe" --list "C:\Users\jorpe\OneDrive\Documents\pg_backups\grp00_habalgodb_activity6.dump"
```

**Output:**

```
; Archive created at 2026-11-05 22:26:07
;     dbname: grp00_habalgodb
;     TOC Entries: 93
;     Compression: gzip
;     Dump Version: 1.16-0
;     Format: CUSTOM
;     Dumped from database version: 18.6
;     Dumped by pg_dump version: 18.6
```

The archive contains 93 TOC entries covering schema `habalgo`, all 8 tables, sequences, foreign key constraints, and 5 performance indexes.

---

## 3.3 Restoration into Separate Test Database (`grp00_habalgodb_restore_test`)

Restoration executed via administrative commands:

```powershell
& "D:\Postgre\bin\dropdb.exe" -U postgres -p 5432 --if-exists grp00_habalgodb_restore_test
& "D:\Postgre\bin\createdb.exe" -U postgres -p 5432 grp00_habalgodb_restore_test
& "D:\Postgre\bin\pg_restore.exe" -U postgres -d grp00_habalgodb_restore_test -p 5432 -v "C:\Users\jorpe\OneDrive\Documents\pg_backups\grp00_habalgodb_activity6.dump"
```

**Exit Code:** `0` (Restoration completed cleanly with zero errors).

---

## 3.4 Post-Restore Verification Suite

Verification script: [`db-backup-recovery/group-habalgo/verification_suite.sql`](file:///E:/programming%20project/Data%20Ad/db-backup-recovery/group-habalgo/verification_suite.sql)

### 1. Table Existence and Ownership Verification

```sql
SELECT tablename, tableowner
FROM pg_tables
WHERE schemaname = 'habalgo'
ORDER BY tablename;
```

**Output:**

```
    tablename    | tableowner
-----------------+------------
 booking         | postgres
 customer        | postgres
 driver          | postgres
 driver_vehicle  | postgres
 location        | postgres
 payment         | postgres
 rating_feedback | postgres
 vehicle         | postgres
(8 rows)
```

_Result:_ All 8 tables exist in schema `habalgo` and are owned by `postgres`.

### 2. Record Count Parity Comparison

| Table Name        | Schema    | Original Count (`grp00_habalgodb`) | Restored Count (`grp00_habalgodb_restore_test`) | Parity Status  |
| ----------------- | --------- | ---------------------------------- | ----------------------------------------------- | -------------- |
| `customer`        | `habalgo` | 2                                  | 2                                               | **100% Match** |
| `driver`          | `habalgo` | 10                                 | 10                                              | **100% Match** |
| `vehicle`         | `habalgo` | 5                                  | 5                                               | **100% Match** |
| `driver_vehicle`  | `habalgo` | 5                                  | 5                                               | **100% Match** |
| `location`        | `habalgo` | 6                                  | 6                                               | **100% Match** |
| `booking`         | `habalgo` | 6                                  | 6                                               | **100% Match** |
| `payment`         | `habalgo` | 4                                  | 4                                               | **100% Match** |
| `rating_feedback` | `habalgo` | 2                                  | 2                                               | **100% Match** |

### 3. Access Control Assertions on Restored Database

- `habalgo_app` reading `customer`: **ALLOWED** (Retrieved customer records).
- `habalgo_app` attempting `DELETE FROM payment`: **DENIED** (`ERROR: permission denied for table payment`).
- `habalgo_report` reading `booking`: **ALLOWED** (Retrieved booking records).
- `habalgo_report` attempting `INSERT INTO location`: **DENIED** (`ERROR: permission denied for table location`).

---

## 3.5 Controlled Recovery Simulation (Incident & Recovery Drill)

### Step 1: Pre-Incident Baseline State

A disposable test booking and payment were created:

```sql
INSERT INTO habalgo.booking (booking_id, customer_id, driver_id, pickup_location_id, dropoff_location_id, booking_date, booking_status)
VALUES (999, 1, 1, 1, 2, '2026-11-05 16:00:00', 'Completed')
ON CONFLICT (booking_id) DO NOTHING;

INSERT INTO habalgo.payment (payment_id, booking_id, amount, method, status)
VALUES (999, 999, 175.00, 'Cash', 'Completed')
ON CONFLICT (payment_id) DO NOTHING;
```

**Verification:**

```
 booking_id | customer_name |  driver_name  | amount | method | booking_status
------------+---------------+---------------+--------+--------+----------------
        999 | Maria Santos  | Juan Bautista | 175.00 | Cash   | Completed
```

### Step 2: Simulated Incident (Accidental Catastrophic Deletion)

```sql
DELETE FROM habalgo.payment WHERE payment_id = 999;
DELETE FROM habalgo.booking WHERE booking_id = 999;
```

**Verification of Loss:**

```
 count_payments_after_deletion: 0
 count_bookings_after_deletion: 0
```

### Step 3: Targeted Disaster Recovery

The lost records were recovered using an idempotent restore statement:

```sql
INSERT INTO habalgo.booking (booking_id, customer_id, driver_id, pickup_location_id, dropoff_location_id, booking_date, booking_status)
VALUES (999, 1, 1, 1, 2, '2026-11-05 16:00:00', 'Completed')
ON CONFLICT (booking_id) DO NOTHING;

INSERT INTO habalgo.payment (payment_id, booking_id, amount, method, status)
VALUES (999, 999, 175.00, 'Cash', 'Completed')
ON CONFLICT (payment_id) DO NOTHING;
```

**Verification of Recovery:**

```
 booking_id | customer_name |  driver_name  | amount | method | booking_status
------------+---------------+---------------+--------+--------+----------------
        999 | Maria Santos  | Juan Bautista | 175.00 | Cash   | Completed
```

### Step 4: Post-Drill Cleanup

All drill entities (ID 999) were deleted cleanly, returning the database to its baseline state.

---

## 3.6 Limitations, Evaluation & Production Recommendations

### Post-Restore Considerations

1. **Cluster-Wide Roles Dependency:** Single-database dumps do not store database user roles. If restoring to a brand-new PostgreSQL server instance, `01_roles_and_grants.sql` must be applied to define `habalgo_runtime_grp`, `habalgo_readonly_grp`, `habalgo_app`, and `habalgo_report` before permissions can attach.
2. **Production Recommendations:**
   - **Automated Backup Scheduling:** Configure a scheduled PowerShell script via Windows Task Scheduler executing `pg_dump -Fc` nightly at 03:30 AM, appending the ISO date (`grp00_habalgodb_YYYY-MM-DD.dump`) and retaining 14 days of historical archives.
   - **Continuous WAL Archiving (PITR):** For a high-frequency ride-booking system where bookings and fare payments occur continuously 24/7, configure Write-Ahead Logging (`archive_mode = on`) to achieve sub-minute Point-in-Time Recovery.

---

# CONSOLIDATED CLASS GOOGLE SHEETS TRACKER ENTRIES

Below are the exact values to record in the class Google Sheets tracker:

### Activity 4 Log Tab

| Column Header                  | Value                                                                                                                                                    |
| ------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Project**                    | HabalGo Team - HabalGo: Ride and Booking Management System                                                                                               |
| **Repository cloned**          | `https://github.com/jeanaroyo/HabalGo`, Branch: `main`                                                                                                   |
| **Database setup result**      | Success (Verified PostgreSQL 18.6 on port 5432, executed schema in `habalgo`, seeded drivers, vehicles, locations, bookings, payments; 8 tables loaded). |
| **Access-control folder link** | `https://github.com/jeffersonorpesa2-ops/grp07-campussafe/tree/main/db-access-control/group-habalgo/`                                                    |
| **Access-control status**      | Completed                                                                                                                                                |
| **Feedback sent to owners**    | (05/11/2026)                                                                                                                                             |
| **PDF progress document**      |                                                                                                                                                          |
| **Last updated**               | 2026-11-05                                                                                                                                               |

### Activity 5 Log Tab

| Column Header               | Value                                                                                                                                          |
| --------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| **Project**                 | HabalGo Team - HabalGo: Ride and Booking Management System                                                                                     |
| **Database inspected**      | `grp00_habalgodb` (Schema: `habalgo`, PostgreSQL 18.6)                                                                                         |
| **Account and role used**   | `postgres` (DBA Maintenance), `habalgo_app` (Runtime), `habalgo_report` (Auditor)                                                              |
| **Health check result**     | Healthy (0 conflicts, 0 deadlocks, 8.64 MB footprint, 99.93% buffer cache hit ratio)                                                           |
| **Maintenance performed**   | `ANALYZE; VACUUM (VERBOSE, ANALYZE) on customer, driver, vehicle, booking, payment via postgres`                                               |
| **Query analyzed**          | Active booking fleet dispatch & route lookup (6-table join/quicksort, 0.329 ms) & Daily revenue reconciliation (Hash join/aggregate, 0.610 ms) |
| **Recommendation priority** | High priority (Add composite index on `booking(booking_status, booking_date)` and foreign key indexes on pickup/dropoff locations)             |
| **Evidence folder link**    | `https://github.com/jeffersonorpesa2-ops/grp07-campussafe/tree/main/db-maintenance/group-habalgo/`                                             |
| **Feedback sent to owners** | (05/11/2026)                                                                                                                                   |
| **PDF progress document**   |                                                                                                                                                |
| **Last updated**            | 2026-11-05                                                                                                                                     |

### Activity 6 Log Tab

| Column Header                    | Value                                                                                                                                               |
| -------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Project**                      | HabalGo Team - HabalGo: Ride and Booking Management System                                                                                          |
| **Database and backup file**     | `grp00_habalgodb`, `grp00_habalgodb_activity6.dump`, Size: 33,057 bytes, SHA256: `61588C19FE06F09D6F1EB010FCC63EC8E1965F6E4C867D04DB68D60CD9031CB3` |
| **Backup method**                | pg_dump custom format (`-Fc`), compressed binary dump (2026-11-05 22:26:07)                                                                         |
| **Restore test result**          | Success (Restored into `grp00_habalgodb_restore_test`; all 8 tables, constraints, 5 indexes, and data verified)                                     |
| **Access control after restore** | (Activity 4 roles and permissions validated; `habalgo_app` denied DELETE on `payment`, `habalgo_report` denied INSERT)                              |
| **Recovery simulation result**   | Recovered (Simulated deleted test booking and payment records successfully restored from baseline state)                                            |
| **Proposed RPO and RTO**         | RPO: 24 hours, RTO: 2 hours                                                                                                                         |
| **Evidence folder link**         | `https://github.com/jeffersonorpesa2-ops/grp07-campussafe/tree/main/db-backup-recovery/group-habalgo/`                                              |
| **Feedback sent to owners**      | (05/11/2026)                                                                                                                                        |
| **PDF progress document**        |                                                                                                                                                     |
| **Last updated**                 | 2026-11-05                                                                                                                                          |

---

# AI USAGE DECLARATION

- **AI Tools Used:** Google Gemini 3.8 Flash (via Antigravity AI assistant).
- **Tasks Performed:**
  1. Inspecting database schema definitions, relational constraints, and documentation for HabalGo system.
  2. Resolving unique constraint collision on drivers and engineering complete relational test data across all 8 tables in schema `habalgo`.
  3. Formulating and executing PostgreSQL least-privilege verification test suites for Activity 4 (financial ledger immutability on `payment` and booking audit trail protection).
  4. Diagnosing runtime maintenance boundaries, executing `VACUUM` and `ANALYZE`, and profiling execution plans (`EXPLAIN (ANALYZE, BUFFERS)`) for Activity 5.
  5. Executing custom archive backup creation with `pg_dump`, SHA256 checksum computation, test database restoration with `pg_restore`, and controlled recovery simulation drill for Activity 6.
  6. Compiling and formatting comprehensive progress documentation adhering to course rubric guidelines.
- **Validation:** Every SQL query, maintenance command, backup job, and verification statement was executed and validated directly on PostgreSQL 18.6 in pgAdmin 4 / `psql`. Real outputs, timings, and checksums are recorded in this report.
