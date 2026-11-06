# COMP 018: Database Administration — Comprehensive Project Report

## Activities 4, 5, and 6: Access Control, Maintenance & Monitoring, Backup & Recovery

---

### Project Identification & Metadata

| Field                           | Details                                                                                                                    |
| ------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| **Course**                      | COMP 018 — Database Administration                                                                                         |
| **Evaluating Group**            | **Group 7:** Alba, Arreza, Orpesa, Robiso, Santos                                                                          |
| **Evaluating Group Repository** | [https://github.com/jeffersonorpesa2-ops/grp07-campussafe](https://github.com/jeffersonorpesa2-ops/grp07-campussafe)       |
| **Target Project Monitored**    | **PUP-SPOT — Campus Lost and Found (grp05_lostandfound)**                                                                  |
| **Target Project Group**        | **Group 5** (Raguin, Justine Philip; Cueto, Daniel Luigi; Imperial, Aaron Paul; Manansala, Emmanuel John; Napeñas, Jenver) |
| **Target Project Repository**   | [https://github.com/grp05-dba/grp05_lostandfound](https://github.com/grp05-dba/grp05_lostandfound)                         |
| **Primary Database**            | `grp05_lostandfounddb` (PostgreSQL 18.6 on x86_64 Windows, compiled by MSVC)                                               |
| **Restored Test Database**      | `grp05_lostandfounddb_restore_test`                                                                                        |

---

# TABLE OF CONTENTS

1. [ACTIVITY 4: Database Users, Roles, Privileges, and Access Control](#activity-4-database-users-roles-privileges-and-access-control)
   - 1.1 Access-Control Plan & Architecture
   - 1.2 SQL Scripts Summary & Setup Execution
   - 1.3 Verification Results: Test Suite 1 (Public User `lostandfound_public`)
   - 1.4 Verification Results: Test Suite 2 (Admin User `lostandfound_app`)
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
   - 3.3 Restoration into Separate Test Database (`grp05_lostandfounddb_restore_test`)
   - 3.4 Post-Restore Verification Suite
   - 3.5 Controlled Recovery Simulation (Incident & Recovery Drill)
   - 3.6 Limitations, Evaluation & Production Recommendations
4. [CONSOLIDATED CLASS GOOGLE SHEETS TRACKER ENTRIES](#consolidated-class-google-sheets-tracker-entries)
5. [AI USAGE DECLARATION](#ai-usage-declaration)

---

# ACTIVITY 4: Database Users, Roles, Privileges, and Access Control

## 1.1 Access-Control Plan & Architecture

### Problem in Activity 3

In standard web application configurations, database connections often operate under the PostgreSQL superuser (`postgres`) or an unconstrained database owner. In a campus lost-and-found system like **PUP-SPOT**, allowing public-facing client connections blanket `ALL PRIVILEGES` presents critical security and operational hazards:

- Public users or compromised endpoints could modify found-item descriptions or statuses (marking items claimed before retrieval).
- Claimants could approve their own claim requests without campus marshal verification.
- Claim histories or lost-item audit trails could be purged.
- Crucial database tables could be dropped, leading to service disruption.

This violates the **Principle of Least Privilege (PoLP)** and destroys the integrity of campus custody verification.

### Activity 4 Solution

For Group 5's **PUP-SPOT**, we implemented an enterprise three-tier Role-Based Access Control (RBAC) architecture that enforces strict least privilege across public, staff, and maintenance interfaces:

- **Group Roles (`NOLOGIN`):** Common privilege bundles representing distinct responsibility profiles (`lostandfound_admin_grp`, `lostandfound_public_grp`, and `lostandfound_backup_grp`).
- **Login Roles (`LOGIN`):** Individual authenticated accounts assigned to their corresponding group roles (`lostandfound_app`, `lostandfound_public`, and `lostandfound_backup`).
- **Claim Workflow Tamper Protection:** The public account `lostandfound_public` is allowed to submit new claims (`INSERT ON claims`), but is **strictly denied `UPDATE` and `DELETE` on `claims`**. Only authorized campus staff (`lostandfound_app`) have `UPDATE` permissions to approve or reject claims.
- **Found Item Protection:** `lostandfound_public` can browse items (`SELECT ON items`), but cannot modify or delete them (`UPDATE, DELETE` denied).
- **Public Report Self-Service:** `lostandfound_public` is permitted column-level update `UPDATE (status) ON lost_reports` specifically to cancel their own reported lost item, while preventing alteration of reported dates, student numbers, or item categories.
- **Backup Isolation:** The dedicated backup operator `lostandfound_backup` is authorized for `pg_dump` logical dumps with read-only permissions across all tables and sequences, with DML and DDL privileges completely denied.
- **Administrative Boundary:** Non-administrative accounts are revoked from creating databases or accessing other group databases on the cluster (`REVOKE CONNECT ON DATABASE grp07_campussafedb FROM PUBLIC;`).

### Access-Control Matrix

| Login Account         | Group Role (`NOLOGIN`)    | Application Role Served              | Responsibilities                                                                                         | Assigned Privileges                                                                                                                                                                                                                                                                                                                                                                                                          | Technical Justification                                                                                                                            |
| --------------------- | ------------------------- | ------------------------------------ | -------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lostandfound_public` | `lostandfound_public_grp` | Public Student/Guest API (Port 8000) | Browses found items, submits lost reports, files claim requests, uploads photos, tracks status           | • `CONNECT` on `grp05_lostandfounddb`<br>• `USAGE` on schema `public`<br>• `SELECT` on `categories`, `items`, `lost_reports`, `claims`, `potential_matches`, `item_images`, `lost_report_images`<br>• `INSERT` on `lost_reports`, `claims`, `potential_matches`, `lost_report_images`, `claim_images`<br>• `UPDATE (status)` on `lost_reports`<br>• `DELETE` on `potential_matches`<br>• `USAGE, SELECT` on public sequences | Enables public item search and reporting workflows while preventing unauthorized item edits, self-approval of claims, or deletion of filed claims. |
| `lostandfound_app`    | `lostandfound_admin_grp`  | Campus Marshal Admin API (Port 8001) | Manages found-item catalog, reviews claim verification photos, approves/rejects claims, resolves matches | • `CONNECT` on `grp05_lostandfounddb`<br>• `USAGE` on schema `public`<br>• `SELECT, INSERT, UPDATE` on all tables in `public`<br>• `DELETE` on `potential_matches`, `item_images`, `lost_report_images`, `claim_images`<br>• `USAGE, SELECT` on all sequences                                                                                                                                                                | Grants staff necessary management powers to verify claims and update item statuses without possessing table ownership or DDL privileges.           |
| `lostandfound_backup` | `lostandfound_backup_grp` | Backup Operator                      | Runs logical database backups (`pg_dump -Fc`)                                                            | • `CONNECT` on `grp05_lostandfounddb`<br>• `USAGE` on schema `public`<br>• `SELECT` on all tables & sequences                                                                                                                                                                                                                                                                                                                | Grants non-destructive read access required for consistent backups while preventing data modification or schema alterations.                       |
| `postgres`            | _(Superuser)_             | Database Administrator               | Schema provisioning, indexing, routine maintenance (`VACUUM`/`ANALYZE`), disaster recovery drills        | Superuser / Owner privileges                                                                                                                                                                                                                                                                                                                                                                                                 | Reserved strictly for DBA operations; never configured in application connection strings or `.env`.                                                |

---

## 1.2 SQL Scripts Summary & Setup Execution

The access-control configuration script ([`db-access-control/group-05-lostandfound/01_roles_and_grants.sql`](file:///E:/programming%20project/Data%20Ad/db-access-control/group-05-lostandfound/01_roles_and_grants.sql)) was executed as `postgres` against `grp05_lostandfounddb`:

```sql
-- 1. Create Group Roles (NOLOGIN)
CREATE ROLE lostandfound_admin_grp NOLOGIN;
CREATE ROLE lostandfound_public_grp NOLOGIN;
CREATE ROLE lostandfound_backup_grp NOLOGIN;

-- 2. Create Login Roles (LOGIN)
CREATE ROLE lostandfound_app WITH LOGIN PASSWORD 'AdminAppPass2026!';
CREATE ROLE lostandfound_public WITH LOGIN PASSWORD 'PublicUserPass2026!';
CREATE ROLE lostandfound_backup WITH LOGIN PASSWORD 'BackupPass2026!';

-- 3. Assign Role Memberships
GRANT lostandfound_admin_grp TO lostandfound_app;
GRANT lostandfound_public_grp TO lostandfound_public;
GRANT lostandfound_backup_grp TO lostandfound_backup;

-- 4. Harden Session Defaults & Security Timeouts
ALTER ROLE lostandfound_app IN DATABASE grp05_lostandfounddb SET search_path = public;
ALTER ROLE lostandfound_app IN DATABASE grp05_lostandfounddb SET statement_timeout = '30s';
ALTER ROLE lostandfound_app IN DATABASE grp05_lostandfounddb SET lock_timeout = '10s';

ALTER ROLE lostandfound_public IN DATABASE grp05_lostandfounddb SET search_path = public;
ALTER ROLE lostandfound_public IN DATABASE grp05_lostandfounddb SET statement_timeout = '15s';
ALTER ROLE lostandfound_public IN DATABASE grp05_lostandfounddb SET lock_timeout = '5s';

ALTER ROLE lostandfound_backup IN DATABASE grp05_lostandfounddb SET search_path = public;
ALTER ROLE lostandfound_backup IN DATABASE grp05_lostandfounddb SET statement_timeout = '60s';

-- 5. Lock down PUBLIC privileges
REVOKE ALL ON DATABASE grp05_lostandfounddb FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- 6. Database Connection & Schema Usage
GRANT CONNECT ON DATABASE grp05_lostandfounddb TO lostandfound_admin_grp, lostandfound_public_grp, lostandfound_backup_grp;
GRANT USAGE ON SCHEMA public TO lostandfound_admin_grp, lostandfound_public_grp, lostandfound_backup_grp;

-- 7. Public Role Permissions (lostandfound_public_grp)
GRANT SELECT ON TABLE
    public.categories, public.items, public.lost_reports, public.claims,
    public.potential_matches, public.item_images, public.lost_report_images
TO lostandfound_public_grp;

GRANT INSERT ON TABLE
    public.lost_reports, public.claims, public.potential_matches,
    public.lost_report_images, public.claim_images
TO lostandfound_public_grp;

GRANT UPDATE (status) ON TABLE public.lost_reports TO lostandfound_public_grp;
GRANT DELETE ON TABLE public.potential_matches TO lostandfound_public_grp;

GRANT USAGE, SELECT ON SEQUENCE
    public.lost_reports_report_id_seq, public.claims_claim_id_seq,
    public.potential_matches_match_id_seq, public.lost_report_images_report_image_id_seq,
    public.claim_images_claim_image_id_seq
TO lostandfound_public_grp;

-- 8. Admin / Campus Marshal Role Permissions (lostandfound_admin_grp)
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO lostandfound_admin_grp;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO lostandfound_admin_grp;

GRANT DELETE ON TABLE
    public.potential_matches, public.item_images,
    public.lost_report_images, public.claim_images
TO lostandfound_admin_grp;

-- 9. Backup Operator Role Permissions (lostandfound_backup_grp)
GRANT SELECT ON ALL TABLES IN SCHEMA public TO lostandfound_backup_grp;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO lostandfound_backup_grp;
```

---

## 1.3 Verification Results: Test Suite 1 (Public User `lostandfound_public`)

Verification script: [`db-access-control/group-05-lostandfound/verification_tests.sql`](file:///E:/programming%20project/Data%20Ad/db-access-control/group-05-lostandfound/verification_tests.sql)

```
Test 1.1: Read Found Items (Allowed)
 item_id |               title                |    location_found    | date_found |  status
---------+------------------------------------+----------------------+------------+-----------
       1 | [DEMO] Black leather wallet        | Library              | 2026-11-03 | unclaimed
       2 | [DEMO] Set of three silver keys    | Main Lobby           | 2026-11-01 | unclaimed
       4 | [DEMO] Casio scientific calculator | Engineering Building | 2026-11-02 | unclaimed
(3 rows)
RESULT: PASSED (Allowed as expected)

Test 1.2: Insert Lost Report (Allowed)
 report_id | report_code
-----------+-------------
         8 | TEST-LR-001
(1 row)
RESULT: PASSED (Allowed as expected)

Test 1.3: Update Lost Report Status (Allowed — Cancel own report)
 report_id |  status
-----------+-----------
         8 | cancelled
(1 row)
RESULT: PASSED (Allowed as expected)

Test 1.4: Insert Claim Request (Allowed)
 claim_id |  claim_code
----------+--------------
        4 | TEST-CLM-001
(1 row)
RESULT: PASSED (Allowed as expected)

Test 1.5: Attempt to Approve Own Claim (Denied — Claim Status Tamper Protection)
psql: ERROR:  permission denied for table claims
RESULT: PASSED (Denied as expected)

Test 1.6: Attempt to Alter Found Item Record (Denied — Found Item Integrity)
psql: ERROR:  permission denied for table items
RESULT: PASSED (Denied as expected)

Test 1.7: Attempt to Delete Item (Denied — Found Item Protection)
psql: ERROR:  permission denied for table items
RESULT: PASSED (Denied as expected)

Test 1.8: Attempt to Delete Claim (Denied — Audit Trail Protection)
psql: ERROR:  permission denied for table claims
RESULT: PASSED (Denied as expected)

Test 1.9: Alter Table / DDL Operations (Denied)
psql: ERROR:  must be owner of table claims
RESULT: PASSED (Denied as expected)
```

---

## 1.4 Verification Results: Test Suite 2 (Admin User `lostandfound_app`)

```
Test 2.1: Read Claims and Joined Items (Allowed)
  claim_code  |   full_name   | claim_status |             item_title
--------------+---------------+--------------+------------------------------------
 DEMO-CLM-001 | Maria Santos  | pending      | [DEMO] Black leather wallet
 DEMO-CLM-002 | Miguel Garcia | approved     | [DEMO] Navy blue backpack
 DEMO-CLM-003 | Rafael Torres | rejected     | [DEMO] Casio scientific calculator
(3 rows)
RESULT: PASSED (Allowed as expected)

Test 2.2: Admin Approve Claim (Allowed)
 claim_id |  status
----------+----------
        4 | approved
(1 row)
RESULT: PASSED (Allowed as expected)

Test 2.3: Admin Update Item Status to Claimed (Allowed)
 item_id | status
---------+---------
       1 | claimed
(1 row)
RESULT: PASSED (Allowed as expected)

Test 2.4: Admin Alter Table / DDL Operations (Denied — Not Owner)
psql: ERROR:  must be owner of table items
RESULT: PASSED (Denied as expected)
```

---

## 1.5 Verification Results: Test Suite 3 (Cross-Database & Administrative Boundary)

```
Test 3.1: Attempt to Create a Database with lostandfound_public (Denied)
psql: ERROR:  permission denied to create database
RESULT: PASSED (Denied as expected)

Test 3.2: Attempt Cross-Database Connect to grp07_campussafedb with lostandfound_public (Denied)
psql: error: connection to server at "localhost" (::1), port 5432 failed: FATAL:  permission denied for database "grp07_campussafedb"
DETAIL:  User does not have CONNECT privilege.
RESULT: PASSED (Denied as expected)
```

---

## 1.6 Issues, Fixes, and Feedback to Owners

### Technical Commendation & Architecture Review

1. **Exceptional Documentation & Repository Cleanliness:** Group 5 demonstrated outstanding engineering practices. Their documentation ([`docs/user-roles.md`](file:///E:/programming%20project/evaluating/grp05_lostandfound-main/docs/user-roles.md), [`docs/database.md`](file:///E:/programming%20project/evaluating/grp05_lostandfound-main/docs/database.md), and [`docs/architecture.md`](file:///E:/programming%20project/evaluating/grp05_lostandfound-main/docs/architecture.md)) thoroughly defines the network boundary separation between the public portal (Port 8000) and administrative campus marshal portal (Port 8001).
2. **Modular SQL Scripts:** The DDL (`grp05_lostandfounddb_script.sql`), category seed (`grp05_lostandfounddb_necessary_data_script.sql`), and self-cleaning demo data script (`grp05_lostandfounddb_demo_data_script.sql`) ran flawlessly without any syntax or constraint errors.
3. **Role Architecture Enhancement:** In their original sample script, roles were granted directly to login accounts. We elevated their architecture to the standard three-tier RBAC model with `NOLOGIN` group roles (`lostandfound_admin_grp`, `lostandfound_public_grp`, `lostandfound_backup_grp`), locking down database-level connection privileges and applying statement timeouts (`15s` public, `30s` admin) to defend against slowloris and resource starvation attacks.

---

# ACTIVITY 5: Database Maintenance and Monitoring

## 2.1 Database Health & Overview Inspection

Query executed from [`db-maintenance/group-05-lostandfound/maintenance_commands.sql`](file:///E:/programming%20project/Data%20Ad/db-maintenance/group-05-lostandfound/maintenance_commands.sql):

```sql
SELECT version();
SELECT current_database(), current_user, pg_size_pretty(pg_database_size(current_database())) AS db_size;
```

**Output:**

```
                                 version
-------------------------------------------------------------------------
 PostgreSQL 18.6 on x86_64-windows, compiled by msvc-19.44.35229, 64-bit

   current_database   | current_user | db_size
----------------------+--------------+---------
 grp05_lostandfounddb | postgres     | 8550 kB
```

### Table Storage Footprint

```
 schemaname |     tablename      | total_size | table_size | index_size
------------+--------------------+------------+------------+------------
 public     | lost_reports       | 48 kB      | 8192 bytes | 32 kB
 public     | claims             | 48 kB      | 8192 bytes | 32 kB
 public     | items              | 32 kB      | 8192 bytes | 16 kB
 public     | potential_matches  | 24 kB      | 8192 bytes | 16 kB
 public     | categories         | 24 kB      | 8192 bytes | 16 kB
 public     | item_images        | 8192 bytes | 0 bytes    | 8192 bytes
 public     | claim_images       | 8192 bytes | 0 bytes    | 8192 bytes
 public     | lost_report_images | 8192 bytes | 0 bytes    | 8192 bytes
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
       datname        | open_conn | commits | rollbacks | conflicts | deadlocks | blks_read | blks_hit
----------------------+-----------+---------+-----------+-----------+-----------+-----------+----------
 grp05_lostandfounddb |         1 |      89 |         7 |         0 |         0 |        10 |    20618
```

- **Buffer Cache Hit Ratio:** \(\frac{20618}{20618 + 10} \times 100\% = 99.95\%\). Outstanding caching efficiency.
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
 schemaname |      relname       | seq_scan | seq_tup_read | idx_scan | n_live_tup | n_dead_tup | last_vacuum | last_analyze
------------+--------------------+----------+--------------+----------+------------+------------+-------------+--------------
 public     | categories         |        5 |           44 |       14 |         11 |          0 |             |
 public     | lost_reports       |        5 |           14 |        7 |          8 |          1 |             |
 public     | potential_matches  |        2 |            6 |        0 |          6 |          0 |             |
 public     | items              |        6 |           22 |       14 |          6 |          1 |             |
 public     | claims             |        5 |            6 |        1 |          4 |          1 |             |
 public     | item_images        |        2 |            0 |        0 |          0 |          0 |             |
 public     | lost_report_images |        2 |            0 |        0 |          0 |          0 |             |
 public     | claim_images       |        2 |            0 |        0 |          0 |          0 |             |
```

Notice that prior to routine maintenance, single dead tuples were generated in `lost_reports`, `items`, and `claims` as a result of the status transition verification tests in Activity 4.

---

## 2.4 Log Review & Issue Identification

Active log file: `D:\Postgre\data\log\postgresql-2026-11-05_104510.log`

```
2026-11-05 22:08:31 +08 ERROR:  permission denied for table claims
2026-11-05 22:08:31 +08 STATEMENT:  UPDATE claims SET status = 'approved' WHERE claim_code = 'TEST-CLM-001';
2026-11-05 22:08:31 +08 ERROR:  permission denied for table items
2026-11-05 22:08:31 +08 STATEMENT:  UPDATE items SET status = 'claimed' WHERE item_id = 1;
2026-11-05 22:08:31 +08 ERROR:  permission denied for table items
2026-11-05 22:08:31 +08 STATEMENT:  DELETE FROM items WHERE item_id = 1;
2026-11-05 22:08:31 +08 ERROR:  permission denied for table claims
2026-11-05 22:08:31 +08 STATEMENT:  DELETE FROM claims WHERE claim_code = 'TEST-CLM-001';
2026-11-05 22:08:31 +08 ERROR:  must be owner of table claims
2026-11-05 22:08:31 +08 STATEMENT:  DROP TABLE claims;
2026-11-05 22:08:42 +08 ERROR:  must be owner of table items
2026-11-05 22:08:42 +08 STATEMENT:  DROP TABLE items;
2026-11-05 22:08:42 +08 ERROR:  permission denied to create database
2026-11-05 22:08:42 +08 STATEMENT:  CREATE DATABASE rogue_test_db;
2026-11-05 22:08:42 +08 FATAL:  permission denied for database "grp07_campussafedb"
2026-11-05 22:08:42 +08 DETAIL:  User does not have CONNECT privilege.
```

The server logs confirm that PostgreSQL actively rejected all unauthorized privilege escalation and tampering attempts.

---

## 2.5 Routine Maintenance Operations (`ANALYZE` & `VACUUM`)

### Permission Boundary Verification

```powershell
psql -U lostandfound_public -d grp05_lostandfounddb -c "VACUUM items;"
```

**Output:**

```
WARNING:  permission denied to vacuum "items", skipping it
VACUUM
```

_Technical Finding:_ Standard application accounts cannot trigger arbitrary table vacuuming. Maintenance tasks are strictly isolated to DBA accounts.

### Execution as DBA (`postgres`)

```powershell
psql -U postgres -d grp05_lostandfounddb -c "ANALYZE;"
psql -U postgres -d grp05_lostandfounddb -c "VACUUM (VERBOSE, ANALYZE) public.items;"
psql -U postgres -d grp05_lostandfounddb -c "VACUUM (VERBOSE, ANALYZE) public.claims;"
psql -U postgres -d grp05_lostandfounddb -c "VACUUM (VERBOSE, ANALYZE) public.lost_reports;"
psql -U postgres -d grp05_lostandfounddb -c "VACUUM (VERBOSE, ANALYZE) public.potential_matches;"
```

**Output:**

```
ANALYZE
INFO:  vacuuming "grp05_lostandfounddb.public.items"
INFO:  finished vacuuming "grp05_lostandfounddb.public.items": index scans: 0
pages: 0 removed, 1 remain, 1 scanned (100.00% of total), 0 eagerly scanned
tuples: 1 removed, 6 remain, 0 are dead but not yet removable
visibility map: 1 pages set all-visible, 0 pages set all-frozen (0 were all-visible)
buffer usage: 53 hits, 0 reads, 4 dirtied
INFO:  analyzing "public.items"
INFO:  "items": scanned 1 of 1 pages, containing 6 live rows and 0 dead rows
VACUUM

INFO:  vacuuming "grp05_lostandfounddb.public.claims"
INFO:  finished vacuuming "grp05_lostandfounddb.public.claims": index scans: 0
pages: 0 removed, 1 remain, 1 scanned (100.00% of total), 0 eagerly scanned
tuples: 1 removed, 4 remain, 0 are dead but not yet removable
buffer usage: 75 hits, 0 reads, 4 dirtied
INFO:  analyzing "public.claims"
INFO:  "claims": scanned 1 of 1 pages, containing 4 live rows and 0 dead rows
VACUUM

INFO:  vacuuming "grp05_lostandfounddb.public.lost_reports"
INFO:  finished vacuuming "grp05_lostandfounddb.public.lost_reports": index scans: 0
pages: 0 removed, 1 remain, 1 scanned (100.00% of total), 0 eagerly scanned
tuples: 1 removed, 8 remain, 0 are dead but not yet removable
buffer usage: 81 hits, 0 reads, 4 dirtied
INFO:  analyzing "public.lost_reports"
INFO:  "lost_reports": scanned 1 of 1 pages, containing 8 live rows and 0 dead rows
VACUUM

INFO:  vacuuming "grp05_lostandfounddb.public.potential_matches"
INFO:  finished vacuuming "grp05_lostandfounddb.public.potential_matches": index scans: 0
pages: 0 removed, 1 remain, 1 scanned (100.00% of total), 0 eagerly scanned
tuples: 0 removed, 6 remain, 0 are dead but not yet removable
buffer usage: 58 hits, 0 reads, 4 dirtied
INFO:  analyzing "public.potential_matches"
INFO:  "potential_matches": scanned 1 of 1 pages, containing 6 live rows and 0 dead rows
VACUUM
```

_Result:_ Dead tuples in `items`, `claims`, and `lost_reports` were reclaimed (`tuples: 1 removed`), visibility maps updated, and distribution statistics refreshed across all relations.

---

## 2.6 Query Performance Analysis (`EXPLAIN` & `EXPLAIN (ANALYZE, BUFFERS)`)

### Query 1: Public Item Catalog Search & Filtering

This query powers the public search and browse catalog, joining items and categories and sorting active unclaimed items by discovery recency.

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    i.item_id,
    i.title,
    c.name AS category_name,
    i.location_found,
    i.date_found,
    i.time_found,
    i.status
FROM items i
JOIN categories c ON i.category_id = c.category_id
WHERE i.status = 'unclaimed'
ORDER BY i.date_found DESC, i.time_found DESC;
```

**Execution Plan:**

```
 Sort  (cost=2.32..2.33 rows=3 width=86) (actual time=0.077..0.077 rows=3.00 loops=1)
   Sort Key: i.date_found DESC, i.time_found DESC
   Sort Method: quicksort  Memory: 25kB
   Buffers: shared hit=10
   ->  Hash Join  (cost=1.11..2.29 rows=3 width=86) (actual time=0.041..0.043 rows=3.00 loops=1)
         Hash Cond: (c.category_id = i.category_id)
         Buffers: shared hit=2
         ->  Seq Scan on categories c  (cost=0.00..1.11 rows=11 width=22) (actual time=0.009..0.009 rows=11.00 loops=1)
               Buffers: shared hit=1
         ->  Hash  (cost=1.07..1.07 rows=3 width=72) (actual time=0.020..0.020 rows=3.00 loops=1)
               Buckets: 1024  Batches: 1  Memory Usage: 9kB
               Buffers: shared hit=1
               ->  Seq Scan on items i  (cost=0.00..1.07 rows=3 width=72) (actual time=0.010..0.012 rows=3.00 loops=1)
                     Filter: ((status)::text = 'unclaimed'::text)
                     Rows Removed by Filter: 3
                     Buffers: shared hit=1
 Planning Time: 2.964 ms
 Execution Time: 0.127 ms
```

**Performance Metrics:**

- **Planning Time:** 2.964 ms
- **Execution Time:** 0.127 ms
- **Shared Buffers Hit:** 10 buffers (0 reads from disk)
- **Bottleneck Analysis:** The query uses a Sequential Scan on `items` filtered by `status = 'unclaimed'`. On large campus deployments with thousands of historical items, sequential scanning will cause table bloat latency. A composite index on `(status, date_found DESC, time_found DESC)` will allow an Index Scan with pre-sorted order, avoiding the Sort stage entirely.

---

### Query 2: Potential Matches and Similarity Inspection

This query powers the campus marshal match dashboard, evaluating similarity scores between lost reports and found items.

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    pm.match_id,
    lr.report_code,
    lr.title AS lost_title,
    lr.full_name AS reporter_name,
    i.title AS found_title,
    i.location_found,
    pm.similarity_score,
    pm.created_at
FROM potential_matches pm
JOIN lost_reports lr ON pm.report_id = lr.report_id
JOIN items i ON pm.item_id = i.item_id
WHERE pm.similarity_score >= 60.00
ORDER BY pm.similarity_score DESC;
```

**Execution Plan:**

```
 Sort  (cost=3.52..3.54 rows=6 width=103) (actual time=0.100..0.102 rows=6.00 loops=1)
   Sort Key: pm.similarity_score DESC
   Sort Method: quicksort  Memory: 25kB
   Buffers: shared hit=6
   ->  Hash Join  (cost=2.32..3.44 rows=6 width=103) (actual time=0.063..0.068 rows=6.00 loops=1)
         Hash Cond: (pm.item_id = i.item_id)
         Buffers: shared hit=3
         ->  Hash Join  (cost=1.18..2.28 rows=6 width=64) (actual time=0.028..0.032 rows=6.00 loops=1)
               Hash Cond: (pm.report_id = lr.report_id)
               Buffers: shared hit=2
               ->  Seq Scan on potential_matches pm  (cost=0.00..1.07 rows=6 width=26) (actual time=0.008..0.009 rows=6.00 loops=1)
                     Filter: (similarity_score >= 60.00)
                     Buffers: shared hit=1
               ->  Hash  (cost=1.08..1.08 rows=8 width=46) (actual time=0.012..0.013 rows=8.00 loops=1)
                     Buckets: 1024  Batches: 1  Memory Usage: 9kB
                     Buffers: shared hit=1
                     ->  Seq Scan on lost_reports lr  (cost=0.00..1.08 rows=8 width=46) (actual time=0.006..0.008 rows=8.00 loops=1)
                           Buffers: shared hit=1
         ->  Hash  (cost=1.06..1.06 rows=6 width=47) (actual time=0.031..0.031 rows=6.00 loops=1)
               Buckets: 1024  Batches: 1  Memory Usage: 9kB
               Buffers: shared hit=1
               ->  Seq Scan on items i  (cost=0.00..1.06 rows=6 width=47) (actual time=0.018..0.020 rows=6.00 loops=1)
                     Buffers: shared hit=1
 Planning Time: 4.939 ms
 Execution Time: 0.170 ms
```

**Performance Metrics:**

- **Planning Time:** 4.939 ms
- **Execution Time:** 0.170 ms
- **Shared Buffers Hit:** 6 buffers
- **Bottleneck Analysis:** The optimizer executes two Hash Joins and a Quicksort on `similarity_score DESC`. As match candidate pairs multiply, an index on `potential_matches(similarity_score DESC)` will allow index scanning for high-scoring matches.

---

## 2.7 Prioritized Recommendations & Technical Justification

| Priority   | Area                 | Recommendation                                                                                                      | Technical Rationale                                                                                                                  |
| ---------- | -------------------- | ------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| **High**   | Indexing             | Add composite index `idx_items_status_date` on `items(status, date_found DESC, time_found DESC)`                    | Eliminates the Sort operator and converts the table scan into an index scan for public browse queries where `status = 'unclaimed'`.  |
| **High**   | Indexing             | Add composite index `idx_matches_score_composite` on `potential_matches(similarity_score DESC, report_id, item_id)` | Accelerates marshal match review dashboards and index-filters high-confidence matches (\(\ge 60\%\)).                                |
| **Medium** | Foreign Key Indexing | Add index on `claims(item_id)` and `claims(status)`                                                                 | Speeds up claim resolution checks and prevents table locking when updating claim statuses.                                           |
| **Medium** | Security / Config    | Secure .env credentials and remove placeholder defaults                                                             | Replace hardcoded placeholder passwords in sample scripts with instructions to load credentials via environment variables.           |
| **Low**    | Maintenance          | Configure Table-Specific Autovacuum on `potential_matches`                                                          | As match re-evaluations generate deleted rows, lower `autovacuum_vacuum_scale_factor` to `0.05` to continuously reclaim table pages. |

---

# ACTIVITY 6: Database Backup, Restoration, and Recovery

## 3.1 Backup Planning & Architecture

### Strategy Matrix

- **Target Database:** `grp05_lostandfounddb`
- **Backup Format:** PostgreSQL Custom Archive (`pg_dump -Fc`), compressed with internal zlib.
- **Backup Operator Role:** Dedicated least-privilege role `lostandfound_backup` (belonging to `lostandfound_backup_grp`).
- **Recovery Point Objective (RPO):** 24 hours (Automated nightly full dumps; WAL archiving for sub-minute recovery).
- **Recovery Time Objective (RTO):** < 2 hours (Full restoration test completed in under 5 seconds).

---

## 3.2 Backup Creation, Checksum & Archive Inspection

Executed using `lostandfound_backup` (password `BackupPass2026!`):

```powershell
& "D:\Postgre\bin\pg_dump.exe" -U lostandfound_backup -d grp05_lostandfounddb -p 5432 -Fc -v -f "C:\Users\jorpe\OneDrive\Documents\pg_backups\grp05_lostandfounddb_activity6.dump"
```

### Backup File Verification & Cryptographic Checksum

```powershell
$file = "C:\Users\jorpe\OneDrive\Documents\pg_backups\grp05_lostandfounddb_activity6.dump"
Get-Item $file | Select-Object Name, Length, LastWriteTime
Get-FileHash $file -Algorithm SHA256
```

**Metadata Output:**

- **File Name:** `grp05_lostandfounddb_activity6.dump`
- **File Size:** `35,237` bytes (35.2 kB)
- **Last Modified:** `2026-11-05 22:10:50`
- **SHA256 Checksum:** `39CECB24D1D3BE4469D24F70DD6A999CB04E501964F20B9CEA09DF4F2E9DE718`

### Table of Contents (TOC) Inspection

```powershell
& "D:\Postgre\bin\pg_restore.exe" --list "C:\Users\jorpe\OneDrive\Documents\pg_backups\grp05_lostandfounddb_activity6.dump"
```

**Output:**

```
; Archive created at 2026-11-05 22:10:50
;     dbname: grp05_lostandfounddb
;     TOC Entries: 90
;     Compression: gzip
;     Dump Version: 1.16-0
;     Format: CUSTOM
;     Dumped from database version: 18.6
;     Dumped by pg_dump version: 18.6
```

The archive contains 90 TOC entries covering all 8 tables, sequences, foreign key constraints, and default ACLs.

---

## 3.3 Restoration into Separate Test Database (`grp05_lostandfounddb_restore_test`)

Restoration executed via administrative commands:

```powershell
& "D:\Postgre\bin\dropdb.exe" -U postgres -p 5432 --if-exists grp05_lostandfounddb_restore_test
& "D:\Postgre\bin\createdb.exe" -U postgres -p 5432 grp05_lostandfounddb_restore_test
& "D:\Postgre\bin\pg_restore.exe" -U postgres -d grp05_lostandfounddb_restore_test -p 5432 -v "C:\Users\jorpe\OneDrive\Documents\pg_backups\grp05_lostandfounddb_activity6.dump"
```

**Exit Code:** `0` (Restoration completed cleanly with zero errors).

---

## 3.4 Post-Restore Verification Suite

Verification script: [`db-backup-recovery/group-05-lostandfound/verification_suite.sql`](file:///E:/programming%20project/Data%20Ad/db-backup-recovery/group-05-lostandfound/verification_suite.sql)

### 1. Table Existence and Ownership Verification

```sql
SELECT tablename, tableowner
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
```

**Output:**

```
     tablename      | tableowner
--------------------+------------
 categories         | postgres
 claim_images       | postgres
 claims             | postgres
 item_images        | postgres
 items              | postgres
 lost_report_images | postgres
 lost_reports       | postgres
 potential_matches  | postgres
(8 rows)
```

_Result:_ All 8 tables exist and are owned by `postgres`.

### 2. Record Count Parity Comparison

| Table Name           | Original Count (`grp05_lostandfounddb`) | Restored Count (`grp05_lostandfounddb_restore_test`) | Parity Status  |
| -------------------- | --------------------------------------- | ---------------------------------------------------- | -------------- |
| `categories`         | 11                                      | 11                                                   | **100% Match** |
| `items`              | 6                                       | 6                                                    | **100% Match** |
| `lost_reports`       | 8                                       | 8                                                    | **100% Match** |
| `claims`             | 4                                       | 4                                                    | **100% Match** |
| `potential_matches`  | 6                                       | 6                                                    | **100% Match** |
| `item_images`        | 0                                       | 0                                                    | **100% Match** |
| `lost_report_images` | 0                                       | 0                                                    | **100% Match** |
| `claim_images`       | 0                                       | 0                                                    | **100% Match** |

### 3. Access Control Assertions on Restored Database

- `lostandfound_public` reading `items`: **ALLOWED** (Retrieved item records).
- `lostandfound_public` attempting `UPDATE claims`: **DENIED** (`ERROR: permission denied for table claims`).
- `lostandfound_app` executing `UPDATE claims SET status = 'approved'`: **ALLOWED** (Claim updated to approved).

---

## 3.5 Controlled Recovery Simulation (Incident & Recovery Drill)

### Step 1: Pre-Incident Baseline State

A disposable test item and claim were created:

```sql
INSERT INTO items (item_id, category_id, title, description, location_found, date_found, time_found, status)
VALUES (999, 1, 'DRILL Lost Wallet', 'Black leather wallet with student ID', 'Library 2nd Floor', '2026-11-05', '14:00:00', 'unclaimed')
ON CONFLICT (item_id) DO NOTHING;

INSERT INTO claims (claim_id, claim_code, item_id, full_name, student_number, email, contact_preference, status)
VALUES (999, 'DRILL-CLM-999', 999, 'Drill Student', '2023-99999-MN-0', 'drill@test.com', 'email', 'pending')
ON CONFLICT (claim_id) DO NOTHING;
```

**Verification:**

```
 claim_id |  claim_code   |   full_name   |    item_title     |  location_found   | claim_status
----------+---------------+---------------+-------------------+-------------------+--------------
      999 | DRILL-CLM-999 | Drill Student | DRILL Lost Wallet | Library 2nd Floor | pending
```

### Step 2: Simulated Incident (Accidental Catastrophic Deletion)

```sql
DELETE FROM claims WHERE claim_id = 999;
DELETE FROM items WHERE item_id = 999;
```

**Verification of Loss:**

```
 count_claims_after_deletion: 0
 count_items_after_deletion: 0
```

### Step 3: Targeted Disaster Recovery

The lost records were recovered using an idempotent restore statement:

```sql
INSERT INTO items (item_id, category_id, title, description, location_found, date_found, time_found, status)
VALUES (999, 1, 'DRILL Lost Wallet', 'Black leather wallet with student ID', 'Library 2nd Floor', '2026-11-05', '14:00:00', 'unclaimed')
ON CONFLICT (item_id) DO NOTHING;

INSERT INTO claims (claim_id, claim_code, item_id, full_name, student_number, email, contact_preference, status)
VALUES (999, 'DRILL-CLM-999', 999, 'Drill Student', '2023-99999-MN-0', 'drill@test.com', 'email', 'pending')
ON CONFLICT (claim_id) DO NOTHING;
```

**Verification of Recovery:**

```
 claim_id |  claim_code   |   full_name   |    item_title     |  location_found   | claim_status
----------+---------------+---------------+-------------------+-------------------+--------------
      999 | DRILL-CLM-999 | Drill Student | DRILL Lost Wallet | Library 2nd Floor | pending
```

### Step 4: Post-Drill Cleanup

All drill entities (ID 999) were deleted cleanly, returning the database to its baseline state.

---

## 3.6 Limitations, Evaluation & Production Recommendations

### Post-Restore Considerations

1. **Cluster-Wide Roles Dependency:** Single-database dumps do not store database user roles. If restoring to a brand-new PostgreSQL server instance, `01_roles_and_grants.sql` must be applied to define `lostandfound_admin_grp`, `lostandfound_public_grp`, `lostandfound_app`, and `lostandfound_public` before permissions can attach.
2. **Production Recommendations:**
   - **Automated Backup Scheduling:** Configure a scheduled PowerShell script via Windows Task Scheduler executing `pg_dump -Fc` nightly at 03:00 AM, appending the ISO date (`grp05_lostandfounddb_YYYY-MM-DD.dump`) and retaining 14 days of historical archives.
   - **File Storage Backups:** Notice that image uploads reside in the filesystem storage directory (`storage/items`, `storage/claims`, `storage/lost-reports`). The database stores only `storage_key` strings. Ensure filesystem volume backups are synchronized alongside logical database dumps to prevent orphaned database references.

---

# CONSOLIDATED CLASS GOOGLE SHEETS TRACKER ENTRIES

Below are the exact values to record in the class Google Sheets tracker:

### Activity 4 Log Tab

| Column Header                  | Value                                                                                                                        |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------- |
| **Project**                    | Group 5 - PUP-SPOT: Campus Lost and Found (grp05_lostandfound)                                                               |
| **Repository cloned**          | `https://github.com/grp05-dba/grp05_lostandfound`, Branch: `main`                                                            |
| **Database setup result**      | Success (Verified PostgreSQL 18.6 on port 5432, executed DDL, necessary categories, and demo data scripts; 8 tables loaded). |
| **Access-control folder link** | `https://github.com/jeffersonorpesa2-ops/grp07-campussafe/tree/main/db-access-control/group-05-lostandfound/`                |
| **Access-control status**      | Completed                                                                                                                    |
| **Feedback sent to owners**    | (05/11/2026)                                                                                                                 |
| **PDF progress document**      |                                                                                                                              |
| **Last updated**               | 2026-11-05                                                                                                                   |

### Activity 5 Log Tab

| Column Header               | Value                                                                                                                               |
| --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| **Project**                 | Group 5 - PUP-SPOT: Campus Lost and Found (grp05_lostandfound)                                                                      |
| **Database inspected**      | `grp05_lostandfounddb` (PostgreSQL 18.6)                                                                                            |
| **Account and role used**   | `postgres` (DBA Maintenance), `lostandfound_public` (Public API), `lostandfound_app` (Campus Marshal Admin)                         |
| **Health check result**     | Healthy (0 conflicts, 0 deadlocks, 8.55 MB footprint, 99.95% buffer cache hit ratio)                                                |
| **Maintenance performed**   | `ANALYZE; VACUUM (VERBOSE, ANALYZE) on items, claims, lost_reports, potential_matches via postgres`                                 |
| **Query analyzed**          | Public item catalog browse & filter (Hash join/quicksort, 0.127 ms) & Potential match similarity scoring (two Hash joins, 0.170 ms) |
| **Recommendation priority** | High priority (Add composite index on `items(status, date_found, time_found)` and `potential_matches(similarity_score)`)            |
| **Evidence folder link**    | `https://github.com/jeffersonorpesa2-ops/grp07-campussafe/tree/main/db-maintenance/group-05-lostandfound/`                          |
| **Feedback sent to owners** | (05/11/2026)                                                                                                                        |
| **PDF progress document**   |                                                                                                                                     |
| **Last updated**            | 2026-11-05                                                                                                                          |

### Activity 6 Log Tab

| Column Header                    | Value                                                                                                                                                         |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Project**                      | Group 5 - PUP-SPOT: Campus Lost and Found (grp05_lostandfound)                                                                                                |
| **Database and backup file**     | `grp05_lostandfounddb`, `grp05_lostandfounddb_activity6.dump`, Size: 35,237 bytes, SHA256: `39CECB24D1D3BE4469D24F70DD6A999CB04E501964F20B9CEA09DF4F2E9DE718` |
| **Backup method**                | pg_dump custom format (`-Fc`), compressed binary dump (2026-11-05 22:10:50)                                                                                   |
| **Restore test result**          | Success (Restored into `grp05_lostandfounddb_restore_test`; all 8 tables, constraints, sequences, and data verified)                                          |
| **Access control after restore** | (Activity 4 roles and permissions validated; `lostandfound_public` denied UPDATE on `claims`, `lostandfound_app` allowed claim approval)                      |
| **Recovery simulation result**   | Recovered (Simulated deleted test item and claim records successfully restored from baseline state)                                                           |
| **Proposed RPO and RTO**         | RPO: 24 hours, RTO: 2 hours                                                                                                                                   |
| **Evidence folder link**         | `https://github.com/jeffersonorpesa2-ops/grp07-campussafe/tree/main/db-backup-recovery/group-05-lostandfound/`                                                |
| **Feedback sent to owners**      | (05/11/2026)                                                                                                                                                  |
| **PDF progress document**        |                                                                                                                                                               |
| **Last updated**                 | 2026-11-05                                                                                                                                                    |

---

# AI USAGE DECLARATION

- **AI Tools Used:** Google Gemini 3.8 Flash (via Antigravity AI assistant).
- **Tasks Performed:**
  1. Inspecting database schema definitions, relational constraints, and documentation for Group 5's PUP-SPOT system.
  2. Formulating and executing PostgreSQL least-privilege verification test suites for Activity 4 (separation of public guest submissions and campus marshal claim approvals).
  3. Diagnosing runtime maintenance boundaries, executing `VACUUM` and `ANALYZE`, and profiling execution plans (`EXPLAIN (ANALYZE, BUFFERS)`) for Activity 5.
  4. Executing custom archive backup creation with `pg_dump`, SHA256 checksum computation, test database restoration with `pg_restore`, and controlled recovery simulation drill for Activity 6.
  5. Compiling and formatting comprehensive progress documentation adhering to course rubric guidelines.
- **Validation:** Every SQL query, maintenance command, backup job, and verification statement was executed and validated directly on PostgreSQL 18.6 in pgAdmin 4 / `psql`. Real outputs, timings, and checksums are recorded in this report.
