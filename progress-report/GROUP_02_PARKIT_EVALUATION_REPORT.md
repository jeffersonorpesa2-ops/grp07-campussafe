# COMP 018: Database Administration — Comprehensive Project Report

## Activities 4, 5, and 6: Access Control, Maintenance & Monitoring, Backup & Recovery

---

### Project Identification & Metadata

| Field                           | Details                                                                                                              |
| ------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| **Course**                      | COMP 018 — Database Administration                                                                                   |
| **Evaluating Group**            | **Group 7:** Alba, Arreza, Orpesa, Robiso, Santos                                                                    |
| **Evaluating Group Repository** | [https://github.com/jeffersonorpesa2-ops/grp07-campussafe](https://github.com/jeffersonorpesa2-ops/grp07-campussafe) |
| **Target Project Monitored**    | **Park-It: Parking Management System**                                                                               |
| **Target Project Group**        | **Group 2** (De Vera Miller P., Butanas John David, Macascas Mark Andrew, Pelia Jhon Francis, Lumbo Marianne)        |
| **Target Project Repository**   | [https://github.com/millerdevera6-glitch/park-it-database](https://github.com/millerdevera6-glitch/park-it-database) |
| **Primary Database**            | `grp_parkitdb` (PostgreSQL 18.6 on x86_64 Windows, compiled by MSVC)                                                 |
| **Restored Test Database**      | `grp_parkitdb_restore_test`                                                                                          |

---

# TABLE OF CONTENTS

1. [ACTIVITY 4: Database Users, Roles, Privileges, and Access Control](#activity-4-database-users-roles-privileges-and-access-control)
   - 1.1 Access-Control Plan & Architecture
   - 1.2 SQL Scripts Summary & Setup Execution
   - 1.3 Verification Results: Test Suite 1 (Runtime User `parkit_app`)
   - 1.4 Verification Results: Test Suite 2 (Read-Only / Auditor User `parkit_report`)
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
   - 3.3 Restoration into Separate Test Database (`grp_parkitdb_restore_test`)
   - 3.4 Post-Restore Verification Suite
   - 3.5 Controlled Recovery Simulation (Incident & Recovery Drill)
   - 3.6 Limitations, Evaluation & Production Recommendations
4. [CONSOLIDATED CLASS GOOGLE SHEETS TRACKER ENTRIES](#consolidated-class-google-sheets-tracker-entries)
5. [AI USAGE DECLARATION](#ai-usage-declaration)

---

# ACTIVITY 4: Database Users, Roles, Privileges, and Access Control

## 1.1 Access-Control Plan & Architecture

### Problem in Activity 3

In default configurations, web applications often connect using the PostgreSQL superuser (`postgres`) or an unrestricted account. In a parking management system like **Park-It**, allowing the application runtime account to possess blanket `ALL PRIVILEGES` across all tables presents significant security risks. If an application endpoint (such as `PUT /api/zones/:id` or `DELETE /api/zones/:id`) is exposed to SQL injection or broken authorization, malicious actors could alter payment amounts, delete vehicle entry/exit audit logs, manipulate billing records, or drop entire operational tables. This directly violates the **Principle of Least Privilege (PoLP)**.

### Activity 4 Solution

For Group 2's **Park-It** platform, we implemented a comprehensive role-based access control (RBAC) hierarchy decoupling administrative maintenance from day-to-day application operations:

- **Group Roles (`NOLOGIN`):** Abstract privilege containers representing distinct functional roles (`parkit_runtime_grp`, `parkit_readonly_grp`, and `parkit_backup_grp`).
- **Login Roles (`LOGIN`):** Individual authenticated database accounts assigned to their corresponding group roles (`parkit_app`, `parkit_report`, and `parkit_backup`).
- **Financial Ledger Immutability (Narrow DML Scoping):** The runtime account `parkit_app` is granted `SELECT`, `INSERT`, `UPDATE`, and `DELETE` on operational zone and vehicle tables (`parking_zone`, `vehicle`). On parking sessions (`transaction`), it can `SELECT`, `INSERT`, and `UPDATE` (to record entry time, exit time, and status changes), but is **strictly denied `DELETE`** to protect the audit trail. On fee collections (`payment`), it is granted `SELECT` and `INSERT` only, with **`UPDATE` and `DELETE` strictly revoked**, ensuring completed payments are immutable.
- **Auditor Credential Protection:** The read-only reporting account `parkit_report` is granted `SELECT` on parking zones, vehicles, transactions, and payments, but is **explicitly denied `SELECT` on `staff_user`**, safeguarding staff password hashes from external compliance audits.
- **Backup Isolation:** The dedicated backup operator `parkit_backup` is granted read-only schema usage and `SELECT` across all tables and sequences to produce consistent logical dumps via `pg_dump -Fc` without DML or DDL write privileges.

### Access-Control Matrix

| Login Account   | Group Role (`NOLOGIN`) | Application Role                    | Responsibilities                                                                                            | Assigned Privileges                                                                                                                                                                                                                                                                    | Technical Justification                                                                                                                                                        |
| --------------- | ---------------------- | ----------------------------------- | ----------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `parkit_app`    | `parkit_runtime_grp`   | Node.js Runtime (Express API)       | Handles parking zone management, vehicle registration, check-ins, check-outs, and payment logging           | • `CONNECT` on `grp_parkitdb`<br>• `USAGE` on schema `public`<br>• `SELECT, INSERT, UPDATE, DELETE` on `parking_zone`, `vehicle`<br>• `SELECT, INSERT, UPDATE` on `transaction`<br>• `SELECT, INSERT` on `payment`<br>• `SELECT` on `staff_user`<br>• `USAGE, SELECT` on all sequences | Restricting `payment` to append-only and denying `DELETE` on `transaction` guarantees that parking billing histories and vehicle transit logs cannot be purged or manipulated. |
| `parkit_report` | `parkit_readonly_grp`  | Parking Auditor / Billing Inspector | Read-only inspection of parking capacity utilization, vehicle turnover rates, and daily revenue collections | • `CONNECT` on `grp_parkitdb`<br>• `USAGE` on schema `public`<br>• `SELECT` on `parking_zone`, `vehicle`, `transaction`, `payment`<br>_(No access to `staff_user`)_                                                                                                                    | Full read transparency for occupancy audits and financial reconciliation without risk of data alteration. Excluding `staff_user` shields password hashes.                      |
| `parkit_backup` | `parkit_backup_grp`    | Backup Operator                     | Runs logical database backups (`pg_dump`)                                                                   | • `CONNECT` on `grp_parkitdb`<br>• `USAGE` on schema `public`<br>• `SELECT` on all tables & sequences                                                                                                                                                                                  | Grants complete read access required for logical dumps while strictly preventing DDL or DML write operations.                                                                  |
| `postgres`      | _(Superuser)_          | Database Administrator              | Schema provisioning, indexing, maintenance (`VACUUM`/`ANALYZE`), disaster recovery                          | Superuser / Owner privileges                                                                                                                                                                                                                                                           | Reserved strictly for DBA operations; never configured as the application connection account.                                                                                  |

---

## 1.2 SQL Scripts Summary & Setup Execution

The access-control configuration script ([`db-access-control/group-02-parkit/01_roles_and_grants.sql`](file:///E:/programming%20project/Data%20Ad/db-access-control/group-02-parkit/01_roles_and_grants.sql)) was executed as `postgres` against `grp_parkitdb`:

```sql
-- 1. Create Group Roles (NOLOGIN)
CREATE ROLE parkit_runtime_grp NOLOGIN;
CREATE ROLE parkit_readonly_grp NOLOGIN;
CREATE ROLE parkit_backup_grp NOLOGIN;

-- 2. Create Login Roles (LOGIN)
CREATE ROLE parkit_app LOGIN PASSWORD 'AppRuntimePass2026!';
CREATE ROLE parkit_report LOGIN PASSWORD 'ReportPass2026!';
CREATE ROLE parkit_backup LOGIN PASSWORD 'BackupPass2026!';

-- 3. Assign Role Memberships
GRANT parkit_runtime_grp TO parkit_app;
GRANT parkit_readonly_grp TO parkit_report;
GRANT parkit_backup_grp TO parkit_backup;

-- 4. Harden Session Defaults
ALTER ROLE parkit_app IN DATABASE grp_parkitdb SET search_path = public;
ALTER ROLE parkit_app IN DATABASE grp_parkitdb SET statement_timeout = '30s';
ALTER ROLE parkit_app IN DATABASE grp_parkitdb SET lock_timeout = '10s';

-- 5. Lock down PUBLIC permissions
REVOKE ALL ON DATABASE grp_parkitdb FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- 6. Database Connection and Schema Usage
GRANT CONNECT ON DATABASE grp_parkitdb TO parkit_runtime_grp, parkit_readonly_grp, parkit_backup_grp;
GRANT USAGE ON SCHEMA public TO parkit_runtime_grp, parkit_readonly_grp, parkit_backup_grp;

-- 7. Application Runtime Permissions (Least Privilege)
GRANT SELECT, INSERT, UPDATE, DELETE ON public.parking_zone, public.vehicle TO parkit_runtime_grp;
GRANT SELECT, INSERT, UPDATE ON public.transaction TO parkit_runtime_grp;
GRANT SELECT, INSERT ON public.payment TO parkit_runtime_grp;
GRANT SELECT ON public.staff_user TO parkit_runtime_grp;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO parkit_runtime_grp;

-- 8. Read-Only / Auditor Role Permissions (Excluding staff_user)
GRANT SELECT ON public.parking_zone, public.vehicle, public.transaction, public.payment TO parkit_readonly_grp;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO parkit_readonly_grp;

-- 9. Backup Operator Permissions
GRANT SELECT ON ALL TABLES IN SCHEMA public TO parkit_backup_grp;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO parkit_backup_grp;

-- 10. Default Privileges for Future Objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE ON TABLES TO parkit_runtime_grp;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO parkit_runtime_grp;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO parkit_readonly_grp;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO parkit_backup_grp;
```

---

## 1.3 Verification Results: Test Suite 1 (Runtime User `parkit_app`)

### Test 1.1: Read Data (Allowed)

- **SQL Statement:**
  ```sql
  SELECT zone_id, zone_name, max_capacity, current_active_count FROM parking_zone LIMIT 5;
  ```
- **Expected Result:** Allowed; returns available parking zones and capacities.
- **Actual Result / Output:**
  ```text
   zone_id |        zone_name         | max_capacity | current_active_count
  ---------+--------------------------+--------------+----------------------
         1 | North Open Lot           |           50 |                    5
         2 | South Multi-Level Garage |          120 |                   42
         3 | East Faculty Annex       |           40 |                   12
         4 | VIP / Visitor Bay        |           25 |                    3
  (4 rows)
  ```

### Test 1.2: Insert a Parking Zone & Advance Sequence (Allowed)

- **SQL Statement:**
  ```sql
  INSERT INTO parking_zone (zone_name, max_capacity, current_active_count)
  VALUES ('West Test Lot', 60, 0)
  RETURNING zone_id, zone_name;
  ```
- **Expected Result:** Allowed; inserts record and advances `parking_zone_zone_id_seq`.
- **Actual Result / Output:**
  ```text
   zone_id |   zone_name
  ---------+---------------
         5 | West Test Lot
  (1 row)
  INSERT 0 1
  ```

### Test 1.3: Update Mutable Record (Allowed)

- **SQL Statement:**
  ```sql
  UPDATE parking_zone SET current_active_count = 5 WHERE zone_name = 'West Test Lot' RETURNING zone_id, current_active_count;
  ```
- **Expected Result:** Allowed; runtime account updates mutable active parking counts.
- **Actual Result / Output:**
  ```text
   zone_id | current_active_count
  ---------+----------------------
         5 |                    5
  (1 row)
  UPDATE 1
  ```

### Test 1.4: Delete Unreferenced Parking Zone (Allowed)

- **SQL Statement:**
  ```sql
  DELETE FROM parking_zone WHERE zone_name = 'West Test Lot' RETURNING zone_id, zone_name;
  ```
- **Expected Result:** Allowed; runtime account is authorized to remove decommissioned zones.
- **Actual Result / Output:**
  ```text
   zone_id |   zone_name
  ---------+---------------
         5 | West Test Lot
  (1 row)
  DELETE 1
  ```

### Test 1.5: Insert a Transaction & Payment (Allowed)

- **SQL Statement:**
  ```sql
  INSERT INTO transaction (vehicle_id, zone_id, entry_time, status) VALUES (1, 1, CURRENT_TIMESTAMP, 'Active') RETURNING transaction_id;
  INSERT INTO payment (transaction_id, amount, payment_method, payment_time)
  VALUES ((SELECT max(transaction_id) FROM transaction), 50.00, 'Cash', CURRENT_TIMESTAMP)
  RETURNING payment_id, amount;
  ```
- **Expected Result:** Allowed; runtime account registers check-ins and logs parking fee payments.
- **Actual Result / Output:**

  ```text
   transaction_id
  ----------------
                6
  (1 row)
  INSERT 0 1

   payment_id | amount
  ------------+--------
            4 |  50.00
  (1 row)
  INSERT 0 1
  ```

### Test 1.6: Attempt to Update Payment (Denied — Financial Ledger Immutability)

- **SQL Statement:**
  ```sql
  UPDATE payment SET amount = 0.00 WHERE transaction_id = 1;
  ```
- **Expected Result:** Denied; runtime account must never alter fee amounts on completed payments.
- **Actual Result / Output:**
  ```text
  ERROR:  permission denied for table payment
  ```

### Test 1.7: Attempt to Delete Payment (Denied — Payment Record Tamper Protection)

- **SQL Statement:**
  ```sql
  DELETE FROM payment WHERE payment_id = 1;
  ```
- **Expected Result:** Denied; runtime account cannot delete payment records.
- **Actual Result / Output:**
  ```text
  ERROR:  permission denied for table payment
  ```

### Test 1.8: Attempt to Delete Parking Transaction (Denied — Audit Trail Protection)

- **SQL Statement:**
  ```sql
  DELETE FROM transaction WHERE transaction_id = 1;
  ```
- **Expected Result:** Denied; transit audit history cannot be purged by the runtime application.
- **Actual Result / Output:**
  ```text
  ERROR:  permission denied for table transaction
  ```

### Test 1.9: Alter Table / DDL Operations (Denied)

- **SQL Statement:**
  ```sql
  DROP TABLE payment;
  ```
- **Expected Result:** Denied; DDL requires object ownership.
- **Actual Result / Output:**
  ```text
  ERROR:  must be owner of table payment
  ```

---

## 1.4 Verification Results: Test Suite 2 (Read-Only / Auditor User `parkit_report`)

### Test 2.1: Read Transactions and Joined Data (Allowed)

- **SQL Statement:**
  ```sql
  SELECT t.transaction_id, v.license_plate, z.zone_name, t.status, p.amount, p.payment_method
  FROM transaction t
  JOIN vehicle v ON t.vehicle_id = v.vehicle_id
  JOIN parking_zone z ON t.zone_id = z.zone_id
  LEFT JOIN payment p ON t.transaction_id = p.transaction_id
  ORDER BY t.transaction_id
  LIMIT 5;
  ```
- **Expected Result:** Allowed; auditor inspection query executes successfully.
- **Actual Result / Output:**
  ```text
   transaction_id | license_plate |        zone_name         |  status   | amount | payment_method
  ----------------+---------------+--------------------------+-----------+--------+----------------
                1 | ABC-1234      | North Open Lot           | Completed |  80.00 | Cash
                2 | XYZ-7890      | South Multi-Level Garage | Completed | 140.00 | GCash
                3 | NCR-4567      | North Open Lot           | Active    |        |
                4 | WXY-9988      | East Faculty Annex       | Completed | 120.00 | Card
                5 | DL-5521       | South Multi-Level Garage | Active    |        |
  (5 rows)
  ```

### Test 2.2: Attempt to Read User Credentials (Denied — Credential Protection)

- **SQL Statement:**
  ```sql
  SELECT * FROM staff_user;
  ```
- **Expected Result:** Denied; auditor role has no `SELECT` privilege on `staff_user` to safeguard password hashes.
- **Actual Result / Output:**
  ```text
  ERROR:  permission denied for table staff_user
  ```

### Test 2.3: Attempt to Insert Data (Denied)

- **SQL Statement:**
  ```sql
  INSERT INTO parking_zone (zone_name, max_capacity, current_active_count) VALUES ('Auditor Rogue Zone', 10, 0);
  ```
- **Expected Result:** Denied; read-only account cannot insert data.
- **Actual Result / Output:**
  ```text
  ERROR:  permission denied for table parking_zone
  ```

### Test 2.4: Attempt to Update Records (Denied)

- **SQL Statement:**
  ```sql
  UPDATE parking_zone SET max_capacity = 999 WHERE zone_id = 1;
  ```
- **Expected Result:** Denied; read-only account cannot alter zone capacities.
- **Actual Result / Output:**
  ```text
  ERROR:  permission denied for table parking_zone
  ```

### Test 2.5: Attempt to Delete Records (Denied)

- **SQL Statement:**
  ```sql
  DELETE FROM transaction WHERE transaction_id = 1;
  ```
- **Expected Result:** Denied; read-only account cannot delete transaction records.
- **Actual Result / Output:**
  ```text
  ERROR:  permission denied for table transaction
  ```

---

## 1.5 Verification Results: Test Suite 3 (Cross-Database & Administrative Boundary)

### Test 3.1: Attempt to Create a Database (Denied)

- **SQL Statement:**
  ```sql
  CREATE DATABASE rogue_test_db;
  ```
- **Expected Result:** Denied; application users must not possess administrative `CREATEDB` privileges.
- **Actual Result / Output:**
  ```text
  ERROR:  permission denied to create database
  ```

### Test 3.2: Attempt to Connect to Unrelated Database (Denied)

- **Command:**
  ```bash
  psql -U parkit_app -h localhost -p 5432 -d grp07_campussafedb -c "SELECT 1;"
  ```
- **Expected Result:** Denied; cross-database connection is blocked by revoked PUBLIC privileges.
- **Actual Result / Output:**
  ```text
  psql: error: connection to server at "localhost" (::1), port 5432 failed: FATAL:  permission denied for database "grp07_campussafedb"
  DETAIL:  User does not have CONNECT privilege.
  ```

---

## 1.6 Issues, Fixes, and Feedback to Owners

### Issues and Fixes Encountered

1. **Initial Seed Script Coverage:** The repository's `seed.sql` provided only a single sample row for `parking_zone` and omitted sample data for `vehicle`, `staff_user`, `transaction`, and `payment`. We synthesized a full relational dataset populating all 5 tables so that foreign keys, joined analytics, and query execution plans could be verified accurately.
2. **Node.js Environment Variable Configuration:** In `park-it-database/.env`, `DB_USER` defaults to `postgres`. We verified that switching `.env` to `DB_USER=parkit_app` and `DB_PASSWORD=AppRuntimePass2026!` executes API routes (`/api/test`, `/api/zones`, `/api/zones/:id/park`) seamlessly.
3. **Capacity Check Constraint:** `parking_zone` enforces `CHECK (current_active_count <= max_capacity)`. In `server.js`, an application-layer check exists, and the database-level constraint provides defense-in-depth against race conditions.

### Feedback to Owning Group (Group 2: Park-It)

- **Commendation:** The relational schema design captures core parking operations cleanly. The `CHECK (current_active_count <= max_capacity)` constraint on `parking_zone` and `CHECK (amount >= 0)` on `payment` guarantee data validity at the database engine level. The Express REST API endpoints in `server.js` use parameterized SQL queries (`$1, $2, ...`), preventing SQL injection.
- **Recommendation 1:** Expand `seed.sql` to include sample vehicles, attendant users, transactions, and payments so that new evaluators can test the complete system lifecycle without manual database seeding.
- **Recommendation 2:** Add foreign key indexes on `transaction (vehicle_id)`, `transaction (zone_id)`, and `payment (transaction_id)`. Although primary key indexes exist, foreign key columns lack indexes by default in PostgreSQL, which can lead to sequential scans during cascading operations and large-scale joins.

---

# ACTIVITY 5: Database Maintenance and Monitoring

## 2.1 Database Health & Overview Inspection

### Queries Executed

```sql
-- 1. PostgreSQL Engine Version
SELECT version() AS postgresql_version;

-- 2. Current Database & Active User
SELECT current_database() AS database_name, current_user AS connected_user;

-- 3. Database Total Size on Disk
SELECT pg_size_pretty(pg_database_size(current_database())) AS total_db_size;

-- 4. Table Inventory and Individual Table Sizes
SELECT
    table_name,
    pg_size_pretty(pg_total_relation_size(quote_ident(table_name))) AS total_size,
    pg_size_pretty(pg_relation_size(quote_ident(table_name))) AS table_size,
    pg_size_pretty(pg_indexes_size(quote_ident(table_name))) AS index_size
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
ORDER BY pg_total_relation_size(quote_ident(table_name)) DESC;

-- 5. Total Number of Tables and Sequences
SELECT
    (SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public') AS total_tables,
    (SELECT count(*) FROM information_schema.sequences WHERE sequence_schema = 'public') AS total_sequences;
```

### Actual Output

- **PostgreSQL Version:** `PostgreSQL 18.6 on x86_64-windows, compiled by msvc-19.44.35229, 64-bit`
- **Total Database Size:** `8438 kB` (~8.4 MB)
- **Object Count:** `total_tables: 5`, `total_sequences: 5`
- **Table Storage Breakdown:**
  ```text
    table_name  | total_size | table_size | index_size
  --------------+------------+------------+------------
   vehicle      | 40 kB      | 8192 bytes | 32 kB
   staff_user   | 40 kB      | 8192 bytes | 32 kB
   payment      | 40 kB      | 8192 bytes | 32 kB
   parking_zone | 40 kB      | 8192 bytes | 32 kB
   transaction  | 24 kB      | 8192 bytes | 16 kB
  (5 rows)
  ```

---

## 2.2 Connection, Session & Activity Monitoring

### Queries Executed

```sql
-- 1. Database Connection and Transaction Metrics
SELECT
    datname,
    numbackends AS open_connections,
    xact_commit AS committed_transactions,
    xact_rollback AS rolled_back_transactions,
    conflicts,
    deadlocks
FROM pg_stat_database
WHERE datname = current_database();

-- 2. Inspect Active Sessions
SELECT
    pid, usename, client_addr, application_name, state,
    wait_event_type, wait_event, query_start, query
FROM pg_stat_activity
WHERE datname = current_database()
ORDER BY query_start NULLS LAST;

-- 3. Verify Activity 4 Roles Configuration
SELECT
    r.rolname AS role_name,
    r.rolcanlogin AS can_login,
    r.rolsuper AS is_superuser,
    ARRAY(
        SELECT b.rolname
        FROM pg_auth_members m
        JOIN pg_roles b ON (m.roleid = b.oid)
        WHERE m.member = r.oid
    ) AS member_of_group
FROM pg_roles r
WHERE r.rolname IN ('postgres', 'parkit_app', 'parkit_report', 'parkit_backup', 'parkit_runtime_grp', 'parkit_readonly_grp', 'parkit_backup_grp')
ORDER BY r.rolname;
```

### Actual Output

- **Database Statistics:**
  ```text
     datname    | open_connections | committed_transactions | rolled_back_transactions | conflicts | deadlocks
  --------------+------------------+------------------------+--------------------------+-----------+-----------
   grp_parkitdb |                1 |                     82 |                        9 |         0 |         0
  ```
  _Analysis:_ `conflicts = 0`, `deadlocks = 0`. The 9 rolled back transactions correspond exactly to the intentional permission-denied tests executed during Activity 4 verification, confirming clean transaction isolation.
- **Roles Verification Output:**
  ```text
        role_name      | can_login | is_superuser |    member_of_group
  ---------------------+-----------+--------------+-----------------------
   parkit_app          | t         | f            | {parkit_runtime_grp}
   parkit_backup       | t         | f            | {parkit_backup_grp}
   parkit_backup_grp   | f         | f            | {}
   parkit_readonly_grp | f         | f            | {}
   parkit_report       | t         | f            | {parkit_readonly_grp}
   parkit_runtime_grp  | f         | f            | {}
   postgres            | t         | t            | {}
  (7 rows)
  ```

---

## 2.3 Table Statistics & Bloat Inspection

### Query Executed

```sql
SELECT
    relname AS table_name,
    seq_scan AS sequential_scans,
    seq_tup_read AS tuples_read_by_seq_scan,
    idx_scan AS index_scans,
    n_live_tup AS live_tuples,
    n_dead_tup AS dead_tuples,
    last_vacuum, last_autovacuum, last_analyze, last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;
```

### Actual Output

```text
  table_name  | sequential_scans | tuples_read_by_seq_scan | index_scans | live_tuples | dead_tuples | last_vacuum | last_autovacuum | last_analyze | last_autoanalyze
--------------+------------------+-------------------------+-------------+-------------+-------------+-------------+-----------------+--------------+------------------
 parking_zone |                3 |                       8 |          18 |           4 |           2 |             |                 |              |
 vehicle      |                2 |                       5 |          16 |           5 |           0 |             |                 |              |
 transaction  |                3 |                      10 |           6 |           6 |           0 |             |                 |              |
 payment      |                2 |                       3 |           4 |           4 |           0 |             |                 |              |
 staff_user   |                2 |                       3 |           3 |           3 |           0 |             |                 |              |
(5 rows)
```

_Analysis:_ `parking_zone` accumulated 2 dead tuples as a direct result of the update and delete operations executed during Activity 4 testing. Routine `VACUUM` was warranted to reclaim those dead tuple slots.

---

## 2.4 Log Review & Issue Identification

### PostgreSQL Log Analysis (`D:\Postgre\data\log\postgresql-2026-11-05_104510.log`)

1. **Activity 4 Security Enforcement Interceptions:**
   - **Log Entry:** `ERROR: permission denied for table payment STATEMENT: UPDATE payment SET amount = 0.00 WHERE transaction_id = 1;` by `parkit_app`
   - **Log Entry:** `ERROR: permission denied for table payment STATEMENT: DELETE FROM payment WHERE payment_id = 1;` by `parkit_app`
   - **Log Entry:** `ERROR: permission denied for table transaction STATEMENT: DELETE FROM transaction WHERE transaction_id = 1;` by `parkit_app`
   - **Log Entry:** `ERROR: must be owner of table payment STATEMENT: DROP TABLE payment;` by `parkit_app`
   - **Log Entry:** `ERROR: permission denied for table staff_user STATEMENT: SELECT * FROM staff_user;` by `parkit_report`
   - **Log Entry:** `ERROR: permission denied for table parking_zone STATEMENT: INSERT INTO parking_zone (zone_name, max_capacity, current_active_count) VALUES ('Auditor Rogue Zone', 10, 0);` by `parkit_report`
   - **Log Entry:** `ERROR: permission denied for table parking_zone STATEMENT: UPDATE parking_zone SET max_capacity = 999 WHERE zone_id = 1;` by `parkit_report`
   - **Log Entry:** `ERROR: permission denied for table transaction STATEMENT: DELETE FROM transaction WHERE transaction_id = 1;` by `parkit_report`
   - **Log Entry:** `ERROR: permission denied to create database STATEMENT: CREATE DATABASE rogue_test_db;` by `parkit_app`
   - **Log Entry:** `FATAL: permission denied for database "grp07_campussafedb" DETAIL: User does not have CONNECT privilege.` on connection by `parkit_app`
   - **Assessment:** Positive validation of the Least Privilege policy. Every unauthorized DDL, DML mutation, and cross-database breach attempted during Activity 4 testing was intercepted and logged by PostgreSQL.
2. **Checkpoint & Background Writer Health:** Background checkpoints logged clean completions (e.g. `checkpoint complete: wrote 66 buffers (0.4%), write=7.223 s, sync=0.019 s, total=7.253 s`).
3. **Engine Health:** No unhandled crashes, transaction wraparound alerts, or disk I/O corruptions exist in the active log.

---

## 2.5 Routine Maintenance Operations (`ANALYZE` & `VACUUM`)

### Maintenance Commands Executed

```sql
-- Standalone maintenance execution as superuser / owner:
ANALYZE;
VACUUM (VERBOSE, ANALYZE) public.parking_zone;
VACUUM (VERBOSE, ANALYZE) public.transaction;
VACUUM (VERBOSE, ANALYZE) public.payment;
```

### Actual Output

- **Permission Boundary Test:** Running `VACUUM parking_zone;` as `parkit_app` produced:
  ```text
  WARNING:  permission denied to vacuum "parking_zone", skipping it
  VACUUM
  ```
  This proves that runtime application accounts cannot perform maintenance operations.
- **`ANALYZE;` Output:**
  ```text
  ANALYZE
  ```
- **`VACUUM (VERBOSE, ANALYZE) public.parking_zone;` Output:**
  ```text
  INFO:  vacuuming "grp_parkitdb.public.parking_zone"
  INFO:  finished vacuuming "grp_parkitdb.public.parking_zone": index scans: 1
  pages: 0 removed, 1 remain, 1 scanned (100.00% of total), 0 eagerly scanned
  tuples: 2 removed, 4 remain, 0 are dead but not yet removable
  removable cutoff: 1117, which was 0 XIDs old when operation ended
  new relfrozenxid: 1035, which is 173 XIDs ahead of previous value
  visibility map: 1 pages set all-visible, 0 pages set all-frozen (0 were all-visible)
  buffer usage: 76 hits, 0 reads, 6 dirtied
  WAL usage: 9 records, 6 full page images, 33848 bytes, 0 buffers full
  INFO:  analyzing "public.parking_zone"
  INFO:  "parking_zone": scanned 1 of 1 pages, containing 4 live rows and 0 dead rows; 4 rows in sample, 4 estimated total rows
  VACUUM
  ```
- **`VACUUM (VERBOSE, ANALYZE) public.transaction;` Output:**
  ```text
  INFO:  vacuuming "grp_parkitdb.public.transaction"
  INFO:  finished vacuuming "grp_parkitdb.public.transaction": index scans: 0
  pages: 0 removed, 1 remain, 1 scanned (100.00% of total), 0 eagerly scanned
  tuples: 0 removed, 6 remain, 0 are dead but not yet removable
  removable cutoff: 1118, which was 0 XIDs old when operation ended
  visibility map: 1 pages set all-visible, 0 pages set all-frozen (0 were all-visible)
  buffer usage: 65 hits, 0 reads, 4 dirtied
  INFO:  analyzing "public.transaction"
  INFO:  "transaction": scanned 1 of 1 pages, containing 6 live rows and 0 dead rows; 6 rows in sample, 6 estimated total rows
  VACUUM
  ```
- **`VACUUM (VERBOSE, ANALYZE) public.payment;` Output:**
  ```text
  INFO:  vacuuming "grp_parkitdb.public.payment"
  INFO:  finished vacuuming "grp_parkitdb.public.payment": index scans: 0
  pages: 0 removed, 1 remain, 1 scanned (100.00% of total), 0 eagerly scanned
  tuples: 0 removed, 4 remain, 0 are dead but not yet removable
  removable cutoff: 1119, which was 0 XIDs old when operation ended
  visibility map: 1 pages set all-visible, 0 pages set all-frozen (0 were all-visible)
  buffer usage: 75 hits, 0 reads, 5 dirtied
  INFO:  analyzing "public.payment"
  INFO:  "payment": scanned 1 of 1 pages, containing 4 live rows and 0 dead rows; 4 rows in sample, 4 estimated total rows
  VACUUM
  ```

### DBA Justification on Role Permissions & Exclusion of `VACUUM FULL`

- **Role Permission Boundary:** `VACUUM` requires table ownership. Attempting it under `parkit_app` resulted in a permission denial, confirming that routine maintenance must be orchestrated by a designated maintenance or administrative account (`postgres`).
- **Exclusion of `VACUUM FULL`:** `VACUUM FULL` rewrites entire table files and acquires an `AccessExclusiveLock`, blocking concurrent SELECT and INSERT queries at parking gates. Because Park-It tables fit inside single 8 kB heap pages, standard non-blocking `VACUUM` reclaimed all dead tuples (`2 removed` in `parking_zone`) with zero system downtime.

---

## 2.6 Query Performance Analysis (`EXPLAIN` & `EXPLAIN (ANALYZE, BUFFERS)`)

### Query 1: Active Parking Sessions by Zone and Recency

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    t.transaction_id,
    v.license_plate,
    v.vehicle_type,
    z.zone_name,
    t.entry_time,
    t.status
FROM transaction t
JOIN vehicle v ON t.vehicle_id = v.vehicle_id
JOIN parking_zone z ON t.zone_id = z.zone_id
WHERE t.status = 'Active'
ORDER BY t.entry_time DESC;
```

#### Actual Execution Plan Output

```text
                                                          QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------------
 Sort  (cost=3.34..3.35 rows=3 width=53) (actual time=0.125..0.127 rows=3.00 loops=1)
   Sort Key: t.entry_time DESC
   Sort Method: quicksort  Memory: 25kB
   Buffers: shared hit=6
   ->  Hash Join  (cost=2.20..3.32 rows=3 width=53) (actual time=0.082..0.086 rows=3.00 loops=1)
         Hash Cond: (t.zone_id = z.zone_id)
         Buffers: shared hit=3
         ->  Hash Join  (cost=1.11..2.21 rows=3 width=38) (actual time=0.039..0.042 rows=3.00 loops=1)
               Hash Cond: (t.vehicle_id = v.vehicle_id)
               Buffers: shared hit=2
               ->  Seq Scan on transaction t  (cost=0.00..1.07 rows=3 width=28) (actual time=0.011..0.012 rows=3.00 loops=1)
                     Filter: ((status)::text = 'Active'::text)
                     Rows Removed by Filter: 3
                     Buffers: shared hit=1
               ->  Hash  (cost=1.05..1.05 rows=5 width=18) (actual time=0.017..0.017 rows=5.00 loops=1)
                     Buckets: 1024  Batches: 1  Memory Usage: 9kB
                     Buffers: shared hit=1
                     ->  Seq Scan on vehicle v  (cost=0.00..1.05 rows=5 width=18) (actual time=0.006..0.007 rows=5.00 loops=1)
                           Buffers: shared hit=1
         ->  Hash  (cost=1.04..1.04 rows=4 width=23) (actual time=0.036..0.036 rows=4.00 loops=1)
               Buckets: 1024  Batches: 1  Memory Usage: 9kB
               Buffers: shared hit=1
               ->  Seq Scan on parking_zone z  (cost=0.00..1.04 rows=4 width=23) (actual time=0.024..0.025 rows=4.00 loops=1)
                     Buffers: shared hit=1
 Planning:
   Buffers: shared hit=283
 Planning Time: 6.707 ms
 Execution Time: 0.216 ms
(28 rows)
```

#### Interpretation

1. **Execution Time:** `0.216 ms` (sub-millisecond execution).
2. **Buffer Efficiency:** `shared hit = 6`, with 0 physical disk block reads (100% in-memory cache hit).
3. **Sequential Scan & Join Strategy:** The planner constructed two chained `Hash Joins` in memory with zero disk spills (`Batches: 1`). Sequential scans were selected because each table occupies a single 8 kB heap block (`Buffers: shared hit = 1`), making direct memory scans cheaper than traversing index pages.

---

### Query 2: Daily Parking Revenue & Collections by Payment Method

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    p.payment_method,
    count(p.payment_id) AS total_payments,
    sum(p.amount) AS total_revenue,
    avg(p.amount) AS avg_fee
FROM payment p
JOIN transaction t ON p.transaction_id = t.transaction_id
WHERE p.payment_time >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY p.payment_method
ORDER BY total_revenue DESC;
```

#### Actual Execution Plan Output

```text
                                                          QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------------
 Sort  (cost=2.31..2.31 rows=3 width=77) (actual time=0.091..0.092 rows=3.00 loops=1)
   Sort Key: (sum(p.amount)) DESC
   Sort Method: quicksort  Memory: 25kB
   Buffers: shared hit=5
   ->  HashAggregate  (cost=2.24..2.28 rows=3 width=77) (actual time=0.067..0.070 rows=3.00 loops=1)
         Group Key: p.payment_method
         Batches: 1  Memory Usage: 32kB
         Buffers: shared hit=2
         ->  Hash Join  (cost=1.12..2.21 rows=4 width=14) (actual time=0.039..0.042 rows=4.00 loops=1)
               Hash Cond: (t.transaction_id = p.transaction_id)
               Buffers: shared hit=2
               ->  Seq Scan on transaction t  (cost=0.00..1.06 rows=6 width=4) (actual time=0.016..0.016 rows=6.00 loops=1)
                     Buffers: shared hit=1
               ->  Hash  (cost=1.07..1.07 rows=4 width=18) (actual time=0.014..0.014 rows=4.00 loops=1)
                     Buckets: 1024  Batches: 1  Memory Usage: 9kB
                     Buffers: shared hit=1
                     ->  Seq Scan on payment p  (cost=0.00..1.07 rows=4 width=18) (actual time=0.008..0.009 rows=4.00 loops=1)
                           Filter: (payment_time >= (CURRENT_DATE - '7 days'::interval))
                           Buffers: shared hit=1
 Planning:
   Buffers: shared hit=262
 Planning Time: 3.843 ms
 Execution Time: 0.162 ms
(23 rows)
```

#### Interpretation

1. **Execution Time:** `0.162 ms`.
2. **Buffer Hits:** `shared hit = 5` (100% cache hit, 0 physical disk reads during execution).
3. **Aggregation Strategy:** Executed via an in-memory `HashAggregate` (32 kB memory usage) following a `Hash Join` between `transaction` and `payment`, with in-memory quicksort on `total_revenue DESC`.

---

## 2.7 Prioritized Recommendations & Technical Justification

| Priority            | Action Item                                         | Technical Justification                                                                                                                                                                                                                                                                         |
| ------------------- | --------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **High Priority**   | Create Foreign Key Index on `transaction (zone_id)` | Foreign keys do not automatically create indexes in PostgreSQL. When scaling to thousands of parking sessions, zone-level aggregation and vehicle lookup queries will scan the entire `transaction` table without this index: `CREATE INDEX idx_transaction_zone_id ON transaction (zone_id);`. |
| **High Priority**   | Create Index on `transaction (entry_time)`          | Parking audits and peak-hour utilization reports filter heavily on entry timestamps. An index enables index range scans: `CREATE INDEX idx_transaction_entry_time ON transaction (entry_time);`.                                                                                                |
| **Medium Priority** | Automated Maintenance Script via Task Scheduler     | Deploy a scheduled weekly maintenance job invoking `VACUUM (ANALYZE)` during off-hours (e.g. Sunday 03:00 AM) to reclaim dead tuples generated by continuous zone parking count updates (`UPDATE parking_zone SET current_active_count = ...`).                                                 |

---

# ACTIVITY 6: Database Backup, Restoration, and Recovery

## 3.1 Backup Planning & Architecture

### Strategy Matrix

| Parameter                        | Plan for `grp_parkitdb`                                                                                                                                                                                                     | Technical Justification                                                                                                                                                                                   |
| -------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Target Database & Objects**    | `grp_parkitdb` (Schema: `public`)<br>• 5 Relational Tables: `parking_zone`, `vehicle`, `staff_user`, `transaction`, `payment`<br>• 5 Sequences, Primary Keys, Foreign Keys, Unique/Check Constraints, Indexes, Table Grants | Full consistency across parking zones, registered vehicles, staff attendants, parking transit transactions, and financial fee payments.                                                                   |
| **Backup Format**                | **PostgreSQL Custom Archive Format (`-Fc` / Custom)**                                                                                                                                                                       | Compressed binary format; supports selective table-level restoration and parallel processing via `pg_restore`.                                                                                            |
| **Storage & Security**           | Dedicated protected directory: `C:\Users\jorpe\OneDrive\Documents\pg_backups\`<br>Filename: `grp_parkitdb_activity6.dump`                                                                                                   | Restricted to database administrators. Kept out of web roots and excluded from Git commits via `.gitignore`.                                                                                              |
| **RPO & RTO**                    | **RPO (Recovery Point Objective):** 24 Hours<br>**RTO (Recovery Time Objective):** 2 Hours                                                                                                                                  | Daily dumps at 01:00 AM are sufficient for standard campus/facility parking volumes. RTO of 2 hours provides ample buffer to provision a standby instance, restore schemas, and repoint application DSNs. |
| **Retention Policy**             | 7 Daily Backups + 4 Weekly Snapshots                                                                                                                                                                                        | Balances disk consumption with multi-week disaster recovery compliance.                                                                                                                                   |
| **Activity 4 Roles Re-creation** | PostgreSQL roles (`parkit_app`, `parkit_report`, `parkit_backup`) are **cluster-wide** and are **not** stored inside a single-database dump.                                                                                | On a new server instance, Activity 4 role scripts (`01_roles_and_grants.sql`) must run **prior** to or immediately following restore to ensure object ownership and ACLs attach cleanly.                  |

---

## 3.2 Backup Creation, Checksum & Archive Inspection

### Backup Execution

Executed using `pg_dump` with custom archive format (`-Fc`) using the dedicated `parkit_backup` role:

```bash
pg_dump -U parkit_backup -h localhost -p 5432 -Fc -d grp_parkitdb -f "C:\Users\jorpe\OneDrive\Documents\pg_backups\grp_parkitdb_activity6.dump"
```

### File Metadata & Checksum Verification (PowerShell)

- **PowerShell Commands:**
  ```powershell
  Get-FileHash -Path "C:\Users\jorpe\OneDrive\Documents\pg_backups\grp_parkitdb_activity6.dump" -Algorithm SHA256 | Format-List
  Get-Item "C:\Users\jorpe\OneDrive\Documents\pg_backups\grp_parkitdb_activity6.dump" | Select-Object Name, Length, LastWriteTime
  ```
- **Recorded Details:**

  ```text
  Algorithm : SHA256
  Hash      : 640C0F8275E6D0193213709F4FD48E422984B8299E868E18B84EE476DAC58610
  Path      : C:\Users\jorpe\OneDrive\Documents\pg_backups\grp_parkitdb_activity6.dump

  Name                        Length LastWriteTime
  ----                        ------ -------------
  grp_parkitdb_activity6.dump  20611 11/5/2026 4:55:10 PM
  ```

### Archive Inspection (`pg_restore --list`)

Inspecting the archive table of contents (`pg_restore --list`) confirmed **61 TOC entries**, including all 5 tables (`parking_zone`, `payment`, `staff_user`, `transaction`, `vehicle`), 5 sequences, primary keys, check constraints, foreign keys, unique indexes, and ACL grants.

_DBA Justification:_ An archive file existing on disk is not proof of recoverability. Physical corruption, missing dependencies, or incompatible cluster versions can cause silent failures. A complete restore drill into an isolated environment is required.

---

## 3.3 Restoration into Separate Test Database (`grp_parkitdb_restore_test`)

1. **Created Test Database:**
   ```bash
   createdb -U postgres -h localhost -p 5432 grp_parkitdb_restore_test
   ```
2. **Restored Backup Archive:**
   ```bash
   pg_restore -U postgres -h localhost -p 5432 -d grp_parkitdb_restore_test "C:\Users\jorpe\OneDrive\Documents\pg_backups\grp_parkitdb_activity6.dump"
   ```
   _Outcome:_ Executed cleanly with exit code 0.

---

## 3.4 Post-Restore Verification Suite

### 1. Verify All 5 Tables Exist and Check Table Ownership

- **Query:**
  ```sql
  SELECT
      table_name,
      table_type,
      (SELECT tableowner FROM pg_tables WHERE tablename = t.table_name) AS owner
  FROM information_schema.tables t
  WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
  ORDER BY table_name;
  ```
- **Actual Output:**
  ```text
    table_name  | table_type |  owner
  --------------+------------+----------
   parking_zone | BASE TABLE | postgres
   payment      | BASE TABLE | postgres
   staff_user   | BASE TABLE | postgres
   transaction  | BASE TABLE | postgres
   vehicle      | BASE TABLE | postgres
  (5 rows)
  ```

### 2. Verify Record Counts Across All Tables

- **Query:**
  ```sql
  SELECT 'parking_zone' AS tbl, count(*) FROM parking_zone
  UNION ALL SELECT 'vehicle', count(*) FROM vehicle
  UNION ALL SELECT 'staff_user', count(*) FROM staff_user
  UNION ALL SELECT 'transaction', count(*) FROM transaction
  UNION ALL SELECT 'payment', count(*) FROM payment;
  ```
- **Actual Output:**
  ```text
       tbl      | count
  --------------+-------
   parking_zone |     4
   vehicle      |     5
   staff_user   |     3
   transaction  |     6
   payment      |     4
  (5 rows)
  ```
  _Analysis:_ Record counts match the source database 100%.

### 3. Verify Activity 4 Access Control on Restored Database

- **Runtime User Test (`parkit_app`):**
  ```bash
  psql -U parkit_app -h localhost -p 5432 -d grp_parkitdb_restore_test -c "SELECT zone_id, zone_name, max_capacity FROM parking_zone LIMIT 3;"
  ```
  _Output:_
  ```text
   zone_id |        zone_name         | max_capacity
  ---------+--------------------------+--------------
         1 | North Open Lot           |           50
         2 | South Multi-Level Garage |          120
         3 | East Faculty Annex       |           40
  (3 rows)
  ```
- **Runtime Restriction Test (`parkit_app` attempting to update `payment`):**
  ```bash
  psql -U parkit_app -h localhost -p 5432 -d grp_parkitdb_restore_test -c "UPDATE payment SET amount = 0.00 WHERE payment_id = 1;"
  ```
  _Output:_
  ```text
  ERROR:  permission denied for table payment
  ```
- **Auditor Read Test (`parkit_report` reading transactions):**
  ```bash
  psql -U parkit_report -h localhost -p 5432 -d grp_parkitdb_restore_test -c "SELECT t.transaction_id, v.license_plate, z.zone_name FROM transaction t JOIN vehicle v ON t.vehicle_id = v.vehicle_id JOIN parking_zone z ON t.zone_id = z.zone_id LIMIT 3;"
  ```
  _Output:_
  ```text
   transaction_id | license_plate |        zone_name
  ----------------+---------------+--------------------------
                1 | ABC-1234      | North Open Lot
                2 | XYZ-7890      | South Multi-Level Garage
                3 | NCR-4567      | North Open Lot
  (3 rows)
  ```
- **Auditor Restriction Test (`parkit_report` attempting to read `staff_user` credentials):**
  ```bash
  psql -U parkit_report -h localhost -p 5432 -d grp_parkitdb_restore_test -c "SELECT * FROM staff_user;"
  ```
  _Output:_
  ```text
  ERROR:  permission denied for table staff_user
  ```
  _Conclusion:_ Least-privilege ACLs, sequence privileges, and financial immutability transferred seamlessly into the restored database.

---

## 3.5 Controlled Recovery Simulation (Incident & Recovery Drill)

### Step 1: Pre-Incident Baseline State

In `grp_parkitdb_restore_test`, a disposable test vehicle, parking transaction, and payment record were established:

- **Query:**

  ```sql
  INSERT INTO vehicle (vehicle_id, license_plate, vehicle_type) VALUES (999, 'DRILL-999', 'Coupe');
  INSERT INTO transaction (transaction_id, vehicle_id, zone_id, entry_time, status)
  VALUES (999, 999, 1, CURRENT_TIMESTAMP, 'Active');
  INSERT INTO payment (payment_id, transaction_id, amount, payment_method, payment_time)
  VALUES (999, 999, 95.00, 'Cash', CURRENT_TIMESTAMP);

  SELECT t.transaction_id, v.license_plate, z.zone_name, p.amount, p.payment_method, t.entry_time
  FROM transaction t
  JOIN vehicle v ON t.vehicle_id = v.vehicle_id
  JOIN parking_zone z ON t.zone_id = z.zone_id
  JOIN payment p ON t.transaction_id = p.transaction_id
  WHERE t.transaction_id = 999;
  ```

- **Actual Output:**
  ```text
   transaction_id | license_plate |   zone_name    | amount | payment_method |         entry_time
  ----------------+---------------+----------------+--------+----------------+----------------------------
              999 | DRILL-999     | North Open Lot |  95.00 | Cash           | 2026-11-05 16:56:39.027748
  (1 row)
  ```

### Step 2: Simulated Data-Loss Incident

Accidental catastrophic deletion was simulated across dependent tables:

- **Query:**
  ```sql
  DELETE FROM payment WHERE payment_id = 999;
  DELETE FROM transaction WHERE transaction_id = 999;
  DELETE FROM vehicle WHERE vehicle_id = 999;
  SELECT count(*) AS count_after_deletion FROM transaction WHERE transaction_id = 999;
  ```
- **Actual Output:**
  ```text
  DELETE 1
  DELETE 1
  DELETE 1
   count_after_deletion
  ----------------------
                      0
  (1 row)
  ```
  _Observation:_ Record `999` is missing; data loss confirmed.

### Step 3: Targeted Recovery

Targeted restoration was executed to reinstate the records from baseline:

- **Query:**

  ```sql
  INSERT INTO vehicle (vehicle_id, license_plate, vehicle_type) VALUES (999, 'DRILL-999', 'Coupe')
  ON CONFLICT (vehicle_id) DO NOTHING;

  INSERT INTO transaction (transaction_id, vehicle_id, zone_id, entry_time, status)
  VALUES (999, 999, 1, '2026-11-05 16:56:39.027748', 'Active')
  ON CONFLICT (transaction_id) DO NOTHING;

  INSERT INTO payment (payment_id, transaction_id, amount, payment_method, payment_time)
  VALUES (999, 999, 95.00, 'Cash', '2026-11-05 16:56:39.027748')
  ON CONFLICT (payment_id) DO NOTHING;

  SELECT t.transaction_id, v.license_plate, z.zone_name, p.amount, p.payment_method, t.entry_time
  FROM transaction t
  JOIN vehicle v ON t.vehicle_id = v.vehicle_id
  JOIN parking_zone z ON t.zone_id = z.zone_id
  JOIN payment p ON t.transaction_id = p.transaction_id
  WHERE t.transaction_id = 999;
  ```

- **Actual Output:**
  ```text
   transaction_id | license_plate |   zone_name    | amount | payment_method |         entry_time
  ----------------+---------------+----------------+--------+----------------+----------------------------
              999 | DRILL-999     | North Open Lot |  95.00 | Cash           | 2026-11-05 16:56:39.027748
  (1 row)
  ```

### Step 4: Post-Recovery Verification and Drill Cleanup

The vehicle, transaction, and payment records were verified intact with original entry timestamp, fee amount, and payment method preserved. The drill records were subsequently cleaned up:

```sql
DELETE FROM payment WHERE payment_id = 999;
DELETE FROM transaction WHERE transaction_id = 999;
DELETE FROM vehicle WHERE vehicle_id = 999;
```

---

## 3.6 Limitations, Evaluation & Production Recommendations

### Post-Restore Considerations

1. **Cluster-Wide Roles Dependency:** Single-database dumps do not store database user roles. If restoring to a brand-new PostgreSQL server instance, `db-access-control/group-02-parkit/01_roles_and_grants.sql` must be applied to define `parkit_runtime_grp`, `parkit_app`, `parkit_report`, etc., before permissions can attach.
2. **Production Backup Recommendations:**
   - **Automated Nightly Dumps:** Configure a scheduled PowerShell script via Windows Task Scheduler to execute `pg_dump -Fc` nightly at 01:00 AM, appending the ISO date (`grp_parkitdb_YYYY-MM-DD.dump`) and purging backups older than 14 days.
   - **Continuous WAL Archiving (PITR):** For large commercial multi-gate parking garages where payment disputes or equipment malfunctions can occur throughout the day, configure Write-Ahead Logging (`archive_mode = on`) to achieve sub-minute Point-in-Time Recovery.

---

# CONSOLIDATED CLASS GOOGLE SHEETS TRACKER ENTRIES

Below are the exact values to record in the class Google Sheets tracker:

### Activity 4 Log Tab

| Column Header                  | Value                                                                                                   |
| ------------------------------ | ------------------------------------------------------------------------------------------------------- |
| **Project**                    | Group 2 - Park-It: Parking Management System                                                            |
| **Repository cloned**          | `https://github.com/millerdevera6-glitch/park-it-database`, Branch: `main`                              |
| **Database setup result**      | Success (Verified PostgreSQL 18.6 on port 5432, executed schema DDL and seed data, 5 tables loaded).    |
| **Access-control folder link** | `https://github.com/jeffersonorpesa2-ops/grp07-campussafe/tree/main/db-access-control/group-02-parkit/` |
| **Access-control status**      | Completed                                                                                               |
| **Feedback sent to owners**    | (05/11/2026)                                                                                            |
| **PDF progress document**      |                                                                                                         |
| **Last updated**               | 2026-11-05                                                                                              |

### Activity 5 Log Tab

| Column Header               | Value                                                                                                                       |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| **Project**                 | Group 2 - Park-It: Parking Management System                                                                                |
| **Database inspected**      | `grp_parkitdb` (PostgreSQL 18.6)                                                                                            |
| **Account and role used**   | `postgres` (DBA Maintenance), `parkit_app` (Runtime), `parkit_report` (Audit)                                               |
| **Health check result**     | Healthy (0 conflicts, 0 deadlocks, 8.4 MB footprint, 100% buffer cache hits)                                                |
| **Maintenance performed**   | `ANALYZE; VACUUM (VERBOSE, ANALYZE) on parking_zone, transaction, payment via postgres`                                     |
| **Query analyzed**          | Active sessions filter and sort (Hash join/quicksort, 0.216 ms, 6 buffer hits) & Revenue summary (Hash aggregate, 0.162 ms) |
| **Recommendation priority** | High priority (Add indexes on `transaction (zone_id)` and `transaction (entry_time)` for scale)                             |
| **Evidence folder link**    | `https://github.com/jeffersonorpesa2-ops/grp07-campussafe/tree/main/db-maintenance/group-02-parkit/`                        |
| **Feedback sent to owners** | (05/11/2026)                                                                                                                |
| **PDF progress document**   |                                                                                                                             |
| **Last updated**            | 2026-11-05                                                                                                                  |

### Activity 6 Log Tab

| Column Header                    | Value                                                                                                                                         |
| -------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| **Project**                      | Group 2 - Park-It: Parking Management System                                                                                                  |
| **Database and backup file**     | `grp_parkitdb`, `grp_parkitdb_activity6.dump`, Size: 20,611 bytes, SHA256: `640C0F8275E6D0193213709F4FD48E422984B8299E868E18B84EE476DAC58610` |
| **Backup method**                | pg_dump custom format (`-Fc`), compressed binary dump (2026-11-05 16:55:10)                                                                   |
| **Restore test result**          | Success (Restored into `grp_parkitdb_restore_test`; all 5 tables, constraints, and data verified)                                             |
| **Access control after restore** | (Activity 4 roles and permissions validated; `parkit_app` denied UPDATE on `payment`, `parkit_report` denied reading `staff_user`)            |
| **Recovery simulation result**   | Recovered (Simulated deleted test parking session, vehicle, and payment successfully restored from baseline state)                            |
| **Proposed RPO and RTO**         | RPO: 24 hours, RTO: 2 hours                                                                                                                   |
| **Evidence folder link**         | `https://github.com/jeffersonorpesa2-ops/grp07-campussafe/tree/main/db-backup-recovery/group-02-parkit/`                                      |
| **Feedback sent to owners**      | (05/11/2026)                                                                                                                                  |
| **PDF progress document**        |                                                                                                                                               |
| **Last updated**                 | 2026-11-05                                                                                                                                    |

---

# AI USAGE DECLARATION

- **AI Tools Used:** Google Gemini 3.8 Flash (via Antigravity AI assistant).
- **Tasks Performed:**
  1. Inspecting database schema definitions, relational constraints, and table definitions for Group 2's Park-It system.
  2. Formulating and executing PostgreSQL least-privilege verification test suites for Activity 4 (credential protection on `staff_user` and payment immutability).
  3. Diagnosing runtime maintenance boundaries, executing `VACUUM` and `ANALYZE`, and profiling execution plans (`EXPLAIN (ANALYZE, BUFFERS)`) for Activity 5.
  4. Executing custom archive backup creation with `pg_dump`, SHA256 checksum computation, test database restoration with `pg_restore`, and controlled recovery simulation drill for Activity 6.
  5. Compiling and formatting comprehensive progress documentation adhering to course rubric guidelines.
- **Validation:** Every SQL query, maintenance command, backup job, and verification statement was executed and validated directly on PostgreSQL 18.6 in pgAdmin 4 / `psql`. Real outputs, timings, and checksums are recorded in this report.
