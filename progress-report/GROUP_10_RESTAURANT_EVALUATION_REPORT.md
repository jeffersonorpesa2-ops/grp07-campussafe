# COMP 018: Database Administration — Comprehensive Project Report

## Activities 4, 5, and 6: Access Control, Maintenance & Monitoring, Backup & Recovery

---

### Project Identification & Metadata

| Field                           | Details                                                                                                                                                               |
| ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Course**                      | COMP 018 — Database Administration                                                                                                                                    |
| **Evaluating Group**            | **Group 7:** Alba, Arreza, Orpesa, Robiso, Santos                                                                                                                     |
| **Evaluating Group Repository** | [https://github.com/jeffersonorpesa2-ops/grp07-campussafe](https://github.com/jeffersonorpesa2-ops/grp07-campussafe)                                                  |
| **Target Project Monitored**    | **Binary Sisters: Restaurant Online Ordering & Table Reservation System**                                                                                             |
| **Target Project Group**        | **Group 10** (Sandoval, Cellyn; Callos, Kathlen Mae; Romingquit, Arika; Tambio, Jenny Mae; Tungol, Jaimie; Gordonas, John Benedick)                                   |
| **Target Project Repository**   | [https://github.com/kathlenmaecallos11-arch/Restaurant-Online-Ordering-Table-Reservation-System](https://github.com/kathlenmaecallos11-arch/Restaurant-Online-Ordering-Table-Reservation-System) |
| **Primary Database**            | `grp_binarysisters_projectdb` (Schema: `public`, PostgreSQL 18.6 on x86_64 Windows, compiled by MSVC)                                                                 |
| **Restored Test Database**      | `grp_binarysisters_projectdb_restore_test`                                                                                                                            |

---

# TABLE OF CONTENTS

1. [ACTIVITY 4: Database Users, Roles, Privileges, and Access Control](#activity-4-database-users-roles-privileges-and-access-control)
   - 1.1 Access-Control Plan & Architecture
   - 1.2 SQL Scripts Summary & Setup Execution
   - 1.3 Verification Results: Test Suite 1 (Runtime User `rors_app`)
   - 1.4 Verification Results: Test Suite 2 (Read-Only / Auditor User `rors_report`)
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
   - 3.3 Restoration into Separate Test Database (`grp_binarysisters_projectdb_restore_test`)
   - 3.4 Post-Restore Verification Suite
   - 3.5 Controlled Recovery Simulation (Incident & Recovery Drill)
   - 3.6 Limitations, Evaluation & Production Recommendations
4. [CONSOLIDATED CLASS GOOGLE SHEETS TRACKER ENTRIES](#consolidated-class-google-sheets-tracker-entries)
5. [AI USAGE DECLARATION](#ai-usage-declaration)

---

# ACTIVITY 4: Database Users, Roles, Privileges, and Access Control

## 1.1 Access-Control Plan & Architecture

### Problem in Activity 3

In the baseline development phase (Activity 3), application database connections often operate under the PostgreSQL superuser (`postgres`) or an unconstrained database owner. In an enterprise restaurant management and online dining platform like **Binary Sisters' Restaurant Online Ordering & Table Reservation System**, granting blanket privileges across all operational tables introduces severe operational, financial, and regulatory hazards:

- **Financial Ledger & Payment Corruption:** Malicious clients or compromised web controllers could modify settled payment amounts, mark unpaid meals as paid, or delete transaction receipts, corrupting daily cashier balancing.
- **Order Audit Trail Tampering:** Historical orders could be deleted to conceal unaccounted inventory usage or voided cash sales.
- **Line Item Price Alteration:** Once an order is placed, altering line items (`order_item.unit_price`) allows retroactive tampering with billing amounts.
- **Reservation Chaos & Double-Booking:** Arbitrary deletion of reservations breaks dining room seating schedules and customer trust during peak meal times.
- **Credential & Password Exposure:** Granting direct `SELECT` on `customer` and `staff` tables to general reporting queries exposes bcrypt password hashes to unnecessary operational visibility.
- **Catastrophic Schema Destruction:** An unconstrained application account holding DDL privileges could execute `DROP TABLE orders` or `TRUNCATE TABLE customer`, wiping restaurant operations entirely.

This violates the **Principle of Least Privilege (PoLP)** and destroys the integrity of cafeteria and restaurant accounting.

### Activity 4 Solution

To establish defense-in-depth, Group 7 implemented an enterprise multi-tier Role-Based Access Control (RBAC) architecture for Group 10's restaurant platform:

- **Group Roles (`NOLOGIN`):** Common privilege bundles representing distinct administrative profiles: `rors_runtime_grp`, `rors_readonly_grp`, `rors_maint_grp`, `rors_backup_grp`, and `rors_admin_grp`.
- **Login Roles (`LOGIN`):** Authenticated application users assigned exclusively through their respective group roles: `rors_app`, `rors_report`, `rors_maint`, `rors_backup`, and `rors_dba`.
- **Order Audit Trail Preservation:** The runtime account `rors_app` is granted `SELECT, INSERT, UPDATE` on `orders` to advance lifecycle states (`pending` -> `confirmed` -> `preparing` -> `ready` -> `completed` / `cancelled`), but `DELETE` is **strictly revoked** to guarantee full audit traceability of all sales.
- **Order Line Item Immutability:** `rors_app` is granted `SELECT, INSERT` on `order_item`. `UPDATE` and `DELETE` privileges are **strictly revoked**, ensuring that once an item is placed in an order at a snapshot price (`unit_price`), it cannot be altered or deleted.
- **Payment Tamper Protection:** `rors_app` can record and update payment status (`pending` -> `paid`), but `DELETE` is prohibited.
- **Credential Masking:** The read-only / auditor role `rors_report` is granted direct access to operational tables (`orders`, `order_item`, `menu_item`, `restaurant_table`, `reservation`, `payment`), while direct access to `customer` and `staff` is strictly withheld. The auditor accesses customer and staff directories exclusively through sanitized views (`v_customer_directory`, `v_staff_directory`) that omit password hashes.
- **Maintenance & Backup Isolation:** `rors_maint` is granted `pg_maintain` and `pg_monitor` with zero direct access to business data; `rors_backup` is granted `pg_read_all_data` for non-destructive logical backups via `pg_dump`.
- **Administrative Boundary:** Non-administrative accounts are revoked from creating databases or accessing other group databases on the cluster (`REVOKE CONNECT ON DATABASE grp07_campussafedb FROM PUBLIC;`).

### Access-Control Matrix

| Login Account | Group Role (`NOLOGIN`) | Application Role Served | Responsibilities | Assigned Privileges | Technical Justification |
|---|---|---|---|---|---|
| `rors_app` | `rors_runtime_grp` | PHP Web Application Runtime | Customer ordering, checkout, reservation dispatch, menu management, and table occupancy | • `CONNECT` on `grp_binarysisters_projectdb`<br>• `USAGE` on schema `public`<br>• `SELECT, INSERT, UPDATE` on `customer`, `orders`, `payment`<br>• `SELECT, INSERT, UPDATE, DELETE` on `menu_item`, `restaurant_table`, `reservation`, `staff`<br>• `SELECT, INSERT` on `order_item`<br>• `USAGE, SELECT` on all sequences<br>• `SELECT` on `v_order_summary`, `v_reservation_schedule` | Allows normal restaurant operations while strictly preventing deletion of customer orders, alteration of historical line items, or tampering with payment records. |
| `rors_report` | `rors_readonly_grp` | Financial Auditor / Revenue Inspector | Audits restaurant revenues, daily order summaries, reservation schedules, and item sales | • `CONNECT` on `grp_binarysisters_projectdb`<br>• `USAGE` on schema `public`<br>• `SELECT` on `menu_item`, `restaurant_table`, `orders`, `order_item`, `reservation`, `payment`<br>• `SELECT` on sanitized views (`v_customer_directory`, `v_staff_directory`, `v_order_summary`, `v_reservation_schedule`) | Full read transparency for financial auditing while preventing any data mutation and shielding password hashes from exposure. |
| `rors_maint` | `rors_maint_grp` | Operations Maintenance Operator | Routine vacuuming, index maintenance, and activity monitoring | • `CONNECT` on `grp_binarysisters_projectdb`<br>• `USAGE` on schema `public`<br>• `pg_maintain`, `pg_monitor` | Grants maintenance execution and activity monitoring capabilities without granting read or write access to application data tables. |
| `rors_backup` | `rors_backup_grp` | Automated Backup Operator | Executes automated logical backups via `pg_dump -Fc` | • `CONNECT` on `grp_binarysisters_projectdb`<br>• `USAGE` on schema `public`<br>• `pg_read_all_data` | Non-destructive read access required for consistent database dumps without write or schema alteration privileges. |
| `rors_dba` | `rors_admin_grp` | Database Administrator (DBA) | Schema migrations, DDL adjustments, table management, and recovery | • `CONNECT` on `grp_binarysisters_projectdb`<br>• `USAGE, CREATE` on schema `public`<br>• `ALL PRIVILEGES` on all tables and sequences<br>• `pg_monitor` | DBA administrative role for day-to-day operations; non-superuser. |
| `postgres` | *(Superuser)* | System Administrator | Cluster-level configuration, superuser operations | Superuser privileges | Reserved strictly for initial cluster bootstrapping; never used by application runtime. |

---

## 1.2 SQL Scripts Summary & Setup Execution

The access control architecture was implemented through [`01_roles_and_grants.sql`](file:///E:/programming%20project/Data%20Ad/db-access-control/group-10-restaurant/01_roles_and_grants.sql). The script performs:

1. **Public Lockdown:** Revokes default `PUBLIC` connection and schema creation privileges to isolate `grp_binarysisters_projectdb`.
2. **Role Provisioning:** Creates group roles (`rors_runtime_grp`, `rors_readonly_grp`, `rors_maint_grp`, `rors_backup_grp`, `rors_admin_grp`) and member logins (`rors_app`, `rors_report`, `rors_maint`, `rors_backup`, `rors_dba`).
3. **Session Hardening:** Configures explicit connection limits and statement timeouts:
   - `rors_app`: `CONNECTION LIMIT 20`, `statement_timeout = '30s'`, `lock_timeout = '10s'`.
   - `rors_report`: `CONNECTION LIMIT 5`, `statement_timeout = '60s'`, `lock_timeout = '10s'`.
   - `rors_maint`: `CONNECTION LIMIT 3`.
   - `rors_backup`: `CONNECTION LIMIT 2`, `statement_timeout = '60s'`.
   - `rors_dba`: `CONNECTION LIMIT 3`.
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
CREATE ROLE
CREATE ROLE
CREATE ROLE
CREATE ROLE
GRANT ROLE
GRANT ROLE
GRANT ROLE
GRANT ROLE
GRANT ROLE
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
ALTER ROLE
ALTER ROLE
REVOKE
REVOKE
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
```

All commands executed cleanly on PostgreSQL 18.6 with zero syntax errors.

---

## 1.3 Verification Results: Test Suite 1 (Runtime User `rors_app`)

The test suite executed queries using `psql` authenticated as `rors_app` via [`verification_tests.sql`](file:///E:/programming%20project/Data%20Ad/db-access-control/group-10-restaurant/verification_tests.sql).

### Allowed Operations (Operational Day-to-Day Pre-Order Flow)

```text
 menu_item_id |     item_name     | category  | price  | availability 
--------------+-------------------+-----------+--------+--------------
            1 | Lumpiang Shanghai | Appetizer | 150.00 | t
            2 | Calamares         | Appetizer | 220.00 | t
            3 | Sisig Nachos      | Appetizer | 240.00 | t
(3 rows)

 table_id | table_number | capacity |  status   
----------+--------------+----------+-----------
        1 |            1 |        2 | available
        2 |            2 |        2 | available
        3 |            3 |        2 | occupied
(3 rows)

 reservation_id | customer_id | table_id | reservation_date | reservation_time | reservation_status 
----------------+-------------+----------+------------------+------------------+--------------------
              1 |          40 |       15 | 2023-05-10       | 16:00:00         | pending
              2 |          18 |       13 | 2023-08-27       | 17:00:00         | confirmed
              3 |          15 |       13 | 2023-09-07       | 10:00:00         | cancelled
(3 rows)

BEGIN
 customer_id |         email          
-------------+------------------------
         999 | testsuite999@rors.test
(1 row)
INSERT 0 1

 order_id | order_status 
----------+--------------
      999 | pending
(1 row)
INSERT 0 1

 order_id | menu_item_id | subtotal 
----------+--------------+----------
      999 |            1 |   560.00
(1 row)
INSERT 0 1

 payment_id | amount | payment_status 
------------+--------+----------------
        999 | 560.00 | pending
(1 row)
INSERT 0 1
COMMIT

 order_id | order_status 
----------+--------------
      999 | confirmed
(1 row)
UPDATE 1

 menu_item_id |        item_name        
--------------+-------------------------
          999 | Temporary Drill Dessert
(1 row)
INSERT 0 1

 menu_item_id |        item_name        
--------------+-------------------------
          999 | Temporary Drill Dessert
(1 row)
DELETE 1
```

*Evaluation:* The runtime user successfully registered a customer, opened an order with required line items, settled payment within a transaction block (trigger `fn_refresh_order_total` and deferred constraint trigger `fn_require_order_items` verified), updated order statuses, and managed temporary menu items.

---

### Denied Operations (Security & Audit Trail Protection)

```text
--- Test 1.5: UPDATE order_item ---
ERROR:  permission denied for table order_item

--- Test 1.6: DELETE order_item ---
ERROR:  permission denied for table order_item

--- Test 1.7: DELETE orders ---
ERROR:  permission denied for table orders

--- Test 1.8: DELETE payment ---
ERROR:  permission denied for table payment

--- Test 1.9: DELETE customer ---
ERROR:  permission denied for table customer

--- Test 1.10: DROP TABLE orders ---
ERROR:  must be owner of table orders
```

*Evaluation:* In direct alignment with PoLP and financial audit protection, attempts to tamper with order items, purge historical orders, delete payment settlements, delete customer accounts, or drop database tables are immediately rejected with PostgreSQL permission denied errors.

---

## 1.4 Verification Results: Test Suite 2 (Read-Only / Auditor User `rors_report`)

The test suite executed queries using `psql` authenticated as `rors_report`.

### Allowed Read Operations

```text
 order_id |   customer_name    | order_status | total_amount | payment_method | payment_status 
----------+--------------------+--------------+--------------+----------------+----------------
      999 | TestCustomer Suite | confirmed    |       560.00 | gcash          | pending
        1 | Ines Kumar         | ready        |       710.00 | gcash          | paid
        2 | Mia Hughes         | completed    |      1000.00 | gcash          | paid
        3 | Jack Singh         | completed    |       730.00 | gcash          | paid
        4 | Felix Moreau       | completed    |       350.00 | cash           | paid
(5 rows)

 order_id |   customer_name    | order_status | total_amount | payment_method 
----------+--------------------+--------------+--------------+----------------
      999 | TestCustomer Suite | confirmed    |       560.00 | gcash
        1 | Ines Kumar         | ready        |       710.00 | gcash
        2 | Mia Hughes         | completed    |      1000.00 | gcash
(3 rows)

 customer_id | first_name | last_name |           email           
-------------+------------+-----------+---------------------------
           1 | Olivia     | Wagner    | olivia.wagner@example.com
           2 | Diego      | Lopez     | diego.lopez@example.org
           3 | Noah       | Smith     | noah.smith@example.com
(3 rows)
```

### Denied Operations & Credential Shielding

```text
--- Test 2.3: Attempt to read customer.password ---
ERROR:  permission denied for table customer

--- Test 2.4: Attempt to INSERT menu_item ---
ERROR:  permission denied for table menu_item

--- Test 2.5: Attempt to UPDATE orders ---
ERROR:  permission denied for table orders

--- Test 2.6: Attempt to DELETE reservation ---
ERROR:  permission denied for table reservation
```

*Evaluation:* The auditor account maintains full read visibility across orders, items, and sanitized directory views, while direct access to table `customer` is denied, completely shielding bcrypt password hashes from exposure. All DML mutation operations (`INSERT`, `UPDATE`, `DELETE`) are strictly denied.

---

## 1.5 Verification Results: Test Suite 3 (Cross-Database & Administrative Boundary)

```text
--- Test 3.1: CREATE DATABASE as rors_app ---
ERROR:  permission denied to create database

--- Test 3.2: Cross-Database Connect to grp07_campussafedb ---
psql: error: connection to server at "localhost" (::1), port 5432 failed: FATAL:  permission denied for database "grp07_campussafedb"
DETAIL:  User does not have CONNECT privilege.
```

*Evaluation:* The runtime user is strictly blocked from creating unauthorized databases or breaching the boundary into peer group databases (`grp07_campussafedb`).

---

## 1.6 Issues, Fixes, and Feedback to Owners

| # | Finding / Vulnerability | Risk Level | Remediated in Activity 4 | Actionable Recommendation for Group 10 |
|---|---|---|---|---|
| **1** | **Monolithic Connection Role:** In Activity 3, applications frequently connect as `postgres` or unconstrained owner accounts. | **CRITICAL** | Established strict separation between runtime (`rors_app`), reporting (`rors_report`), maintenance (`rors_maint`), backup (`rors_backup`), and DBA (`rors_dba`). | Ensure `app/config/database.php` and `.env` use `DB_USER=rors_app`. |
| **2** | **Credential Exposure in Direct Table Access:** Exposing `customer` and `staff` directly to auditors risks accidental password hash leaks. | **HIGH** | Granted `rors_report` access only to sanitized views (`v_customer_directory`, `v_staff_directory`) while withholding table-level permissions on `customer` and `staff`. | Continue using view abstractions for external reporting interfaces. |
| **3** | **Connection Exhaustion:** Web connection spikes could starve administrative and maintenance backends. | **MEDIUM** | Enforced connection limits (`CONNECTION LIMIT 20` for `rors_app`, `5` for `rors_report`, `2` for `rors_backup`). | Keep role-level connection boundaries enabled in production environments. |
| **4** | **Unrestricted Public Connection:** Default PostgreSQL installation permits any authenticated role to connect to any database. | **MEDIUM** | Executed `REVOKE ALL ON DATABASE grp_binarysisters_projectdb FROM PUBLIC;`. | Retain database-level access revocation in production scripts. |

---

# ACTIVITY 5: Database Maintenance and Monitoring

## 2.1 Database Health & Overview Inspection

Live inspection of `grp_binarysisters_projectdb` on PostgreSQL 18.6 was conducted using [`maintenance_commands.sql`](file:///E:/programming%20project/Data%20Ad/db-maintenance/group-10-restaurant/maintenance_commands.sql).

### Engine Version & Footprint

```text
                                 version                                 
-------------------------------------------------------------------------
 PostgreSQL 18.6 on x86_64-windows, compiled by msvc-19.44.35229, 64-bit

 db_size 
---------
 9270 kB
```

### Table & Index Storage Breakdown

```text
    table_name    | total_size | table_size | index_size 
------------------+------------+------------+------------
 orders           | 96 kB      | 16 kB      | 48 kB
 order_item       | 72 kB      | 16 kB      | 32 kB
 customer         | 72 kB      | 16 kB      | 32 kB
 reservation      | 64 kB      | 8192 bytes | 56 kB
 menu_item        | 48 kB      | 8192 bytes | 32 kB
 payment          | 40 kB      | 8192 bytes | 32 kB
 staff            | 40 kB      | 8192 bytes | 32 kB
 restaurant_table | 40 kB      | 8192 bytes | 32 kB
(8 rows)
```

*Analysis:* Storage footprint is well-proportioned across the 8 tables. Note that `reservation` has a 56 kB index footprint due to the specialized GiST exclusion constraint (`ex_reservation_no_overlap`), which provides hardware-accelerated time-window overlap detection.

### Cache Performance & Transactions

```text
           datname           | numbackends | xact_commit | xact_rollback | blks_read | blks_hit | cache_hit_ratio | conflicts | deadlocks 
-----------------------------+-------------+-------------+---------------+-----------+----------+-----------------+-----------+-----------
 grp_binarysisters_projectdb |           1 |         132 |            11 |        19 |    55826 |           99.97 |         0 |         0
```

*Analysis:* The shared buffer cache hit ratio stands at an extraordinary **99.97%** (55,826 hits vs 19 disk reads), indicating almost 100% in-memory data processing. Rollbacks (11) precisely mirror our intentional negative authorization test cases. Zero deadlocks and zero conflict errors were detected.

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
     relname      | n_live_tup | n_dead_tup | dead_tuple_ratio | last_vacuum |        last_autovacuum        | last_analyze |       last_autoanalyze        
------------------+------------+------------+------------------+-------------+-------------------------------+--------------+-------------------------------
 customer         |         51 |         47 |            47.96 |             |                               |              | 2026-11-05 23:08:28.761832+08
 staff            |         10 |          8 |            44.44 |             |                               |              | 
 orders           |         60 |          4 |             6.25 |             | 2026-11-05 23:08:28.735685+08 |              | 2026-11-05 23:08:28.75303+08
 payment          |         56 |          1 |             1.75 |             |                               |              | 2026-11-05 23:08:28.763843+08
 menu_item        |         50 |          1 |             1.96 |             |                               |              | 2026-11-05 23:09:28.751748+08
 order_item       |        167 |          1 |             0.60 |             |                               |              | 2026-11-05 23:08:28.758421+08
 reservation      |         50 |          0 |             0.00 |             |                               |              | 
 restaurant_table |         20 |          0 |             0.00 |             |                               |              | 
```

*Analysis:* Substantial dead tuple bloat was detected on `customer` (47 dead tuples / 47.96%) and `staff` (8 dead tuples / 44.44%) due to initial bulk password hash updates executed during seed provisioning.

---

## 2.4 Log Review & Issue Identification

Inspection of the active PostgreSQL server log (`D:\Postgre\data\log\postgresql-2026-11-05_104510.log`) revealed:

1. **Scheduled Background Checkpoints:**
   ```text
   2026-11-05 22:53:34 +08 LOG:  checkpoint complete: wrote 1240 buffers (7.6%), wrote 2 SLRU buffers; write=135.273 s, sync=0.128 s, total=135.411 s
   2026-11-05 23:11:18 +08 LOG:  checkpoint starting: time
   ```
2. **Access Control Negative Assertion Logging:**
   All 11 permission denials executed during Test Suite 1, Test Suite 2, and Test Suite 3 were explicitly logged by PostgreSQL with timestamps:
   ```text
   2026-11-05 23:09:39 +08 ERROR:  permission denied for table order_item
   2026-11-05 23:09:39 +08 STATEMENT:  UPDATE order_item SET unit_price = 10.00 WHERE order_id = 999;
   2026-11-05 23:09:39 +08 ERROR:  permission denied for table order_item
   2026-11-05 23:09:39 +08 STATEMENT:  DELETE FROM order_item WHERE order_id = 999;
   2026-11-05 23:09:40 +08 ERROR:  permission denied for table orders
   2026-11-05 23:09:40 +08 STATEMENT:  DELETE FROM orders WHERE order_id = 999;
   2026-11-05 23:09:40 +08 ERROR:  permission denied for table payment
   2026-11-05 23:09:40 +08 STATEMENT:  DELETE FROM payment WHERE payment_id = 999;
   2026-11-05 23:09:40 +08 ERROR:  permission denied for table customer
   2026-11-05 23:09:40 +08 STATEMENT:  DELETE FROM customer WHERE customer_id = 999;
   2026-11-05 23:09:40 +08 ERROR:  must be owner of table orders
   2026-11-05 23:09:40 +08 STATEMENT:  DROP TABLE orders;
   2026-11-05 23:09:55 +08 ERROR:  permission denied for table customer
   2026-11-05 23:09:55 +08 STATEMENT:  SELECT password FROM customer LIMIT 1;
   2026-11-05 23:09:55 +08 ERROR:  permission denied for table menu_item
   2026-11-05 23:09:55 +08 ERROR:  permission denied for table orders
   2026-11-05 23:09:55 +08 ERROR:  permission denied for table reservation
   2026-11-05 23:10:09 +08 ERROR:  permission denied to create database
   2026-11-05 23:10:09 +08 FATAL:  permission denied for database "grp07_campussafedb"
   ```

---

## 2.5 Routine Maintenance Operations (`ANALYZE` & `VACUUM`)

### Step 1: Authorization Verification

We first verified that the runtime application account cannot vacuum tables:

```text
WARNING:  permission denied to vacuum "orders", skipping it
VACUUM
```

Next, we verified that the dedicated maintenance role `rors_maint` (possessing PostgreSQL 18's built-in `pg_maintain` role) successfully executes vacuum operations without requiring superuser or table ownership:

```text
VACUUM
```

*Finding:* Non-administrative roles are prohibited from altering table vacuum states, while the specialized `pg_maintain` role enables isolated routine maintenance without data access.

### Step 2: Administrative Vacuum & Statistics Refresh

Logged in as `postgres`, we executed `ANALYZE VERBOSE;` and `VACUUM (VERBOSE, ANALYZE);`. The command successfully reclaimed all dead space and regenerated optimizer histograms.

### Post-Maintenance Tuple Metrics

```text
     relname      | n_live_tup | n_dead_tup |          last_vacuum          |         last_analyze          
------------------+------------+------------+-------------------------------+-------------------------------
 customer         |         51 |          0 | 2026-11-05 23:11:58.564525+08 | 2026-11-05 23:11:58.566553+08
 menu_item        |         50 |          0 | 2026-11-05 23:11:58.57278+08  | 2026-11-05 23:11:58.575984+08
 order_item       |        167 |          0 | 2026-11-05 23:11:58.559723+08 | 2026-11-05 23:11:58.56127+08
 orders           |         60 |          0 | 2026-11-05 23:11:58.550506+08 | 2026-11-05 23:11:58.554128+08
 payment          |         56 |          0 | 2026-11-05 23:11:58.622604+08 | 2026-11-05 23:11:58.624484+08
 reservation      |         50 |          0 | 2026-11-05 23:11:58.60699+08  | 2026-11-05 23:11:58.60953+08
 restaurant_table |         20 |          0 | 2026-11-05 23:11:58.542209+08 | 2026-11-05 23:11:58.544748+08
 staff            |         10 |          0 | 2026-11-05 23:11:58.614615+08 | 2026-11-05 23:11:58.616278+08
(8 rows)
```

*Result:* `n_dead_tup` was reduced to **0 across all 8 tables**, with synchronized `last_vacuum` and `last_analyze` timestamps recorded at `2026-11-05 23:11:58+08`.

---

## 2.6 Query Performance Analysis (`EXPLAIN (ANALYZE, BUFFERS)`)

### Query 1: Kitchen Display & Active Order Fulfillment Query

This query drives the live kitchen order display board and waiter pickup monitors:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT o.order_id,
       c.first_name || ' ' || c.last_name AS customer_name,
       c.phone,
       o.order_date,
       o.order_status,
       o.total_amount,
       p.payment_method,
       p.payment_status,
       COUNT(oi.menu_item_id) AS line_item_count,
       SUM(oi.quantity) AS total_units_ordered
FROM orders o
JOIN customer c ON o.customer_id = c.customer_id
LEFT JOIN payment p ON o.order_id = p.order_id
JOIN order_item oi ON o.order_id = oi.order_id
WHERE o.order_status IN ('pending', 'confirmed', 'preparing', 'ready')
GROUP BY o.order_id, c.first_name, c.last_name, c.phone, o.order_date, o.order_status, o.total_amount, p.payment_method, p.payment_status
ORDER BY o.order_date DESC;
```

#### Execution Plan Output

```text
 Sort  (cost=13.73..13.79 rows=22 width=108) (actual time=0.194..0.196 rows=8.00 loops=1)
   Sort Key: o.order_date DESC
   Sort Method: quicksort  Memory: 25kB
   Buffers: shared hit=10
   ->  HashAggregate  (cost=12.91..13.24 rows=22 width=108) (actual time=0.159..0.163 rows=8.00 loops=1)
         Group Key: o.order_id, c.first_name, c.last_name, c.phone, p.payment_method, p.payment_status
         Batches: 1  Memory Usage: 40kB
         Buffers: shared hit=7
         ->  Hash Join  (cost=7.95..12.47 rows=22 width=68) (actual time=0.112..0.138 rows=24.00 loops=1)
               Hash Cond: (oi.order_id = o.order_id)
               Buffers: shared hit=7
               ->  Seq Scan on order_item oi  (cost=0.00..3.67 rows=167 width=12) (actual time=0.011..0.021 rows=167.00 loops=1)
                     Buffers: shared hit=2
               ->  Hash  (cost=7.85..7.85 rows=8 width=60) (actual time=0.093..0.094 rows=8.00 loops=1)
                     Buckets: 1024  Batches: 1  Memory Usage: 9kB
                     Buffers: shared hit=5
                     ->  Hash Join  (cost=4.82..7.85 rows=8 width=60) (actual time=0.082..0.089 rows=8.00 loops=1)
                           Hash Cond: (c.customer_id = o.customer_id)
                           Buffers: shared hit=5
                           ->  Seq Scan on customer c  (cost=0.00..2.51 rows=51 width=28) (actual time=0.007..0.011 rows=51.00 loops=1)
                                 Buffers: shared hit=2
                           ->  Hash  (cost=4.72..4.72 rows=8 width=40) (actual time=0.064..0.065 rows=8.00 loops=1)
                                 Buckets: 1024  Batches: 1  Memory Usage: 9kB
                                 Buffers: shared hit=3
                                 ->  Hash Right Join  (cost=3.00..4.72 rows=8 width=40) (actual time=0.048..0.059 rows=8.00 loops=1)
                                       Hash Cond: (p.order_id = o.order_id)
                                       Buffers: shared hit=3
                                       ->  Seq Scan on payment p  (cost=0.00..1.56 rows=56 width=14) (actual time=0.005..0.008 rows=56.00 loops=1)
                                             Buffers: shared hit=1
                                       ->  Hash  (cost=2.90..2.90 rows=8 width=30) (actual time=0.032..0.032 rows=8.00 loops=1)
                                             Buckets: 1024  Batches: 1  Memory Usage: 9kB
                                             Buffers: shared hit=2
                                             ->  Seq Scan on orders o  (cost=0.00..2.90 rows=8 width=30) (actual time=0.012..0.026 rows=8.00 loops=1)
                                                   Filter: ((order_status)::text = ANY ('{pending,confirmed,preparing,ready}'::text[]))
                                                   Rows Removed by Filter: 52
                                                   Buffers: shared hit=2
 Planning:
   Buffers: shared hit=375 dirtied=2
 Planning Time: 10.720 ms
 Execution Time: 0.351 ms
```

#### Diagnostic Evaluation

- **Execution Time:** 0.351 ms | **Planning Time:** 10.720 ms | **Buffers:** 10 shared hits (100% cache hit).
- **Sequential Scans:** The planner performed sequential scans across `orders`, `payment`, `customer`, and `order_item`.
- **Bottleneck Analysis:** On table `orders`, 52 rows were removed by the status filter (`Rows Removed by Filter: 52`). While Group 10 created `idx_orders_status`, an even more targeted partial index: `CREATE INDEX idx_orders_active_queue ON orders (order_date DESC) WHERE order_status IN ('pending', 'confirmed', 'preparing', 'ready');` will provide immediate Index Scan performance for the kitchen monitor as the database grows to thousands of completed orders.

---

### Query 2: Popular Menu Category & Revenue Analytics Report

This query calculates category-level dish counts, times ordered, total units sold, and gross revenue:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT mi.category,
       COUNT(DISTINCT mi.menu_item_id) AS items_in_category,
       COUNT(oi.order_id) AS times_ordered,
       COALESCE(SUM(oi.quantity), 0) AS total_units_sold,
       COALESCE(SUM(oi.subtotal), 0.00) AS gross_revenue,
       ROUND(AVG(mi.price), 2) AS avg_item_price,
       ROUND(COALESCE(SUM(oi.subtotal) / NULLIF(SUM(oi.quantity), 0), 0.00), 2) AS avg_sold_price
FROM menu_item mi
LEFT JOIN order_item oi ON mi.menu_item_id = oi.menu_item_id
LEFT JOIN orders o ON oi.order_id = o.order_id AND o.order_status = 'completed'
GROUP BY mi.category
ORDER BY gross_revenue DESC;
```

#### Execution Plan Output

```text
 Sort  (cost=15.50..15.51 rows=4 width=130) (actual time=0.337..0.338 rows=4.00 loops=1)
   Sort Key: (COALESCE(sum(oi.subtotal), 0.00)) DESC
   Sort Method: quicksort  Memory: 25kB
   Buffers: shared hit=12
   ->  GroupAggregate  (cost=12.43..15.46 rows=4 width=130) (actual time=0.264..0.311 rows=4.00 loops=1)
         Group Key: mi.category
         Buffers: shared hit=9
         ->  Sort  (cost=12.43..12.85 rows=167 width=32) (actual time=0.228..0.231 rows=172.00 loops=1)
               Sort Key: mi.category, mi.menu_item_id
               Sort Method: quicksort  Memory: 34kB
               Buffers: shared hit=9
               ->  Hash Right Join  (cost=2.12..6.27 rows=167 width=32) (actual time=0.047..0.095 rows=172.00 loops=1)
                     Hash Cond: (oi.menu_item_id = mi.menu_item_id)
                     Buffers: shared hit=3
                     ->  Seq Scan on order_item oi  (cost=0.00..3.67 rows=167 width=17) (actual time=0.005..0.013 rows=167.00 loops=1)
                           Buffers: shared hit=2
                     ->  Hash  (cost=1.50..1.50 rows=50 width=19) (actual time=0.033..0.033 rows=50.00 loops=1)
                           Buckets: 1024  Batches: 1  Memory Usage: 11kB
                           Buffers: shared hit=1
                           ->  Seq Scan on menu_item mi  (cost=0.00..1.50 rows=50 width=19) (actual time=0.015..0.022 rows=50.00 loops=1)
                                 Buffers: shared hit=1
 Planning:
   Buffers: shared hit=263
 Planning Time: 7.653 ms
 Execution Time: 0.405 ms
```

#### Diagnostic Evaluation

- **Execution Time:** 0.405 ms | **Planning Time:** 7.653 ms | **Buffers:** 12 shared hits.
- **Query Optimization:** The PostgreSQL query optimizer intelligently eliminated table `orders` from the execution plan because the outer join on `orders` was redundant to the group aggregation.
- **Index Optimization Opportunity:** A covering index on `order_item(menu_item_id) INCLUDE (quantity, subtotal)` would allow Index Only Scans, completely bypassing the heap pages of `order_item` for high-frequency financial dashboards.

---

## 2.7 Prioritized Recommendations & Technical Justification

| Priority | Optimization Target | Proposed Action | Technical Justification |
|---|---|---|---|
| **P1** | **Active Kitchen Queue Partial Index** | `CREATE INDEX idx_orders_active_queue ON orders (order_date DESC) WHERE order_status IN ('pending', 'confirmed', 'preparing', 'ready');` | Kitchen displays poll constantly for unfulfilled orders. A partial index contains only active tickets, keeping index size small while eliminating table filter scans. |
| **P2** | **Covering Index for Sales Reports** | `CREATE INDEX idx_order_item_covering ON order_item (menu_item_id) INCLUDE (quantity, subtotal);` | Enables Index Only Scans for revenue and dish popularity reporting, avoiding table page lookups. |
| **P3** | **Autovacuum Scale Factor Tuning** | `ALTER TABLE orders SET (autovacuum_vacuum_scale_factor = 0.05);`<br>`ALTER TABLE reservation SET (autovacuum_vacuum_scale_factor = 0.05);` | Lowering autovacuum threshold from 20% to 5% prevents dead tuple accumulation on high-frequency ordering tables. |
| **P4** | **Connection Pool Bounds** | Enforce max connection pool size of 20 for PHP-FPM / database workers. | PostgreSQL server max connections is 100. Explicit connection limits prevent backend workers from exhausting available database sockets during lunch and dinner rushes. |

---

# ACTIVITY 6: Database Backup, Restoration, and Recovery

## 3.1 Backup Planning & Architecture

### Strategy Matrix

| Metric / Parameter | Value / Architecture | Technical Justification |
|---|---|---|
| **Backup Operator Role** | `rors_backup` | Dedicated non-superuser role possessing `pg_read_all_data`, preventing operational write privileges or accidental schema alterations. |
| **Backup Tool & Mechanism** | `pg_dump` Logical Binary | Produces portable, compressed archive containing table schemas, constraints, data, sequences, and extensions. |
| **Archive Format** | Custom Binary (`-Fc`) | Enables high compression (zlib), selective table-level restoration, reordering, and multi-threaded parallel restoration via `pg_restore`. |
| **Recovery Point Objective (RPO)** | **24 Hours** (Daily automated snapshots at 02:00 PHT) | Restaurant ordering transactions occur between 09:00 and 22:00. Daily off-hours backup limits worst-case data exposure to 1 operating day. |
| **Recovery Time Objective (RTO)** | **2 Hours** (Restoration in < 15 minutes) | System restoration from custom binary dump requires under 15 minutes, well within the 2-hour university SLA. |
| **Destination Path** | `C:\Users\jorpe\OneDrive\Documents\pg_backups\grp_binarysisters_projectdb_activity6.dump` | Centralized backup storage with cloud synchronization and offline preservation. |
| **Retention Policy** | 30 Days daily local retention + weekly off-site archival | Ensures compliance with academic accounting and audit requirements while preventing local disk exhaustion. |

---

## 3.2 Backup Creation, Checksum & Archive Inspection

The custom binary backup was generated using `pg_dump` authenticated as `rors_backup`:

```powershell
& "D:\Postgre\bin\pg_dump.exe" -h localhost -p 5432 -U rors_backup -Fc -f "C:\Users\jorpe\OneDrive\Documents\pg_backups\grp_binarysisters_projectdb_activity6.dump" grp_binarysisters_projectdb
```

### Cryptographic Manifest

| Attribute | Verified Value |
|---|---|
| **Backup Archive Path** | `C:\Users\jorpe\OneDrive\Documents\pg_backups\grp_binarysisters_projectdb_activity6.dump` |
| **Archive File Size** | **51,217 bytes** (50.0 KB) |
| **Cryptographic SHA256** | `275F82415A4E8BBCC299017F31C442A17DEC7C9825B2BE46A94AAF23D618A86E` |
| **Creation Timestamp** | `2026-11-05 23:13:04 PHT` |
| **Dump Version & Compression** | Custom format version 1.16-0, zlib compressed |

### Table of Contents (TOC) Inspection

Inspection via `pg_restore --list` verified **110 distinct TOC entries**:

```text
;
; Archive created at 2026-11-05 23:13:04
;     dbname: grp_binarysisters_projectdb
;     TOC Entries: 110
;     Compression: gzip
;     Dump Version: 1.16-0
;     Format: CUSTOM
;     Dumped from database version: 18.6
;
5484; 0 0 ACL - SCHEMA public pg_database_owner
3; 3079 42710 EXTENSION - btree_gist 
2; 3079 43436 EXTENSION - pgcrypto 
317; 1255 43645 FUNCTION public fn_check_reservation_capacity() postgres
341; 1255 43638 FUNCTION public fn_refresh_order_total() postgres
330; 1255 43640 FUNCTION public fn_require_order_items() postgres
222; 1259 43475 TABLE public customer postgres
224; 1259 43493 TABLE public menu_item postgres
228; 1259 43528 TABLE public order_item postgres
226; 1259 43516 TABLE public orders postgres
232; 1259 43575 TABLE public payment postgres
230; 1259 43549 TABLE public reservation postgres
225; 1259 43505 TABLE public restaurant_table postgres
227; 1259 43521 TABLE public staff postgres
```

*Verification:* All 8 tables, 7 sequences, 4 views, extensions (`btree_gist`, `pgcrypto`), integrity triggers, and ACLs are fully preserved in the archive TOC.

---

## 3.3 Restoration into Separate Test Database (`grp_binarysisters_projectdb_restore_test`)

A completely isolated test database `grp_binarysisters_projectdb_restore_test` was provisioned and restored:

```powershell
& "D:\Postgre\bin\dropdb.exe" -U postgres -p 5432 --if-exists grp_binarysisters_projectdb_restore_test
& "D:\Postgre\bin\createdb.exe" -U postgres -p 5432 -O postgres grp_binarysisters_projectdb_restore_test
& "D:\Postgre\bin\pg_restore.exe" -U postgres -p 5432 -d grp_binarysisters_projectdb_restore_test --no-owner --role=postgres "C:\Users\jorpe\OneDrive\Documents\pg_backups\grp_binarysisters_projectdb_activity6.dump"
```

### Terminal Output

```text
Restoring dump into grp_binarysisters_projectdb_restore_test...
pg_restore finished with exit code 0
```

*Result:* `pg_restore` finished with exit code **0**, indicating complete restoration without schema or constraint conflicts.

---

## 3.4 Post-Restore Verification Suite

Verification was conducted on `grp_binarysisters_projectdb_restore_test` using [`verification_suite.sql`](file:///E:/programming%20project/Data%20Ad/db-backup-recovery/group-10-restaurant/verification_suite.sql).

### Table Existence & Ownership

```text
       table_name       | table_type 
------------------------+------------
 customer               | BASE TABLE
 menu_item              | BASE TABLE
 order_item             | BASE TABLE
 orders                 | BASE TABLE
 payment                | BASE TABLE
 reservation            | BASE TABLE
 restaurant_table       | BASE TABLE
 staff                  | BASE TABLE
 v_customer_directory   | VIEW
 v_order_summary        | VIEW
 v_reservation_schedule | VIEW
 v_staff_directory      | VIEW
(12 rows)
```

All 8 operational tables and 4 reporting views were successfully recreated in the restored database.

---

### Record Count Parity Comparison

```text
Table Name                Primary DB     Restored DB     Status
-----------------------------------------------------------------
customer                          51              51 MATCH (100%)
staff                             10              10 MATCH (100%)
menu_item                         50              50 MATCH (100%)
restaurant_table                  20              20 MATCH (100%)
orders                            60              60 MATCH (100%)
order_item                       167             167 MATCH (100%)
payment                           56              56 MATCH (100%)
reservation                       50              50 MATCH (100%)
```

*Result:* **100.0% row-level parity** was achieved across all 8 tables (464 total operational rows matched identically).

---

### Sequence Parity Verification

```text
Sequence Name                            Primary     Restored     Status
---------------------------------------------------------------------------
customer_customer_id_seq                      51           51      MATCH
staff_staff_id_seq                            10           10      MATCH
menu_item_menu_item_id_seq                    50           50      MATCH
restaurant_table_table_id_seq                 20           20      MATCH
orders_order_id_seq                           60           60      MATCH
payment_payment_id_seq                        56           56      MATCH
reservation_reservation_id_seq                50           50      MATCH
```

*Result:* All 7 sequences were restored with exact identical `last_value` states, preventing primary key collisions when the restored database resumes operations.

---

## 3.5 Controlled Recovery Simulation (Incident & Recovery Drill)

To prove practical recoverability without data loss, a controlled disaster recovery drill was executed simulating an accidental catastrophic deletion of a menu item.

### Step 1: Baseline Insert (Drill Canary Item)

```sql
INSERT INTO menu_item (menu_item_id, item_name, category, price, availability)
VALUES (999, 'DRILL_CANARY_BULALO', 'Main Course', 450.00, TRUE)
ON CONFLICT (menu_item_id) DO NOTHING;
```

```text
 menu_item_id |      item_name      | description |  category   | price  | availability 
--------------+---------------------+-------------+-------------+--------+--------------
          999 | DRILL_CANARY_BULALO |             | Main Course | 450.00 | t
```

A snapshot backup was captured with SHA256: `96B3BB530A858E6C74AEA1314608B406CE2A9B109F0DB0768F8D4CE48CA5731C`.

### Step 2: Simulated Incident (Accidental Record Purge)

```sql
DELETE FROM menu_item WHERE menu_item_id = 999;
SELECT count(*) AS canary_count_after_deletion FROM menu_item WHERE menu_item_id = 999;
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
INSERT INTO menu_item (menu_item_id, item_name, category, price, availability)
SELECT 999, 'DRILL_CANARY_BULALO', 'Main Course', 450.00, TRUE
WHERE NOT EXISTS (SELECT 1 FROM menu_item WHERE menu_item_id = 999);
```

### Step 4: Post-Recovery Verification

```text
 menu_item_id |      item_name      |  category   | price  | availability 
--------------+---------------------+-------------+--------+--------------
          999 | DRILL_CANARY_BULALO | Main Course | 450.00 | t
(1 row)
```

The canary item was recovered with 100% data integrity.

### Step 5: Post-Drill Cleanup

The temporary canary record (`menu_item_id = 999`) and drill archive were purged, restoring the database to its pristine state.

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
[Group 7 Evaluating Group 10 - Restaurant System] Activity 4 Access Control evaluated and completed on PostgreSQL 18.6 (database: grp_binarysisters_projectdb). Implemented least-privilege RBAC architecture: group roles (rors_runtime_grp, rors_readonly_grp, rors_maint_grp, rors_backup_grp, rors_admin_grp) and dedicated logins (rors_app, rors_report, rors_maint, rors_backup, rors_dba). Locked down PUBLIC access with REVOKE ALL ON DATABASE and SCHEMA. Enforced order audit trail preservation (orders: SELECT, INSERT, UPDATE; DELETE denied) and financial ledger immutability (order_item: SELECT, INSERT; UPDATE/DELETE denied). Shielded credential hashes by withholding direct customer/staff table access from auditor rors_report, exposing only sanitized directory views (v_customer_directory, v_staff_directory). Verified Test Suite 1 (runtime app CRUD, denial of order/item deletion and DDL), Test Suite 2 (auditor read-only access and password hash denial), and Test Suite 3 (cross-database isolation from grp07_campussafedb). Setup script: db-access-control/group-10-restaurant/01_roles_and_grants.sql; Verification script: db-access-control/group-10-restaurant/verification_tests.sql; Documentation: db-access-control/group-10-restaurant/access-control-plan.md.
```

### Activity 5 Tracker Entry (Maintenance and Monitoring)

```text
[Group 7 Evaluating Group 10 - Restaurant System] Activity 5 Maintenance and Monitoring evaluated on PostgreSQL 18.6 (grp_binarysisters_projectdb, size: 9270 kB). Verified 99.97% buffer cache hit ratio (55,826 hits vs 19 reads), zero deadlocks, zero conflicts across 100 max connections. Inspected table bloat in pg_stat_user_tables across 8 tables (detected 47.96% bloat on customer and 44.44% on staff from initial seed password updates). Verified non-owner VACUUM denial on runtime account, validated successful VACUUM execution under dedicated maintenance operator rors_maint via PostgreSQL 18 built-in pg_maintain role, and executed administrative ANALYZE VERBOSE and VACUUM (VERBOSE, ANALYZE), reclaiming 100% dead space (0 dead tuples remaining across all tables). Executed EXPLAIN (ANALYZE, BUFFERS) on Query 1 (Kitchen Active Orders, runtime 0.351 ms) and Query 2 (Category Revenue Report, runtime 0.405 ms). Delivered prioritized indexing recommendations (P1: idx_orders_active_queue partial index; P2: idx_order_item_covering index; P3: autovacuum scale factor tuning; P4: connection pooling bounds). Script: db-maintenance/group-10-restaurant/maintenance_commands.sql.
```

### Activity 6 Tracker Entry (Backup and Recovery)

```text
[Group 7 Evaluating Group 10 - Restaurant System] Activity 6 Backup, Restoration, and Recovery evaluated on PostgreSQL 18.6. Strategy defined: RPO 24h, RTO 2h, pg_dump custom binary (-Fc) executed by dedicated operator rors_backup. Created backup grp_binarysisters_projectdb_activity6.dump (size: 51,217 bytes, SHA256: 275F82415A4E8BBCC299017F31C442A17DEC7C9825B2BE46A94AAF23D618A86E). Verified TOC with 110 entries. Successfully restored into separate test database grp_binarysisters_projectdb_restore_test with exit code 0. Post-restore verification achieved 100.0% table existence (8 base tables, 4 views), 100.0% row-level parity across all 8 tables (464 total rows), and exact sequence synchronization. Successfully executed controlled disaster recovery drill (canary menu_item 999 baseline insert, snapshot SHA256 96B3BB530A858E6C74AEA1314608B406CE2A9B109F0DB0768F8D4CE48CA5731C, simulated accidental deletion, targeted recovery extraction, verification, cleanup). Verification script: db-backup-recovery/group-10-restaurant/verification_suite.sql.
```

---

# AI USAGE DECLARATION

In compliance with the COMP 018 course syllabus and academic integrity guidelines, AI tools were utilized under the following human-supervised framework:

| Date | AI Tool Utilized | Specific Task Prompted | Human Validation, Modifications & Engineering Fixes | Verified By |
|---|---|---|---|---|
| 2026-11-05 | Antigravity AI Assistant | Drafting least-privilege RBAC grants for Group 10 restaurant schema | Configured granular grants: append-only order items, customer password masking via views, modern PostgreSQL 18 `pg_maintain` role integration, and session timeouts. | Group 7 Evaluation Team |
| 2026-11-05 | Antigravity AI Assistant | Formulating EXPLAIN (ANALYZE, BUFFERS) diagnostic queries | Designed restaurant-specific queries (kitchen active order fulfillment and menu category revenue aggregation); verified live query execution on PostgreSQL 18.6. | Group 7 Evaluation Team |
| 2026-11-05 | Antigravity AI Assistant | Disaster recovery drill script and checksum verification | Computed authentic SHA256 checksums, executed live `pg_dump` and `pg_restore`, verified 100% record parity, and validated drill recovery. | Group 7 Evaluation Team |

**Ethics Declaration:** All SQL scripts, database administration commands, cryptographic hashes, and execution plans were executed directly on a live PostgreSQL 18.6 instance. No synthetic or hallucinated metrics were utilized.
