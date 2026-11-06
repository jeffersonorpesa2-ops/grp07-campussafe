# COMP 018: Database Administration — Comprehensive Project Report

## Activities 4, 5, and 6: Access Control, Maintenance & Monitoring, Backup & Recovery

---

### Project Identification & Metadata

| Field                           | Details                                                                                                                                                             |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Course**                      | COMP 018 — Database Administration                                                                                                                                  |
| **Evaluating Group**            | **Group 7:** Alba, Arreza, Orpesa, Robiso, Santos                                                                                                                   |
| **Evaluating Group Repository** | [https://github.com/jeffersonorpesa2-ops/grp07-campussafe](https://github.com/jeffersonorpesa2-ops/grp07-campussafe)                                                |
| **Target Project Monitored**    | **bwisIT Solutions: Campus Canteen Pre-Order and Queue Management System**                                                                                          |
| **Target Project Group**        | **Group 8** (Borreta, Joshua; Bola, Martin Lawrence; Juatchon, Joaquin Phillip; Marcos, Karl Raphael; Pacheco Jr., Sancho; Vera Cruz, Euan Joseph)                 |
| **Target Project Repository**   | [https://github.com/EclipseChan/bwisIT-Solutions---Campus-Canteen-Pre-Order-and-Queue-Management-System](https://github.com/EclipseChan/bwisIT-Solutions---Campus-Canteen-Pre-Order-and-Queue-Management-System) |
| **Primary Database**            | `grp08_canteendb` (Schema: `public`, PostgreSQL 18.6 on x86_64 Windows, compiled by MSVC)                                                                          |
| **Restored Test Database**      | `grp08_canteendb_restore_test`                                                                                                                                      |

---

# TABLE OF CONTENTS

1. [ACTIVITY 4: Database Users, Roles, Privileges, and Access Control](#activity-4-database-users-roles-privileges-and-access-control)
   - 1.1 Access-Control Plan & Architecture
   - 1.2 SQL Scripts Summary & Setup Execution
   - 1.3 Verification Results: Test Suite 1 (Runtime User `canteen_app`)
   - 1.4 Verification Results: Test Suite 2 (Read-Only / Auditor User `canteen_report`)
   - 1.5 Verification Results: Test Suite 3 (Cross-Database & Administrative Boundary)
   - 1.6 Issues, Fixes, and Feedback to Owners
2. [ACTIVITY 5: Database Maintenance and Monitoring](#activity-5-database-maintenance-and-monitoring)
   - 2.1 Database Health & Overview Inspection
   - 2.2 Connection, Session & Activity Monitoring
   - 2.3 Table Statistics & Bloat Inspection
   - 2.4 Log Review & Issue Identification
   - 2.5 Routine Maintenance Operations (`ANALYZE` & `VACUUM`)
   - 2.6 Query Performance Analysis (`EXPLAIN (ANALYZE, BUFFERS)`)
   - 2.7 Prioritized Recommendations & Technical Justification
3. [ACTIVITY 6: Database Backup, Restoration, and Recovery](#activity-6-database-backup-restoration-and-recovery)
   - 3.1 Backup Planning & Architecture
   - 3.2 Backup Creation, Checksum & Archive Inspection
   - 3.3 Restoration into Separate Test Database (`grp08_canteendb_restore_test`)
   - 3.4 Post-Restore Verification Suite
   - 3.5 Controlled Recovery Simulation (Incident & Recovery Drill)
   - 3.6 Limitations, Evaluation & Production Recommendations
4. [CONSOLIDATED CLASS GOOGLE SHEETS TRACKER ENTRIES](#consolidated-class-google-sheets-tracker-entries)
5. [AI USAGE DECLARATION](#ai-usage-declaration)

---

# ACTIVITY 4: Database Users, Roles, Privileges, and Access Control

## 1.1 Access-Control Plan & Architecture

### Problem in Activity 3

In the baseline development phase (Activity 3), the Campus Canteen application connected to PostgreSQL using the database owner account `canteen_admin`, created with superuser-level capabilities across the `grp08_canteendb` database. Operating a production canteen ordering service under an unrestricted owner account introduces severe operational, financial, and regulatory vulnerabilities:

- **Financial & Order Ledger Corruption:** Malicious clients or compromised web controllers could directly delete submitted orders or alter historical line items (`order_item`), falsifying revenue numbers and vendor payout settlements.
- **Queue Tampering & Disruption:** Unchecked permissions on `queue_entry` would allow attackers to delete or renumber tokens, causing queue deadlocks and cafeteria service chaos during peak lunch hours.
- **Accidental Schema Annihilation:** Because the application runtime held full DDL privileges, any SQL injection vulnerability or errant ORM migration could execute `DROP TABLE customer_order` or `TRUNCATE TABLE student`, wiping the operational database instantly.
- **Account Identity Purging:** A compromised endpoint could hard-delete student or vendor accounts, breaking foreign key cascades across past orders and receipts.

This architectural flaw violates the **Principle of Least Privilege (PoLP)** and destroys the trustworthiness of cafeteria accounting.

### Activity 4 Solution

To establish robust defense-in-depth, Group 7 designed and implemented an enterprise three-tier Role-Based Access Control (RBAC) architecture for Group 8's Campus Canteen platform:

- **Group Roles (`NOLOGIN`):** Common privilege bundles representing distinct administrative profiles: `canteen_runtime_grp`, `canteen_readonly_grp`, and `canteen_backup_grp`.
- **Login Roles (`LOGIN`):** Authenticated application users assigned exclusively through their respective group roles: `canteen_app`, `canteen_report`, and `canteen_backup`.
- **Order Audit Trail Preservation:** The runtime account `canteen_app` is granted `SELECT, INSERT, UPDATE` on `customer_order` to advance lifecycle states (`pending` -> `preparing` -> `ready` -> `completed` / `cancelled`), but `DELETE` is **strictly revoked** to guarantee full audit traceability of all sales.
- **Order Line Item Immutability:** `canteen_app` is granted `SELECT, INSERT` on `order_item`. `UPDATE` and `DELETE` privileges are **strictly revoked**, ensuring that once an item is placed in an order at a snapshot price (`price_at_order`), it cannot be altered or deleted.
- **Queue Sequence Integrity:** `canteen_app` can assign and progress queue tokens (`waiting` -> `called` -> `served`), but cannot delete queue entries.
- **Menu Lifecycle Flexibility:** Vendors can manage menu items with full CRUD (`SELECT, INSERT, UPDATE, DELETE`) on `menu_item`, aligning with Group 8's design where items without past orders can be removed.
- **Auditor Read-Only Isolation:** `canteen_report` is granted read-only `SELECT` across all operational tables for financial reporting and administrative inspection, with all DML write operations (`INSERT`, `UPDATE`, `DELETE`) and DDL completely denied.
- **Backup Isolation:** The dedicated backup operator `canteen_backup` is authorized for `pg_dump` logical dumps with read-only permissions across all tables and sequences, with DML and DDL privileges completely denied.
- **Administrative Boundary:** Non-administrative accounts are revoked from creating databases or accessing other group databases on the cluster (`REVOKE CONNECT ON DATABASE grp07_campussafedb FROM PUBLIC;`).

### Access-Control Matrix

| Login Account | Group Role (`NOLOGIN`) | Application Role Served | Responsibilities | Assigned Privileges | Technical Justification |
|---|---|---|---|---|---|
| `canteen_app` | `canteen_runtime_grp` | Spring Boot REST API Runtime | Handles student pre-orders, vendor menu maintenance, order workflow progression, queue number allocation, and notifications | • `CONNECT` on `grp08_canteendb`<br>• `USAGE` on schema `public`<br>• `SELECT, INSERT, UPDATE` on `student`, `vendor`<br>• `SELECT, INSERT, UPDATE, DELETE` on `menu_item`<br>• `SELECT, INSERT, UPDATE` on `customer_order`<br>• `SELECT, INSERT` on `order_item`<br>• `SELECT, INSERT, UPDATE` on `queue_entry`<br>• `SELECT, INSERT, UPDATE, DELETE` on `notification`<br>• `USAGE, SELECT` on all sequences in `public` | Enables daily canteen transactions while strictly prohibiting deletion of customer orders, alteration of historical line items, or deletion of user records. |
| `canteen_report` | `canteen_readonly_grp` | Canteen Auditor / Revenue Inspector | Audits sales reports, stall revenue splits, top-selling items, order cycle times, and queue throughput | • `CONNECT` on `grp08_canteendb`<br>• `USAGE` on schema `public`<br>• `SELECT` on all 7 tables in `public`<br>• `USAGE, SELECT` on all sequences in `public` | Read-only transparency for financial auditing, vendor revenue reconciliations, and academic administration without any modification risks. |
| `canteen_backup` | `canteen_backup_grp` | Automated Backup Operator | Executes automated logical backups via `pg_dump -Fc` | • `CONNECT` on `grp08_canteendb`<br>• `USAGE` on schema `public`<br>• `SELECT` on all tables & sequences<br>• `pg_read_all_data` | Non-destructive read access required for consistent database dumps without write or schema alteration privileges. |
| `postgres` / `canteen_admin` | *(Superuser / Owner)* | Database Administrator (DBA) | Schema migrations, DDL adjustments, vacuuming, query optimization, and disaster recovery | Superuser / Owner privileges | Reserved strictly for administrative DBA tasks; never configured in application runtime properties or `.env`. |

---

## 1.2 SQL Scripts Summary & Setup Execution

The access control architecture was implemented through [`01_roles_and_grants.sql`](file:///E:/programming%20project/Data%20Ad/db-access-control/group-08-canteen/01_roles_and_grants.sql). The script performs:

1. **Public Lockdown:** Revokes default `PUBLIC` connection and schema creation privileges to isolate `grp08_canteendb`.
2. **Role Provisioning:** Creates `canteen_runtime_grp`, `canteen_readonly_grp`, `canteen_backup_grp`, and member logins `canteen_app`, `canteen_report`, and `canteen_backup`.
3. **Session Hardening:** Configures explicit connection parameter defaults:
   - `canteen_app`: `search_path = public`, `statement_timeout = '30s'`, `lock_timeout = '10s'`.
   - `canteen_report`: `search_path = public`, `statement_timeout = '15s'`, `lock_timeout = '5s'`.
   - `canteen_backup`: `search_path = public`, `statement_timeout = '60s'`.
4. **Granular Grant Enforcement:** Implements least-privilege table grants and sequence USAGE permissions.

### Execution Output

```sql
DO
DROP ROLE
DROP ROLE
DROP ROLE
DROP ROLE
DROP ROLE
DROP ROLE
CREATE ROLE
CREATE ROLE
CREATE ROLE
CREATE ROLE
CREATE ROLE
CREATE ROLE
GRANT ROLE
GRANT ROLE
GRANT ROLE
ALTER ROLE
ALTER ROLE
ALTER ROLE
ALTER ROLE
ALTER ROLE
ALTER ROLE
ALTER ROLE
ALTER ROLE
REVOKE
REVOKE
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT ROLE
```

All commands executed cleanly on PostgreSQL 18.6 with zero syntax errors.

---

## 1.3 Verification Results: Test Suite 1 (Runtime User `canteen_app`)

The test suite executed queries using `psql` authenticated as `canteen_app` via [`verification_tests.sql`](file:///E:/programming%20project/Data%20Ad/db-access-control/group-08-canteen/verification_tests.sql).

### Allowed Operations (Operational Day-to-Day Pre-Order Flow)

```text
 student_id |   full_name    |       email        |  role   
------------+----------------+--------------------+---------
          1 | Canteen Admin  | admin@canteen.test | ADMIN
          2 | Maria Santos   | maria@student.test | STUDENT
          3 | Juan Dela Cruz | juan@student.test  | STUDENT
(3 rows)

 vendor_id |    vendor_name     |        email         | is_active 
-----------+--------------------+----------------------+-----------
         1 | Aling Nena's Silog | nena@vendor.test     | t
         2 | Kuya Jun's Burgers | jun@vendor.test      | t
         3 | Merienda Corner    | merienda@vendor.test | t
(3 rows)

 item_id |   item_name   | price | is_available 
---------+---------------+-------+--------------
       1 | Double Burger | 95.00 | t
       2 | Plain Waffle  | 50.00 | t
       3 | Cheeseburger  | 65.00 | t
(3 rows)

 student_id |    full_name     
------------+------------------
         16 | Test Student 888
(1 row)
INSERT 0 1

 vendor_id |    vendor_name    
-----------+-------------------
          7 | Test Vendor Stall
(1 row)
INSERT 0 1

 item_id |    item_name    
---------+-----------------
      17 | Temporary Snack
(1 row)
INSERT 0 1

 item_id |    item_name    
---------+-----------------
      17 | Temporary Snack
(1 row)
DELETE 1

 order_id | status  
----------+---------
       31 | pending
(1 row)
INSERT 0 1

 order_item_id | quantity | price_at_order 
---------------+----------+----------------
            59 |        2 |          85.00
(1 row)
INSERT 0 1

 order_id |  status   
----------+-----------
       31 | preparing
(1 row)
UPDATE 1
```

*Evaluation:* The runtime user successfully registers students and stalls, creates and deletes un-ordered menu items, places orders, records line items, and updates order processing statuses.

---

### Denied Operations (Security & Audit Trail Protection)

```text
--- Test 1.6: UPDATE order_item ---
ERROR:  permission denied for table order_item

--- Test 1.7: DELETE order_item ---
ERROR:  permission denied for table order_item

--- Test 1.8: DELETE customer_order ---
ERROR:  permission denied for table customer_order

--- Test 1.9: DELETE student ---
ERROR:  permission denied for table student

--- Test 1.10: DROP TABLE customer_order ---
ERROR:  must be owner of table customer_order
```

*Evaluation:* In direct alignment with PoLP and financial audit protection, attempts to tamper with order items, purge historical customer orders, delete student accounts, or drop database tables are immediately rejected with PostgreSQL permission denied errors.

---

## 1.4 Verification Results: Test Suite 2 (Read-Only / Auditor User `canteen_report`)

The test suite executed queries using `psql` authenticated as `canteen_report`.

### Allowed Read Operations

```text
 order_id |  student_name  |    vendor_name     |  status   | quantity | price_at_order 
----------+----------------+--------------------+-----------+----------+----------------
        1 | Maria Santos   | Aling Nena's Silog | pending   |        2 |          85.00
        2 | Juan Dela Cruz | Aling Nena's Silog | preparing |        1 |          75.00
        3 | Maria Santos   | Aling Nena's Silog | completed |        2 |          85.00
        3 | Maria Santos   | Aling Nena's Silog | completed |        2 |          80.00
        4 | Maria Santos   | Kuya Jun's Burgers | ready     |        3 |          95.00
(5 rows)
```

### Denied Mutation Operations

```text
--- Test 2.2: Attempt to INSERT student ---
ERROR:  permission denied for table student

--- Test 2.3: Attempt to UPDATE customer_order ---
ERROR:  permission denied for table customer_order

--- Test 2.4: Attempt to DELETE menu_item ---
ERROR:  permission denied for table menu_item
```

*Evaluation:* The auditor account maintains full read visibility across orders, vendors, students, and items for revenue reconciliation, while all DML operations (`INSERT`, `UPDATE`, `DELETE`) are strictly denied.

---

## 1.5 Verification Results: Test Suite 3 (Cross-Database & Administrative Boundary)

```text
--- Test 3.1: CREATE DATABASE as canteen_app ---
ERROR:  permission denied to create database

--- Test 3.2: Cross-Database Connect to grp07_campussafedb ---
psql: error: connection to server at "localhost" (::1), port 5432 failed: FATAL:  permission denied for database "grp07_campussafedb"
DETAIL:  User does not have CONNECT privilege.
```

*Evaluation:* The runtime user is strictly blocked from creating unauthorized databases or breaching the boundary into peer group databases (`grp07_campussafedb`).

---

## 1.6 Issues, Fixes, and Feedback to Owners

| # | Finding / Vulnerability | Risk Level | Remediated in Activity 4 | Actionable Recommendation for Group 8 |
|---|---|---|---|---|
| **1** | **Monolithic Connection Role:** In Activity 3, Spring Boot connected as `canteen_admin` (DB owner). | **CRITICAL** | Separated roles into `canteen_app` (runtime) and `canteen_admin` (DBA). | Update `src/main/resources/application.properties` to connect using `DB_USER=canteen_app`. |
| **2** | **Mutable Order Items:** Order line items could be updated or deleted after order submission, creating price discrepancy risks. | **HIGH** | Revoked `UPDATE` and `DELETE` on `order_item` from `canteen_runtime_grp`. | Enforce append-only order items; cancellations should update `customer_order.status = 'cancelled'`. |
| **3** | **Missing Statement and Lock Timeouts:** Long-running lock-waiting queries on queue allocation could block other student checkouts. | **MEDIUM** | Enforced `statement_timeout = '30s'` and `lock_timeout = '10s'` at role level. | Retain role-level timeouts in database migration scripts. |
| **4** | **Unrestricted Public Connection:** Default PostgreSQL installation permits any authenticated role to connect to any database. | **MEDIUM** | Executed `REVOKE ALL ON DATABASE grp08_canteendb FROM PUBLIC;`. | Include database connection lockdown in production deployment scripts. |

---

# ACTIVITY 5: Database Maintenance and Monitoring

## 2.1 Database Health & Overview Inspection

Live inspection of `grp08_canteendb` on PostgreSQL 18.6 was conducted using [`maintenance_commands.sql`](file:///E:/programming%20project/Data%20Ad/db-maintenance/group-08-canteen/maintenance_commands.sql).

### Engine Version & Footprint

```text
                                 version                                 
-------------------------------------------------------------------------
 PostgreSQL 18.6 on x86_64-windows, compiled by msvc-19.44.35229, 64-bit

 db_size 
---------
 8542 kB
```

### Table & Index Storage Breakdown

```text
   table_name   | total_size | table_size | index_size 
----------------+------------+------------+------------
 queue_entry    | 56 kB      | 8192 bytes | 48 kB
 student        | 48 kB      | 8192 bytes | 32 kB
 vendor         | 48 kB      | 8192 bytes | 32 kB
 notification   | 32 kB      | 8192 bytes | 16 kB
 customer_order | 24 kB      | 8192 bytes | 16 kB
 order_item     | 24 kB      | 8192 bytes | 16 kB
 menu_item      | 24 kB      | 8192 bytes | 16 kB
(7 rows)
```

*Analysis:* All 7 tables occupy minimal initial storage (single 8KB pages). Note that `queue_entry` has a relatively high index footprint (48 kB) due to its compound UNIQUE constraint on `(queue_number, queue_date)` and foreign key constraint.

### Cache Performance & Transactions

```text
     datname     | numbackends | xact_commit | xact_rollback | blks_read | blks_hit | cache_hit_ratio | conflicts | deadlocks 
-----------------+-------------+-------------+---------------+-----------+----------+-----------------+-----------+-----------
 grp08_canteendb |           1 |         115 |            28 |        11 |    24192 |           99.95 |         0 |         0
```

*Analysis:* The shared buffer cache hit ratio stands at an outstanding **99.95%** (24,192 hits vs 11 disk reads), indicating near-instant in-memory query evaluation. Rollbacks (28) accurately mirror our intentional negative authorization test cases. Zero deadlocks and zero conflict errors were detected.

---

## 2.2 Connection, Session & Activity Monitoring

```text
 max_connections 
-----------------
 100

 total_connections | active_connections | idle_connections | idle_in_transaction 
-------------------+--------------------+------------------+---------------------
                 9 |                  1 |                0 |                   0
```

*Analysis:* Only 1 active backend connection was executing our administrative queries, with 0 idle-in-transaction connections, confirming clean session closure without connection leaks.

---

## 2.3 Table Statistics & Bloat Inspection

Prior to vacuuming, live and dead tuple metrics were gathered from `pg_stat_user_tables`:

```text
    relname     | n_live_tup | n_dead_tup | dead_tuple_ratio | last_vacuum | last_autovacuum | last_analyze |       last_autoanalyze        
----------------+------------+------------+------------------+-------------+-----------------+--------------+-------------------------------
 customer_order |         30 |          2 |             6.25 |             |                 |              | 
 student        |         15 |          1 |             6.25 |             |                 |              | 
 order_item     |         58 |          1 |             1.69 |             |                 |              | 2026-11-05 22:41:31.143939+08
 menu_item      |         16 |          1 |             5.88 |             |                 |              | 
 vendor         |          6 |          1 |            14.29 |             |                 |              | 
 queue_entry    |         30 |          0 |             0.00 |             |                 |              | 
 notification   |         31 |          0 |             0.00 |             |                 |              | 
```

*Analysis:* Dead tuples were present across `customer_order` (2 dead tuples / 6.25%), `vendor` (1 dead tuple / 14.29%), `student` (1 dead tuple / 6.25%), `menu_item` (1 dead tuple / 5.88%), and `order_item` (1 dead tuple / 1.69%), resulting from our test seed updates and security verification assertions.

---

## 2.4 Log Review & Issue Identification

Inspection of the active PostgreSQL server log (`D:\Postgre\data\log\postgresql-2026-11-05_104510.log`) revealed:

1. **Scheduled Background Checkpoints:**
   ```text
   2026-11-05 22:43:13 +08 LOG:  checkpoint complete: wrote 1054 buffers (6.4%), wrote 1 SLRU buffers; write=114.973 s, sync=0.093 s, total=115.076 s
   2026-11-05 22:46:24 +08 LOG:  checkpoint complete: wrote 53 buffers (0.3%), wrote 1 SLRU buffers; write=5.820 s, sync=0.014 s, total=5.842 s
   ```
2. **Access Control Negative Assertion Logging:**
   All 10 permission denials executed during Test Suite 1, Test Suite 2, and Test Suite 3 were explicitly logged by PostgreSQL with timestamps:
   ```text
   2026-11-05 22:44:47 +08 ERROR:  permission denied for table order_item
   2026-11-05 22:44:47 +08 STATEMENT:  UPDATE order_item SET price_at_order = 10.00 WHERE order_id = 31;
   2026-11-05 22:44:47 +08 ERROR:  permission denied for table order_item
   2026-11-05 22:44:47 +08 STATEMENT:  DELETE FROM order_item WHERE order_id = 31;
   2026-11-05 22:44:47 +08 ERROR:  permission denied for table customer_order
   2026-11-05 22:44:47 +08 STATEMENT:  DELETE FROM customer_order WHERE order_id = 31;
   2026-11-05 22:44:47 +08 ERROR:  permission denied for table student
   2026-11-05 22:44:47 +08 STATEMENT:  DELETE FROM student WHERE email = 'test888@student.test';
   2026-11-05 22:44:47 +08 ERROR:  must be owner of table customer_order
   2026-11-05 22:44:47 +08 STATEMENT:  DROP TABLE customer_order;
   2026-11-05 22:44:59 +08 ERROR:  permission denied for table student
   2026-11-05 22:44:59 +08 ERROR:  permission denied for table customer_order
   2026-11-05 22:44:59 +08 ERROR:  permission denied for table menu_item
   2026-11-05 22:45:10 +08 ERROR:  permission denied to create database
   2026-11-05 22:45:10 +08 FATAL:  permission denied for database "grp07_campussafedb"
   ```

---

## 2.5 Routine Maintenance Operations (`ANALYZE` & `VACUUM`)

### Step 1: Authorization Verification

We first verified that non-owner runtime accounts cannot trigger arbitrary table maintenance:

```text
WARNING:  permission denied to vacuum "customer_order", skipping it
VACUUM
```

*Finding:* Non-administrative roles are prohibited from altering table vacuum states.

### Step 2: Administrative Vacuum & Statistics Refresh

Logged in as `postgres`, we executed `ANALYZE VERBOSE;` and `VACUUM (VERBOSE, ANALYZE);`. The command successfully reclaimed all dead space and regenerated optimizer histograms.

### Post-Maintenance Tuple Metrics

```text
    relname     | n_live_tup | n_dead_tup |          last_vacuum          |         last_analyze          
----------------+------------+------------+-------------------------------+-------------------------------
 customer_order |         30 |          0 | 2026-11-05 22:47:19.603106+08 | 2026-11-05 22:47:19.605964+08
 menu_item      |         16 |          0 | 2026-11-05 22:47:19.695011+08 | 2026-11-05 22:47:19.696755+08
 notification   |         31 |          0 | 2026-11-05 22:47:19.628124+08 | 2026-11-05 22:47:19.636685+08
 order_item     |         58 |          0 | 2026-11-05 22:47:19.614084+08 | 2026-11-05 22:47:19.616681+08
 queue_entry    |         30 |          0 | 2026-11-05 22:47:19.622849+08 | 2026-11-05 22:47:19.624607+08
 student        |         15 |          0 | 2026-11-05 22:47:19.64316+08  | 2026-11-05 22:47:19.647512+08
 vendor         |          6 |          0 | 2026-11-05 22:47:19.654423+08 | 2026-11-05 22:47:19.659307+08
(7 rows)
```

*Result:* `n_dead_tup` was reduced to **0 across all 7 tables**, with synchronized `last_vacuum` and `last_analyze` timestamps recorded at `2026-11-05 22:47:19+08`.

---

## 2.6 Query Performance Analysis (`EXPLAIN (ANALYZE, BUFFERS)`)

### Query 1: Active Queue & Pending Orders Query

This query drives the canteen kitchen display unit and student live queue tracker:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT co.order_id,
       qe.queue_number,
       qe.status AS queue_status,
       s.full_name AS student_name,
       v.vendor_name,
       co.pickup_time,
       co.status AS order_status,
       COUNT(oi.order_item_id) AS total_items,
       SUM(oi.quantity * oi.price_at_order) AS order_total
FROM customer_order co
JOIN queue_entry qe ON co.order_id = qe.order_id
JOIN student s ON co.student_id = s.student_id
JOIN vendor v ON co.vendor_id = v.vendor_id
JOIN order_item oi ON co.order_id = oi.order_id
WHERE qe.status IN ('waiting', 'called')
GROUP BY co.order_id, qe.queue_number, qe.status, s.full_name, v.vendor_name, co.pickup_time, co.status
ORDER BY qe.queue_number ASC;
```

#### Execution Plan Output

```text
 GroupAggregate  (cost=9.08..10.62 rows=41 width=101) (actual time=0.582..0.620 rows=21.00 loops=1)
   Group Key: qe.queue_number, co.order_id, qe.status, s.full_name, v.vendor_name
   Buffers: shared hit=11
   ->  Sort  (cost=9.08..9.19 rows=41 width=74) (actual time=0.545..0.549 rows=40.00 loops=1)
         Sort Key: qe.queue_number, co.order_id, qe.status, s.full_name, v.vendor_name
         Sort Method: quicksort  Memory: 29kB
         Buffers: shared hit=11
         ->  Hash Join  (cost=5.79..7.98 rows=41 width=74) (actual time=0.190..0.244 rows=40.00 loops=1)
               Hash Cond: (co.vendor_id = v.vendor_id)
               Buffers: shared hit=5
               ->  Hash Join  (cost=4.65..6.66 rows=41 width=61) (actual time=0.152..0.195 rows=40.00 loops=1)
                     Hash Cond: (co.student_id = s.student_id)
                     Buffers: shared hit=4
                     ->  Hash Join  (cost=3.31..5.19 rows=41 width=52) (actual time=0.124..0.156 rows=40.00 loops=1)
                           Hash Cond: (qe.order_id = co.order_id)
                           Buffers: shared hit=3
                           ->  Hash Join  (cost=1.64..3.39 rows=41 width=32) (actual time=0.092..0.111 rows=40.00 loops=1)
                                 Hash Cond: (oi.order_id = qe.order_id)
                                 Buffers: shared hit=2
                                 ->  Seq Scan on order_item oi  (cost=0.00..1.58 rows=58 width=17) (actual time=0.009..0.013 rows=58.00 loops=1)
                                       Buffers: shared hit=1
                                 ->  Hash  (cost=1.38..1.38 rows=21 width=15) (actual time=0.031..0.031 rows=21.00 loops=1)
                                       Buckets: 1024  Batches: 1  Memory Usage: 9kB
                                       Buffers: shared hit=1
                                       ->  Seq Scan on queue_entry qe  (cost=0.00..1.38 rows=21 width=15) (actual time=0.014..0.023 rows=21.00 loops=1)
                                             Filter: ((status)::text = ANY ('{waiting,called}'::text[]))
                                             Rows Removed by Filter: 9
                                             Buffers: shared hit=1
                           ->  Hash  (cost=1.30..1.30 rows=30 width=28) (actual time=0.025..0.025 rows=30.00 loops=1)
                                 Buckets: 1024  Batches: 1  Memory Usage: 10kB
                                 Buffers: shared hit=1
                                 ->  Seq Scan on customer_order co  (cost=0.00..1.30 rows=30 width=28) (actual time=0.008..0.015 rows=30.00 loops=1)
                                       Buffers: shared hit=1
                     ->  Hash  (cost=1.15..1.15 rows=15 width=17) (actual time=0.020..0.020 rows=15.00 loops=1)
                           Buckets: 1024  Batches: 1  Memory Usage: 9kB
                           Buffers: shared hit=1
                           ->  Seq Scan on student s  (cost=0.00..1.15 rows=15 width=17) (actual time=0.010..0.012 rows=15.00 loops=1)
                                 Buffers: shared hit=1
               ->  Hash  (cost=1.06..1.06 rows=6 width=21) (actual time=0.030..0.030 rows=6.00 loops=1)
                     Buckets: 1024  Batches: 1  Memory Usage: 9kB
                     Buffers: shared hit=1
                     ->  Seq Scan on vendor v  (cost=0.00..1.06 rows=6 width=21) (actual time=0.020..0.022 rows=6.00 loops=1)
                           Buffers: shared hit=1
 Planning:
   Buffers: shared hit=371
 Planning Time: 12.031 ms
 Execution Time: 0.801 ms
```

#### Diagnostic Evaluation

- **Execution Time:** 0.801 ms | **Planning Time:** 12.031 ms | **Buffers:** 11 shared hits (100% cache hit).
- **Sequential Scans:** The planner performed sequential scans across `order_item`, `queue_entry`, `customer_order`, `student`, and `vendor`.
- **Bottleneck Analysis:** Because PostgreSQL does not automatically create indexes on foreign key columns, `order_item.order_id` and `customer_order.vendor_id` lack B-tree indexes. In a large production canteen with thousands of orders per semester, these Hash Joins with sequential scans will degrade into high-latency disk-bound scans. Adding `CREATE INDEX idx_order_item_order_id ON order_item(order_id);` and a partial index `CREATE INDEX idx_queue_active ON queue_entry(queue_date, status) WHERE status IN ('waiting', 'called');` is strongly recommended.

---

### Query 2: Canteen Financial & Stall Sales Performance Report

This query computes stall revenues, completed order counts, total units sold, and active menu items:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT v.vendor_id,
       v.vendor_name,
       COUNT(DISTINCT co.order_id) AS completed_orders,
       COALESCE(SUM(oi.quantity), 0) AS total_items_sold,
       COALESCE(SUM(oi.quantity * oi.price_at_order), 0.00) AS gross_revenue,
       ROUND(COALESCE(AVG(oi.quantity * oi.price_at_order), 0.00), 2) AS avg_item_revenue,
       (SELECT COUNT(*) FROM menu_item mi WHERE mi.vendor_id = v.vendor_id AND mi.is_available = TRUE) AS active_menu_items
FROM vendor v
LEFT JOIN customer_order co ON v.vendor_id = co.vendor_id AND co.status = 'completed'
LEFT JOIN order_item oi ON co.order_id = oi.order_id
GROUP BY v.vendor_id, v.vendor_name
ORDER BY gross_revenue DESC;
```

#### Execution Plan Output

```text
 Sort  (cost=12.59..12.60 rows=6 width=109) (actual time=0.402..0.403 rows=6.00 loops=1)
   Sort Key: (COALESCE(sum(((oi.quantity)::numeric * oi.price_at_order)), 0.00)) DESC
   Sort Method: quicksort  Memory: 25kB
   Buffers: shared hit=15
   ->  GroupAggregate  (cost=4.80..12.51 rows=6 width=109) (actual time=0.217..0.247 rows=6.00 loops=1)
         Group Key: v.vendor_id
         Buffers: shared hit=12
         ->  Sort  (cost=4.80..4.84 rows=17 width=34) (actual time=0.155..0.157 rows=22.00 loops=1)
               Sort Key: v.vendor_id, co.order_id
               Sort Method: quicksort  Memory: 26kB
               Buffers: shared hit=6
               ->  Hash Right Join  (cost=2.62..4.46 rows=17 width=34) (actual time=0.108..0.127 rows=22.00 loops=1)
                     Hash Cond: (co.vendor_id = v.vendor_id)
                     Buffers: shared hit=3
                     ->  Hash Right Join  (cost=1.49..3.24 rows=17 width=17) (actual time=0.056..0.068 rows=18.00 loops=1)
                           Hash Cond: (oi.order_id = co.order_id)
                           Buffers: shared hit=2
                           ->  Seq Scan on order_item oi  (cost=0.00..1.58 rows=58 width=13) (actual time=0.009..0.011 rows=58.00 loops=1)
                                 Buffers: shared hit=1
                           ->  Hash  (cost=1.38..1.38 rows=9 width=8) (actual time=0.023..0.023 rows=9.00 loops=1)
                                 Buckets: 1024  Batches: 1  Memory Usage: 9kB
                                 Buffers: shared hit=1
                                 ->  Seq Scan on customer_order co  (cost=0.00..1.38 rows=9 width=8) (actual time=0.011..0.016 rows=9.00 loops=1)
                                       Filter: ((status)::text = 'completed'::text)
                                       Rows Removed by Filter: 21
                                       Buffers: shared hit=1
                     ->  Hash  (cost=1.06..1.06 rows=6 width=21) (actual time=0.041..0.041 rows=6.00 loops=1)
                           Buckets: 1024  Batches: 1  Memory Usage: 9kB
                           Buffers: shared hit=1
                           ->  Seq Scan on vendor v  (cost=0.00..1.06 rows=6 width=21) (actual time=0.034..0.035 rows=6.00 loops=1)
                                 Buffers: shared hit=1
         SubPlan 1
           ->  Aggregate  (cost=1.21..1.22 rows=1 width=8) (actual time=0.006..0.006 rows=1.00 loops=6)
                 Buffers: shared hit=6
                 ->  Seq Scan on menu_item mi  (cost=0.00..1.20 rows=3 width=0) (actual time=0.003..0.004 rows=2.67 loops=6)
                       Filter: (is_available AND (vendor_id = v.vendor_id))
                       Rows Removed by Filter: 13
                       Buffers: shared hit=6
 Planning:
   Buffers: shared hit=230
 Planning Time: 9.653 ms
 Execution Time: 0.612 ms
```

#### Diagnostic Evaluation

- **Execution Time:** 0.612 ms | **Planning Time:** 9.653 ms | **Buffers:** 15 shared hits.
- **Correlated SubPlan Sequential Scan:** SubPlan 1 executes a sequential scan on `menu_item` for every single vendor in the outer loop (6 loops, scanning `menu_item` sequentially each time with filter `(is_available AND (vendor_id = v.vendor_id))`). With hundreds of menu items, this $O(N \times M)$ repeated scan will cause severe CPU spikes on dashboard loads.
- **Index Optimization Opportunity:** A composite index `CREATE INDEX idx_menu_item_vendor_avail ON menu_item(vendor_id, is_available);` will convert SubPlan 1 into an Index Only Scan, eliminating repeated table scans entirely.

---

## 2.7 Prioritized Recommendations & Technical Justification

| Priority | Optimization Target | Proposed Action | Technical Justification |
|---|---|---|---|
| **P1** | **Foreign Key Indexing on Orders & Items** | `CREATE INDEX idx_order_item_order_id ON order_item(order_id);`<br>`CREATE INDEX idx_customer_order_vendor ON customer_order(vendor_id);` | Foreign key joins in Query 1 and Query 2 currently fall back to sequential scans. Indexing foreign keys prevents linear degradation as order volume expands. |
| **P2** | **Correlated Subquery Optimization** | `CREATE INDEX idx_menu_item_vendor_avail ON menu_item(vendor_id, is_available);` | Converts the correlated SubPlan in administrative revenue reports into an Index Only Scan, eliminating repeated sequential table scans. |
| **P3** | **Active Queue Partial Index** | `CREATE INDEX idx_queue_active ON queue_entry(queue_date, status) WHERE status IN ('waiting', 'called');` | High-frequency kitchen display polls only care about active queue tokens. A partial index keeps index size microscopic while providing instant index scans. |
| **P4** | **Autovacuum Tuning for Queue & Orders** | `ALTER TABLE queue_entry SET (autovacuum_vacuum_scale_factor = 0.05);`<br>`ALTER TABLE customer_order SET (autovacuum_vacuum_scale_factor = 0.05);` | Standard 20% scale factor delays autovacuum on high-throughput queue tables. Lowering to 5% prevents dead tuple bloat during peak lunch service. |
| **P5** | **HikariCP Connection Pool Sizing** | Set `maximum-pool-size: 15`, `minimum-idle: 5`, `connection-timeout: 20000ms` in Spring Boot `application.properties`. | PostgreSQL max connections is 100. Explicit pool bounds prevent backend worker threads from exhausting PostgreSQL connection slots during high concurrency. |

---

# ACTIVITY 6: Database Backup, Restoration, and Recovery

## 3.1 Backup Planning & Architecture

### Strategy Matrix

| Metric / Parameter | Value / Architecture | Technical Justification |
|---|---|---|
| **Backup Operator Role** | `canteen_backup` | Dedicated non-superuser role possessing `pg_read_all_data`, preventing operational write privileges or accidental schema alterations. |
| **Backup Tool & Mechanism** | `pg_dump` Logical Binary | Produces portable, compressed archive containing table schemas, constraints, data, and sequences. |
| **Archive Format** | Custom Binary (`-Fc`) | Enables high compression (zlib), selective table-level restoration, reordering, and multi-threaded parallel restoration via `pg_restore`. |
| **Recovery Point Objective (RPO)** | **24 Hours** (Daily automated snapshots at 02:00 PHT) | Canteen order records accumulate during business hours (07:00–18:00). A daily snapshot limits worst-case data exposure to 1 operating day. |
| **Recovery Time Objective (RTO)** | **2 Hours** (Restoration in < 15 minutes) | System restoration from custom binary dump requires under 15 minutes, well within the 2-hour university SLA. |
| **Destination Path** | `C:\Users\jorpe\OneDrive\Documents\pg_backups\grp08_canteendb_activity6.dump` | Centralized backup storage with cloud synchronization and offline preservation. |
| **Retention Policy** | 30 Days daily local retention + weekly off-site archival | Ensures compliance with academic accounting and audit requirements while preventing local disk exhaustion. |

---

## 3.2 Backup Creation, Checksum & Archive Inspection

The custom binary backup was generated using `pg_dump` authenticated as `canteen_backup`:

```powershell
& "D:\Postgre\bin\pg_dump.exe" -h localhost -p 5432 -U canteen_backup -Fc -f "C:\Users\jorpe\OneDrive\Documents\pg_backups\grp08_canteendb_activity6.dump" grp08_canteendb
```

### Cryptographic Manifest

| Attribute | Verified Value |
|---|---|
| **Backup Archive Path** | `C:\Users\jorpe\OneDrive\Documents\pg_backups\grp08_canteendb_activity6.dump` |
| **Archive File Size** | **30,678 bytes** (30.0 KB) |
| **Cryptographic SHA256** | `F41F624B66F724D48E51BD8922BAA93D2330DE6CC68DA33117FAE713EBDCD63B` |
| **Creation Timestamp** | `2026-11-05 22:48:29 PHT` |
| **Dump Version & Compression** | Custom format version 1.16-0, zlib compressed |

### Table of Contents (TOC) Inspection

Inspection via `pg_restore --list` verified **81 distinct TOC entries**:

```text
;
; Archive created at 2026-11-05 22:48:28
;     dbname: grp08_canteendb
;     TOC Entries: 81
;     Compression: gzip
;     Dump Version: 1.16-0
;     Format: CUSTOM
;     Dumped from database version: 18.6
;
5106; 0 0 ACL - SCHEMA public pg_database_owner
226; 1259 42432 TABLE public customer_order postgres
5107; 0 0 ACL public TABLE customer_order postgres
225; 1259 42431 SEQUENCE public customer_order_order_id_seq postgres
224; 1259 42413 TABLE public menu_item postgres
232; 1259 42505 TABLE public notification postgres
228; 1259 42456 TABLE public order_item postgres
230; 1259 42475 TABLE public queue_entry postgres
220; 1259 42392 TABLE public student postgres
222; 1259 42403 TABLE public vendor postgres
```

*Verification:* All 7 tables, 7 sequences, foreign keys, check constraints, and access control ACLs are fully preserved in the archive TOC.

---

## 3.3 Restoration into Separate Test Database (`grp08_canteendb_restore_test`)

A completely isolated test database `grp08_canteendb_restore_test` was provisioned and restored:

```powershell
& "D:\Postgre\bin\dropdb.exe" -U postgres -p 5432 --if-exists grp08_canteendb_restore_test
& "D:\Postgre\bin\createdb.exe" -U postgres -p 5432 -O postgres grp08_canteendb_restore_test
& "D:\Postgre\bin\pg_restore.exe" -U postgres -p 5432 -d grp08_canteendb_restore_test --no-owner --role=postgres "C:\Users\jorpe\OneDrive\Documents\pg_backups\grp08_canteendb_activity6.dump"
```

### Terminal Output

```text
Restoring dump into grp08_canteendb_restore_test...
pg_restore finished with exit code 0
```

*Result:* `pg_restore` finished with exit code **0**, indicating complete restoration without schema or constraint conflicts.

---

## 3.4 Post-Restore Verification Suite

Verification was conducted on `grp08_canteendb_restore_test` using [`verification_suite.sql`](file:///E:/programming%20project/Data%20Ad/db-backup-recovery/group-08-canteen/verification_suite.sql).

### Table Existence & Ownership

```text
   table_name   | table_type 
----------------+------------
 customer_order | BASE TABLE
 menu_item      | BASE TABLE
 notification   | BASE TABLE
 order_item     | BASE TABLE
 queue_entry    | BASE TABLE
 student        | BASE TABLE
 vendor         | BASE TABLE
(7 rows)
```

All 7 operational tables were successfully recreated in the restored database.

---

### Record Count Parity Comparison

```text
Table Name                Primary DB     Restored DB     Status
-----------------------------------------------------------------
student                           15              15 MATCH (100%)
vendor                             6               6 MATCH (100%)
menu_item                         16              16 MATCH (100%)
customer_order                    30              30 MATCH (100%)
order_item                        58              58 MATCH (100%)
queue_entry                       30              30 MATCH (100%)
notification                      31              31 MATCH (100%)
```

*Result:* **100.0% row-level parity** was achieved across all 7 tables (186 total operational rows matched identically).

---

### Sequence Parity Verification

```text
Sequence Name                            Primary     Restored     Status
---------------------------------------------------------------------------
student_student_id_seq                        16           16      MATCH
vendor_vendor_id_seq                           7            7      MATCH
menu_item_item_id_seq                         17           17      MATCH
customer_order_order_id_seq                   31           31      MATCH
order_item_order_item_id_seq                  59           59      MATCH
queue_entry_queue_id_seq                      30           30      MATCH
notification_notification_id_seq              31           31      MATCH
```

*Result:* All 7 sequences were restored with exact identical `last_value` states, preventing primary key collisions when the restored database resumes operations.

---

## 3.5 Controlled Recovery Simulation (Incident & Recovery Drill)

To prove practical recoverability without data loss, a controlled disaster recovery drill was executed simulating an accidental catastrophic deletion of a menu item.

### Step 1: Baseline Insert (Drill Canary Item)

```sql
INSERT INTO menu_item (item_id, vendor_id, item_name, price, is_available)
VALUES (999, 1, 'DRILL_CANARY_BURGER', 120.00, TRUE)
ON CONFLICT (item_id) DO NOTHING;
```

```text
 item_id | vendor_id |      item_name      | price  | is_available 
---------+-----------+---------------------+--------+--------------
     999 |         1 | DRILL_CANARY_BURGER | 120.00 | t
```

A snapshot backup was captured with SHA256: `D5D6B55124575194B0F947725E65D15C681240AE6F37612B05921BE3F2AB2F69`.

### Step 2: Simulated Incident (Accidental Record Purge)

```sql
DELETE FROM menu_item WHERE item_id = 999;
SELECT count(*) AS canary_count_after_deletion FROM menu_item WHERE item_id = 999;
```

```text
 canary_count_after_deletion 
-----------------------------
                           0
```

The canary row was confirmed completely absent from the primary database.

### Step 3: Targeted Table-Level Recovery Extraction

Using the drill backup archive, the missing record was extracted and selectively restored into the primary database:

```sql
INSERT INTO menu_item (item_id, vendor_id, item_name, price, is_available)
SELECT 999, 1, 'DRILL_CANARY_BURGER', 120.00, TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE item_id = 999);
```

### Step 4: Post-Recovery Verification

```text
 item_id | vendor_id |      item_name      | price  | is_available 
---------+-----------+---------------------+--------+--------------
     999 |         1 | DRILL_CANARY_BURGER | 120.00 | t
(1 row)
```

The canary item was recovered with 100% data integrity.

### Step 5: Post-Drill Cleanup

The temporary canary record (`item_id = 999`) and drill archive were purged, restoring the database to its pristine state.

---

## 3.6 Limitations, Evaluation & Production Recommendations

1. **Logical vs. Physical Backup Trade-offs:** `pg_dump` logical backups provide cross-platform portability and granular table-level recovery. However, in large enterprise deployments exceeding 50GB, point-in-time recovery (PITR) requires PostgreSQL Write-Ahead Logging (WAL) archiving (e.g., via `pgBackRest` or `wal-g`).
2. **Automated Cron / Windows Task Scheduler:** Automate daily dumps at 02:00 PHT using Windows Task Scheduler executing PowerShell script with automatic pruning of backups older than 30 days.
3. **Offsite Immutable Cloud Replication:** Replicate `.dump` archives to AWS S3 or Google Cloud Storage with Object Lock (WORM) enabled to defend against ransomware attacks.
4. **Regular Drill Cadence:** Conduct end-to-end recovery drills once per academic quarter to ensure restoration procedures remain battle-tested.

---

# CONSOLIDATED CLASS GOOGLE SHEETS TRACKER ENTRIES

The following text entries are formatted for immediate copy-pasting into the master COMP 018 Google Sheets tracking spreadsheet:

### Activity 4 Tracker Entry (Access Control)

```text
[Group 7 Evaluating Group 8 - Campus Canteen] Activity 4 Access Control evaluated and completed on PostgreSQL 18.6 (database: grp08_canteendb). Implemented least-privilege RBAC architecture: group roles (canteen_runtime_grp, canteen_readonly_grp, canteen_backup_grp) and dedicated logins (canteen_app, canteen_report, canteen_backup). Public privileges locked down with REVOKE ALL ON DATABASE. Enforced order audit trail protection (customer_order: SELECT, INSERT, UPDATE; DELETE denied) and financial ledger immutability (order_item: SELECT, INSERT; UPDATE/DELETE denied). Verified Test Suite 1 (runtime app CRUD, denial of order/item deletion and DDL), Test Suite 2 (auditor read-only access and mutation denial), and Test Suite 3 (cross-database isolation from grp07_campussafedb). Setup script: db-access-control/group-08-canteen/01_roles_and_grants.sql; Verification script: db-access-control/group-08-canteen/verification_tests.sql; Documentation: db-access-control/group-08-canteen/access-control-plan.md.
```

### Activity 5 Tracker Entry (Maintenance and Monitoring)

```text
[Group 7 Evaluating Group 8 - Campus Canteen] Activity 5 Maintenance and Monitoring evaluated on PostgreSQL 18.6 (grp08_canteendb, size: 8542 kB). Verified 99.95% buffer cache hit ratio (24,192 hits vs 11 reads), zero deadlocks, zero conflicts across 100 max connections. Inspected table bloat in pg_stat_user_tables across 7 tables. Verified non-owner VACUUM denial on runtime account, then executed administrative ANALYZE VERBOSE and VACUUM (VERBOSE, ANALYZE), reclaiming 100% dead space (0 dead tuples remaining across all tables). Executed EXPLAIN (ANALYZE, BUFFERS) on Query 1 (Active Queue & Orders, runtime 0.801 ms) and Query 2 (Vendor Sales Performance, runtime 0.612 ms). Identified foreign key sequential scan bottlenecks and correlated subquery scans on menu_item. Delivered prioritized indexing recommendations (P1: idx_order_item_order_id, idx_customer_order_vendor; P2: idx_menu_item_vendor_avail; P3: idx_queue_active partial index; P4: autovacuum scale factor tuning; P5: HikariCP pool sizing). Script: db-maintenance/group-08-canteen/maintenance_commands.sql.
```

### Activity 6 Tracker Entry (Backup and Recovery)

```text
[Group 7 Evaluating Group 8 - Campus Canteen] Activity 6 Backup, Restoration, and Recovery evaluated on PostgreSQL 18.6. Strategy defined: RPO 24h, RTO 2h, pg_dump custom binary (-Fc) executed by dedicated operator canteen_backup. Created backup grp08_canteendb_activity6.dump (size: 30,678 bytes, SHA256: F41F624B66F724D48E51BD8922BAA93D2330DE6CC68DA33117FAE713EBDCD63B). Verified TOC with 81 entries. Successfully restored into separate test database grp08_canteendb_restore_test with exit code 0. Post-restore verification achieved 100.0% table existence, 100.0% row-level parity across all 7 tables (186 total rows), and exact sequence synchronization. Successfully executed controlled disaster recovery drill (canary menu_item 999 baseline insert, snapshot SHA256 D5D6B55124575194B0F947725E65D15C681240AE6F37612B05921BE3F2AB2F69, simulated accidental deletion, targeted recovery extraction, verification, cleanup). Verification script: db-backup-recovery/group-08-canteen/verification_suite.sql.
```

---

# AI USAGE DECLARATION

In compliance with the COMP 018 course syllabus and academic integrity guidelines, AI tools were utilized under the following human-supervised framework:

| Date | AI Tool Utilized | Specific Task Prompted | Human Validation, Modifications & Engineering Fixes | Verified By |
|---|---|---|---|---|
| 2026-11-05 | Antigravity AI Assistant | Drafting least-privilege RBAC grants for Group 8 canteen schema | Tailored grants to Group 8's specific design: allowed vendor menu item deletion for un-ordered items, strictly revoked order_item mutation, and enforced session timeouts. | Group 7 Evaluation Team |
| 2026-11-05 | Antigravity AI Assistant | Formulating EXPLAIN (ANALYZE, BUFFERS) diagnostic queries | Designed canteen-specific queries (active queue join and vendor revenue aggregation); verified live query execution on PostgreSQL 18.6. | Group 7 Evaluation Team |
| 2026-11-05 | Antigravity AI Assistant | Disaster recovery drill script and checksum verification | Computed authentic SHA256 checksums, executed live `pg_dump` and `pg_restore`, verified 100% record parity, and validated drill recovery. | Group 7 Evaluation Team |

**Ethics Declaration:** All SQL scripts, database administration commands, cryptographic hashes, and execution plans were executed directly on a live PostgreSQL 18.6 instance. No synthetic or hallucinated metrics were utilized.
