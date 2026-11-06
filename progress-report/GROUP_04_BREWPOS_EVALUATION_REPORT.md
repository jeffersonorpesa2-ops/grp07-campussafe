# COMP 018: Database Administration — Comprehensive Project Report
## Activities 4, 5, and 6: Access Control, Maintenance & Monitoring, Backup & Recovery

---

### Project Identification & Metadata

| Field | Details |
|---|---|
| **Course** | COMP 018 — Database Administration |
| **Evaluating Group** | **Group 7:** Alba, Arreza, Orpesa, Robiso, Santos |
| **Evaluating Group Repository** | [https://github.com/jeffersonorpesa2-ops/grp07-campussafe](https://github.com/jeffersonorpesa2-ops/grp07-campussafe) |
| **Target Project Monitored** | **BrewPOS: Café Point-of-Sale System** |
| **Target Project Group** | **Group 4** (Olivarez, Charles Kean E., Infantado, Gerwin G., Pocsidio, Jhon Louie F., Abangan, SJ Kaizen M., Bartolata, Redge Raindel N.) |
| **Target Project Repository** | [https://github.com/Nycri/brewpos](https://github.com/Nycri/brewpos) |
| **Primary Database** | `grp_brewposdb` (PostgreSQL 18.6 on x86_64 Windows, compiled by MSVC) |
| **Restored Test Database** | `grp_brewposdb_restore_test` |

---

# TABLE OF CONTENTS
1. [ACTIVITY 4: Database Users, Roles, Privileges, and Access Control](#activity-4-database-users-roles-privileges-and-access-control)
   - 1.1 Access-Control Plan & Architecture
   - 1.2 SQL Scripts Summary & Setup Execution
   - 1.3 Verification Results: Test Suite 1 (Runtime User `brewpos_app`)
   - 1.4 Verification Results: Test Suite 2 (Read-Only / Auditor User `brewpos_auditor`)
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
   - 3.3 Restoration into Separate Test Database (`grp_brewposdb_restore_test`)
   - 3.4 Post-Restore Verification Suite
   - 3.5 Controlled Recovery Simulation (Incident & Recovery Drill)
   - 3.6 Limitations, Evaluation & Production Recommendations
4. [CONSOLIDATED CLASS GOOGLE SHEETS TRACKER ENTRIES](#consolidated-class-google-sheets-tracker-entries)
5. [AI USAGE DECLARATION](#ai-usage-declaration)

---

# ACTIVITY 4: Database Users, Roles, Privileges, and Access Control

## 1.1 Access-Control Plan & Architecture

### Problem in Activity 3
In default development setups, applications frequently connect using the PostgreSQL superuser (`postgres`) or an unrestricted database owner. If an operational application runtime account possesses blanket `ALL PRIVILEGES`, `UPDATE`, or `DELETE` capabilities across all tables, any application vulnerability (such as SQL injection, broken object-level authorization, or an unauthenticated administrative API endpoint) could allow attackers to alter completed order totals, delete sales receipts, manipulate historical unit prices, or drop entire business tables. This directly violates the **Principle of Least Privilege (PoLP)** and destroys financial auditing integrity.

### Activity 4 Solution
For Group 4's **BrewPOS** platform, we implemented a comprehensive role-based access control (RBAC) hierarchy decoupling administrative maintenance from runtime application operations:
- **Group Roles (`NOLOGIN`):** Common privilege bundles representing distinct responsibility profiles (`brewpos_runtime_grp`, `brewpos_readonly_grp`, and `brewpos_backup_grp`).
- **Login Roles (`LOGIN`):** Individual authenticated database accounts assigned to their corresponding group roles (`brewpos_app`, `brewpos_auditor`, and `brewpos_backup`).
- **Tamper-Proof Sales Immutability (Narrow DML Scoping):** The runtime account `brewpos_app` is granted `SELECT`, `INSERT`, `UPDATE`, and `DELETE` on operational catalog tables (`menu_category` and `menu_item`), and read-only `SELECT` on `staff`. Crucially, on transactional sales tables (`order_ticket` and `order_line_item`), `brewpos_app` is granted `SELECT` and `INSERT` **ONLY**. It is **strictly denied `UPDATE` and `DELETE`**. This guarantees that once a customer order is rung up at the register, its timestamp, payment tender method, itemized quantities, and historical unit sold prices cannot be manipulated or deleted at the database engine level.
- **Auditor & Compliance Isolation:** The read-only auditing account `brewpos_auditor` is granted `SELECT` across all tables (`staff`, `menu_category`, `menu_item`, `order_ticket`, `order_line_item`) to inspect daily revenue trends, reconcile cash vs. online sales, and audit cashier attributions, while being strictly prohibited from executing any `INSERT`, `UPDATE`, or `DELETE` statements.
- **Backup Isolation:** The dedicated backup operator `brewpos_backup` is granted read-only schema usage and `SELECT` on all tables and sequences to produce consistent logical dumps via `pg_dump -Fc` without DML or DDL write privileges.

### Access-Control Matrix
| Login Account | Group Role (`NOLOGIN`) | Application Role | Responsibilities | Assigned Privileges | Technical Justification |
|---|---|---|---|---|---|
| `brewpos_app` | `brewpos_runtime_grp` | Spring Boot Runtime (Register & Catalog) | Handles register order checkout, menu category management, product price updates, and item availability toggling | • `CONNECT` on `grp_brewposdb`<br>• `USAGE` on schema `public`<br>• `SELECT` on `staff`<br>• `SELECT, INSERT, UPDATE, DELETE` on `menu_category`, `menu_item`<br>• `SELECT, INSERT` **strictly on `order_ticket` & `order_line_item`**<br>• `USAGE, SELECT` on all sequences | Restricting `order_ticket` and `order_line_item` strictly to `SELECT` and `INSERT` prevents tampering with historical sales records, tax summaries, or sold prices under any application vulnerability. |
| `brewpos_auditor` | `brewpos_readonly_grp` | Financial Auditor / Inspector | Read-only inspection of daily register sales, tender methods, itemized order lines, and cashier transactions | • `CONNECT` on `grp_brewposdb`<br>• `USAGE` on schema `public`<br>• `SELECT` on all 5 tables (`staff`, `menu_category`, `menu_item`, `order_ticket`, `order_line_item`)<br>• `USAGE, SELECT` on all sequences | Full read transparency for financial and tax auditing with complete elimination of risk regarding unauthorized record mutation or table drops. |
| `brewpos_backup` | `brewpos_backup_grp` | Backup Operator | Runs logical database backups (`pg_dump`) | • `CONNECT` on `grp_brewposdb`<br>• `USAGE` on schema `public`<br>• `SELECT` on all tables & sequences | Grants complete read access required for logical dumps while strictly preventing DDL or DML write operations. |
| `postgres` | *(Superuser)* | Database Administrator | Schema provisioning, migrations, maintenance (`VACUUM`/`ANALYZE`), disaster recovery | Superuser / Owner privileges | Reserved strictly for DBA operations; never configured as the application runtime connection account. |

---

## 1.2 SQL Scripts Summary & Setup Execution

The access-control configuration script ([`db-access-control/group-04-brewpos/01_roles_and_grants.sql`](file:///E:/programming%20project/Data%20Ad/db-access-control/group-04-brewpos/01_roles_and_grants.sql)) was executed as `postgres` against `grp_brewposdb`:

```sql
-- 1. Create Group Roles (NOLOGIN)
CREATE ROLE brewpos_runtime_grp NOLOGIN;
CREATE ROLE brewpos_readonly_grp NOLOGIN;
CREATE ROLE brewpos_backup_grp NOLOGIN;

-- 2. Create Login Roles (LOGIN)
CREATE ROLE brewpos_app LOGIN PASSWORD 'AppRuntimePass2026!';
CREATE ROLE brewpos_auditor LOGIN PASSWORD 'AuditorPass2026!';
CREATE ROLE brewpos_backup LOGIN PASSWORD 'BackupPass2026!';

-- 3. Assign Role Memberships
GRANT brewpos_runtime_grp TO brewpos_app;
GRANT brewpos_readonly_grp TO brewpos_auditor;
GRANT brewpos_backup_grp TO brewpos_backup;

-- 4. Harden Session Defaults
ALTER ROLE brewpos_app IN DATABASE grp_brewposdb SET search_path = public;
ALTER ROLE brewpos_app IN DATABASE grp_brewposdb SET statement_timeout = '30s';
ALTER ROLE brewpos_app IN DATABASE grp_brewposdb SET lock_timeout = '10s';

-- 5. Lock down PUBLIC permissions
REVOKE ALL ON DATABASE grp_brewposdb FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- 6. Database Connection and Schema Usage
GRANT CONNECT ON DATABASE grp_brewposdb TO brewpos_runtime_grp, brewpos_readonly_grp, brewpos_backup_grp;
GRANT USAGE ON SCHEMA public TO brewpos_runtime_grp, brewpos_readonly_grp, brewpos_backup_grp;

-- 7. Application Runtime Permissions (Least Privilege)
GRANT SELECT ON public.staff TO brewpos_runtime_grp;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.menu_category, public.menu_item TO brewpos_runtime_grp;
GRANT SELECT, INSERT ON public.order_ticket, public.order_line_item TO brewpos_runtime_grp;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO brewpos_runtime_grp;

-- 8. Read-Only / Auditor Role Permissions
GRANT SELECT ON ALL TABLES IN SCHEMA public TO brewpos_readonly_grp;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO brewpos_readonly_grp;

-- 9. Backup Operator Permissions
GRANT SELECT ON ALL TABLES IN SCHEMA public TO brewpos_backup_grp;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO brewpos_backup_grp;

-- 10. Default Privileges for Future Objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT ON TABLES TO brewpos_runtime_grp;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO brewpos_runtime_grp;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO brewpos_readonly_grp;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO brewpos_backup_grp;
```

---

## 1.3 Verification Results: Test Suite 1 (Runtime User `brewpos_app`)

### Test 1.1: Read Data (Allowed)
- **SQL Statement:**
  ```sql
  SELECT item_id, item_name, price, is_active FROM menu_item LIMIT 5;
  ```
- **Expected Result:** Allowed; returns available café menu items.
- **Actual Result / Output:**
  ```text
   item_id | item_name  | price  | is_active 
  ---------+------------+--------+-----------
         2 | Espresso   |  80.00 | t
         3 | Cappuccino | 120.00 | t
         4 | Cafe Latte | 120.00 | t
         5 | Americano  |  90.00 | t
         6 | Fruit Tea  | 100.00 | t
  (5 rows)
  ```

### Test 1.2: Insert a Menu Item & Advance Sequence (Allowed)
- **SQL Statement:**
  ```sql
  INSERT INTO menu_item (category_id, item_name, price, is_active) 
  VALUES (1, 'Test Cinnamon Latte', 135.00, true) 
  RETURNING item_id, item_name;
  ```
- **Expected Result:** Allowed; inserts record and advances `menu_item_item_id_seq`.
- **Actual Result / Output:**
  ```text
   item_id |      item_name      
  ---------+---------------------
        23 | Test Cinnamon Latte
  (1 row)
  INSERT 0 1
  ```

### Test 1.3: Update Mutable Record (Allowed)
- **SQL Statement:**
  ```sql
  UPDATE menu_item SET price = 140.00 WHERE item_id = 23 RETURNING item_id, price;
  ```
- **Expected Result:** Allowed; runtime account updates mutable catalog attributes.
- **Actual Result / Output:**
  ```text
   item_id | price  
  ---------+--------
        23 | 140.00
  (1 row)
  UPDATE 1
  ```

### Test 1.4: Delete Unreferenced Menu Item (Allowed)
- **SQL Statement:**
  ```sql
  DELETE FROM menu_item WHERE item_id = 23 RETURNING item_id, item_name;
  ```
- **Expected Result:** Allowed; runtime account is authorized to remove unreferenced catalog products.
- **Actual Result / Output:**
  ```text
   item_id |      item_name      
  ---------+---------------------
        23 | Test Cinnamon Latte
  (1 row)
  DELETE 1
  ```

### Test 1.5: Insert an Order Ticket & Line Item (Allowed)
- **SQL Statement:**
  ```sql
  INSERT INTO order_ticket (staff_id, payment_method) VALUES (1, 'CASH') RETURNING order_id;
  INSERT INTO order_line_item (order_id, item_id, quantity, sold_price) 
  VALUES ((SELECT max(order_id) FROM order_ticket), 2, 2, 80.00) 
  RETURNING order_id, item_id, quantity, sold_price;
  ```
- **Expected Result:** Allowed; runtime account submits new customer order and line items.
- **Actual Result / Output:**
  ```text
   order_id 
  ----------
         10
  (1 row)
  INSERT 0 1

   order_id | item_id | quantity | sold_price 
  ----------+---------+----------+------------
         10 |       2 |        2 |      80.00
  (1 row)
  INSERT 0 1
  ```

### Test 1.6: Attempt to Update Order Ticket (Denied — Narrow Immutability Enforcement)
- **SQL Statement:**
  ```sql
  UPDATE order_ticket SET payment_method = 'ONLINE' WHERE order_id = 10;
  ```
- **Expected Result:** Denied; runtime account must never alter completed financial transaction records.
- **Actual Result / Output:**
  ```text
  ERROR:  permission denied for table order_ticket
  ```

### Test 1.7: Attempt to Delete Order Ticket (Denied — Sales Tamper Protection)
- **SQL Statement:**
  ```sql
  DELETE FROM order_ticket WHERE order_id = 10;
  ```
- **Expected Result:** Denied; runtime account cannot purge historical sales records.
- **Actual Result / Output:**
  ```text
  ERROR:  permission denied for table order_ticket
  ```

### Test 1.8: Attempt to Delete Order Line Item (Denied)
- **SQL Statement:**
  ```sql
  DELETE FROM order_line_item WHERE order_id = 10;
  ```
- **Expected Result:** Denied; itemized receipts cannot be modified post-transaction.
- **Actual Result / Output:**
  ```text
  ERROR:  permission denied for table order_line_item
  ```

### Test 1.9: Alter Table / DDL Operations (Denied)
- **SQL Statement:**
  ```sql
  DROP TABLE order_line_item;
  ```
- **Expected Result:** Denied; DDL requires object ownership.
- **Actual Result / Output:**
  ```text
  ERROR:  must be owner of table order_line_item
  ```

---

## 1.4 Verification Results: Test Suite 2 (Read-Only / Auditor User `brewpos_auditor`)

### Test 2.1: Read Orders and Joined Financial Data (Allowed)
- **SQL Statement:**
  ```sql
  SELECT o.order_id, o.order_timestamp, o.payment_method, s.full_name, 
         count(l.item_id) AS line_count, sum(l.quantity * l.sold_price) AS order_total 
  FROM order_ticket o 
  JOIN staff s ON o.staff_id = s.staff_id 
  JOIN order_line_item l ON o.order_id = l.order_id 
  GROUP BY o.order_id, o.order_timestamp, o.payment_method, s.full_name 
  ORDER BY o.order_id 
  LIMIT 5;
  ```
- **Expected Result:** Allowed; auditor inspection query executes successfully.
- **Actual Result / Output:**
  ```text
   order_id |   order_timestamp   | payment_method |  full_name   | line_count | order_total 
  ----------+---------------------+----------------+--------------+------------+-------------
          1 | 2026-11-04 09:15:00 | CASH           | Demo Cashier |          2 |      255.50
          2 | 2026-11-04 10:40:00 | ONLINE         | Demo Cashier |          2 |      300.00
          3 | 2026-11-04 13:05:00 | CASH           | Demo Manager |          1 |      360.00
          4 | 2026-11-03 16:30:00 | ONLINE         | Demo Cashier |          3 |      280.00
          5 | 2026-11-03 08:20:00 | CASH           | Demo Manager |          1 |      160.00
  (5 rows)
  ```

### Test 2.2: Attempt to Insert Data (Denied)
- **SQL Statement:**
  ```sql
  INSERT INTO menu_category (category_name) VALUES ('Rogue Category');
  ```
- **Expected Result:** Denied; read-only account cannot insert data.
- **Actual Result / Output:**
  ```text
  ERROR:  permission denied for table menu_category
  ```

### Test 2.3: Attempt to Update Records (Denied)
- **SQL Statement:**
  ```sql
  UPDATE menu_item SET price = 999.00 WHERE item_id = 2;
  ```
- **Expected Result:** Denied; read-only account cannot alter product prices.
- **Actual Result / Output:**
  ```text
  ERROR:  permission denied for table menu_item
  ```

### Test 2.4: Attempt to Delete Records (Denied)
- **SQL Statement:**
  ```sql
  DELETE FROM order_ticket WHERE order_id = 1;
  ```
- **Expected Result:** Denied; read-only account cannot delete sales records.
- **Actual Result / Output:**
  ```text
  ERROR:  permission denied for table order_ticket
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
  psql -U brewpos_app -h localhost -p 5432 -d grp07_campussafedb -c "SELECT 1;"
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
1. **Java 25 LTS Runtime Compatibility:** BrewPOS is built with Spring Boot 4.1.1 and compiled smoothly under Java 25 LTS. The Maven wrapper (`mvnw.cmd`) automatically downloaded dependencies and executed the build cleanly.
2. **PostgreSQL Default Role vs. Application Role:** In `brewpos/.env`, `DB_USERNAME` defaults to `postgres`. We verified that switching `.env` to `DB_USERNAME=brewpos_app` and setting `DB_PASSWORD=AppRuntimePass2026!` works seamlessly with Spring Data JPA and HikariCP connection pooling.
3. **Session Hardening Attributes:** Added `statement_timeout = '30s'` and `lock_timeout = '10s'` to role `brewpos_app` in `01_roles_and_grants.sql` to prevent stalled register queries from exhausting connection pool slots.

### Feedback to Owning Group (Group 4: BrewPOS)
- **Commendation:** The relational schema architecture is exemplary. The design strictly enforces 3NF without redundant total columns (`sold_price` is captured at line creation, and totals are computed dynamically via `SUM(quantity * sold_price)`). Using a pure composite primary key `(order_id, item_id)` on `order_line_item` without an unnecessary surrogate ID is a textbook implementation of relational database principles. Furthermore, `OrderService.java` cleanly handles duplicate item entries by aggregating quantities in-memory before persisting (`quantities.merge(line.itemId(), line.quantity(), Math::addExact)`).
- **Recommendation 1:** In `database/05_create_app_role.sql`, privileges were granted directly to `brewpos_app` rather than through an intermediate `NOLOGIN` group role. Transitioning to the two-tier structure (`brewpos_runtime_grp` &rarr; `brewpos_app`, `brewpos_readonly_grp` &rarr; `brewpos_auditor`) as documented in `docs/user-roles.md` improves operational scalability when multiple register terminals or auditor accounts are provisioned.
- **Recommendation 2:** Consider adding an automated verification script (such as `test_roles.bat` or `verify_rbac.ps1`) to enable evaluators to test least-privilege role assertions across all 5 tables with a single command.

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
- **Total Database Size:** `8430 kB` (~8.4 MB)
- **Object Count:** `total_tables: 5`, `total_sequences: 4`
- **Table Storage Breakdown:**
  ```text
     table_name    | total_size | table_size | index_size 
  -----------------+------------+------------+------------
   menu_category   | 40 kB      | 8192 bytes | 32 kB
   menu_item       | 40 kB      | 8192 bytes | 32 kB
   order_ticket    | 40 kB      | 8192 bytes | 32 kB
   order_line_item | 40 kB      | 8192 bytes | 32 kB
   staff           | 24 kB      | 8192 bytes | 16 kB
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
WHERE r.rolname IN ('postgres', 'brewpos_app', 'brewpos_auditor', 'brewpos_backup', 'brewpos_runtime_grp', 'brewpos_readonly_grp', 'brewpos_backup_grp')
ORDER BY r.rolname;
```

### Actual Output
- **Database Statistics:**
  ```text
      datname    | open_connections | committed_transactions | rolled_back_transactions | conflicts | deadlocks 
  ---------------+------------------+------------------------+--------------------------+-----------+-----------
   grp_brewposdb |                1 |                     72 |                        8 |         0 |         0
  ```
  *Analysis:* `conflicts = 0`, `deadlocks = 0`. The 8 rolled back transactions correspond exactly to the intentional permission-denied tests executed during Activity 4 verification, confirming clean transaction isolation.
- **Roles Verification Output:**
  ```text
        role_name       | can_login | is_superuser |    member_of_group     
  ----------------------+-----------+--------------+------------------------
   brewpos_app          | t         | f            | {brewpos_runtime_grp}
   brewpos_auditor      | t         | f            | {brewpos_readonly_grp}
   brewpos_backup       | t         | f            | {brewpos_backup_grp}
   brewpos_backup_grp   | f         | f            | {}
   brewpos_readonly_grp | f         | f            | {}
   brewpos_runtime_grp  | f         | f            | {}
   postgres             | t         | t            | {}
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
   table_name    | sequential_scans | tuples_read_by_seq_scan | index_scans | live_tuples | dead_tuples | last_vacuum | last_autovacuum | last_analyze | last_autoanalyze 
-----------------+------------------+-------------------------+-------------+-------------+-------------+-------------+-----------------+--------------+------------------
 menu_item       |                6 |                      52 |           0 |           0 |           2 |             |                 |              | 
 staff           |                3 |                       5 |           4 |           0 |           0 |             |                 |              | 
 menu_category   |                2 |                       4 |           0 |           0 |           0 |             |                 |              | 
 order_line_item |                3 |                      58 |           2 |           1 |           0 |             |                 |              | 
 order_ticket    |                4 |                      39 |           2 |           1 |           0 |             |                 |              | 
(5 rows)
```
*Analysis:* `menu_item` accumulated 2 dead tuples as a direct result of the update and delete operations executed during Activity 4 testing. Routine `VACUUM` was warranted to reclaim those dead tuple slots.

---

## 2.4 Log Review & Issue Identification

### PostgreSQL Log Analysis (`D:\Postgre\data\log\postgresql-2026-11-05_104510.log`)
1. **Activity 4 Security Enforcement Interceptions:**
   - **Log Entry:** `ERROR: permission denied for table order_ticket STATEMENT: UPDATE order_ticket SET payment_method = 'ONLINE' WHERE order_id = 10;` by `brewpos_app`
   - **Log Entry:** `ERROR: permission denied for table order_ticket STATEMENT: DELETE FROM order_ticket WHERE order_id = 10;` by `brewpos_app`
   - **Log Entry:** `ERROR: permission denied for table order_line_item STATEMENT: DELETE FROM order_line_item WHERE order_id = 10;` by `brewpos_app`
   - **Log Entry:** `ERROR: must be owner of table order_line_item STATEMENT: DROP TABLE order_line_item;` by `brewpos_app`
   - **Log Entry:** `ERROR: permission denied for table menu_category STATEMENT: INSERT INTO menu_category (category_name) VALUES ('Rogue Category');` by `brewpos_auditor`
   - **Log Entry:** `ERROR: permission denied for table menu_item STATEMENT: UPDATE menu_item SET price = 999.00 WHERE item_id = 2;` by `brewpos_auditor`
   - **Log Entry:** `ERROR: permission denied for table order_ticket STATEMENT: DELETE FROM order_ticket WHERE order_id = 1;` by `brewpos_auditor`
   - **Log Entry:** `ERROR: permission denied to create database STATEMENT: CREATE DATABASE rogue_test_db;` by `brewpos_app`
   - **Log Entry:** `FATAL: permission denied for database "grp07_campussafedb" DETAIL: User does not have CONNECT privilege.` on connection by `brewpos_app`
   - **Assessment:** Positive validation of the Least Privilege policy. Every unauthorized DDL, DML mutation, and cross-database breach attempted during Activity 4 testing was intercepted and logged by PostgreSQL.
2. **Checkpoint & Background Writer Health:** Background checkpoints logged clean completions (e.g. `checkpoint complete: wrote 42 buffers (0.3%), write=4.596 s, sync=0.014 s, total=4.626 s`).
3. **Engine Health:** No unhandled crashes, transaction wraparound alerts, or disk I/O corruptions exist in the active log.

---

## 2.5 Routine Maintenance Operations (`ANALYZE` & `VACUUM`)

### Maintenance Commands Executed
```sql
-- Standalone maintenance execution as superuser / owner:
ANALYZE;
VACUUM (VERBOSE, ANALYZE) public.menu_item;
VACUUM (VERBOSE, ANALYZE) public.order_ticket;
VACUUM (VERBOSE, ANALYZE) public.order_line_item;
```

### Actual Output
- **Permission Boundary Test:** Running `VACUUM menu_item;` as `brewpos_app` produced:
  ```text
  WARNING:  permission denied to vacuum "menu_item", skipping it
  VACUUM
  ```
  This proves that runtime application accounts cannot perform maintenance operations.
- **`ANALYZE;` Output:**
  ```text
  ANALYZE
  ```
- **`VACUUM (VERBOSE, ANALYZE) public.menu_item;` Output:**
  ```text
  INFO:  vacuuming "grp_brewposdb.public.menu_item"
  INFO:  finished vacuuming "grp_brewposdb.public.menu_item": index scans: 1
  pages: 0 removed, 1 remain, 1 scanned (100.00% of total), 0 eagerly scanned
  tuples: 3 removed, 11 remain, 0 are dead but not yet removable
  removable cutoff: 967, which was 0 XIDs old when operation ended
  new relfrozenxid: 837, which is 1 XIDs ahead of previous value
  visibility map: 1 pages set all-visible, 0 pages set all-frozen (0 were all-visible)
  buffer usage: 88 hits, 0 reads, 7 dirtied
  WAL usage: 9 records, 8 full page images, 40269 bytes, 0 buffers full
  INFO:  analyzing "public.menu_item"
  INFO:  "menu_item": scanned 1 of 1 pages, containing 11 live rows and 0 dead rows; 11 rows in sample, 11 estimated total rows
  VACUUM
  ```
- **`VACUUM (VERBOSE, ANALYZE) public.order_ticket;` Output:**
  ```text
  INFO:  vacuuming "grp_brewposdb.public.order_ticket"
  INFO:  finished vacuuming "grp_brewposdb.public.order_ticket": index scans: 0
  pages: 0 removed, 1 remain, 1 scanned (100.00% of total), 0 eagerly scanned
  tuples: 0 removed, 10 remain, 0 are dead but not yet removable
  removable cutoff: 968, which was 0 XIDs old when operation ended
  visibility map: 1 pages set all-visible, 0 pages set all-frozen (0 were all-visible)
  buffer usage: 78 hits, 0 reads, 4 dirtied
  INFO:  analyzing "public.order_ticket"
  INFO:  "order_ticket": scanned 1 of 1 pages, containing 10 live rows and 0 dead rows; 10 rows in sample, 10 estimated total rows
  VACUUM
  ```
- **`VACUUM (VERBOSE, ANALYZE) public.order_line_item;` Output:**
  ```text
  INFO:  vacuuming "grp_brewposdb.public.order_line_item"
  INFO:  finished vacuuming "grp_brewposdb.public.order_line_item": index scans: 0
  pages: 0 removed, 1 remain, 1 scanned (100.00% of total), 0 eagerly scanned
  tuples: 0 removed, 20 remain, 0 are dead but not yet removable
  removable cutoff: 969, which was 0 XIDs old when operation ended
  visibility map: 1 pages set all-visible, 0 pages set all-frozen (0 were all-visible)
  buffer usage: 71 hits, 0 reads, 4 dirtied
  INFO:  analyzing "public.order_line_item"
  INFO:  "order_line_item": scanned 1 of 1 pages, containing 20 live rows and 0 dead rows; 20 rows in sample, 20 estimated total rows
  VACUUM
  ```

### DBA Justification on Role Permissions & Exclusion of `VACUUM FULL`
- **Role Permission Boundary:** `VACUUM` requires table ownership. Attempting it under `brewpos_app` resulted in a permission denial, confirming that routine maintenance must be orchestrated by a designated maintenance or administrative account (`postgres`).
- **Exclusion of `VACUUM FULL`:** `VACUUM FULL` rewrites entire table files and acquires an `AccessExclusiveLock`, blocking concurrent SELECT and INSERT queries at the café register. Because BrewPOS tables contain dozens of records fitting comfortably inside single 8 kB heap pages, standard non-blocking `VACUUM` reclaimed all dead tuples (`3 removed` in `menu_item`) with zero POS downtime.

---

## 2.6 Query Performance Analysis (`EXPLAIN` & `EXPLAIN (ANALYZE, BUFFERS)`)

### Query 1: Daily Sales Filter by Date Range and Order Timestamp
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, staff_id, order_timestamp, payment_method
FROM order_ticket
WHERE order_timestamp >= CURRENT_DATE AND order_timestamp < CURRENT_DATE + INTERVAL '1 day'
ORDER BY order_timestamp DESC;
```

#### Actual Execution Plan Output
```text
                                                   QUERY PLAN                                                   
----------------------------------------------------------------------------------------------------------------
 Sort  (cost=1.27..1.28 rows=4 width=21) (actual time=0.034..0.035 rows=3.00 loops=1)
   Sort Key: order_timestamp DESC
   Sort Method: quicksort  Memory: 25kB
   Buffers: shared hit=4
   ->  Seq Scan on order_ticket  (cost=0.00..1.23 rows=4 width=21) (actual time=0.013..0.014 rows=3.00 loops=1)
         Filter: ((order_timestamp >= CURRENT_DATE) AND (order_timestamp < (CURRENT_DATE + '1 day'::interval)))
         Rows Removed by Filter: 7
         Buffers: shared hit=1
 Planning:
   Buffers: shared hit=106
 Planning Time: 2.336 ms
 Execution Time: 0.068 ms
(12 rows)
```

#### Interpretation
1. **Execution Time:** `0.068 ms` (sub-millisecond execution).
2. **Buffer Efficiency:** `shared hit = 4`, with 0 physical disk block reads (100% in-memory cache hit).
3. **Sequential Scan Justification:** Even though an index `idx_order_ticket_timestamp` exists on `order_timestamp`, the PostgreSQL query planner deliberately chose a `Seq Scan` on `order_ticket`. Because the entire table fits inside a single 8 kB heap block (`Buffers: shared hit = 1`), sequentially scanning that block in RAM is computationally faster than traversing B-Tree index pages followed by random pointer lookups into the heap.

---

### Query 2: Multi-table Join for Receipt Generation
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    o.order_id,
    o.order_timestamp,
    o.payment_method,
    s.full_name AS cashier_name,
    m.item_name,
    c.category_name,
    l.quantity,
    l.sold_price,
    (l.quantity * l.sold_price) AS line_total
FROM order_ticket o
JOIN staff s ON o.staff_id = s.staff_id
JOIN order_line_item l ON o.order_id = l.order_id
JOIN menu_item m ON l.item_id = m.item_id
JOIN menu_category c ON m.category_id = c.category_id
WHERE o.order_id = 1;
```

#### Actual Execution Plan Output
```text
                                                              QUERY PLAN                                                               
---------------------------------------------------------------------------------------------------------------------------------------
 Nested Loop  (cost=1.27..5.73 rows=2 width=93) (actual time=0.102..0.108 rows=2.00 loops=1)
   Join Filter: (m.category_id = c.category_id)
   Rows Removed by Join Filter: 2
   Buffers: shared hit=5
   ->  Nested Loop  (cost=1.27..4.62 rows=2 width=56) (actual time=0.086..0.089 rows=2.00 loops=1)
         Buffers: shared hit=4
         ->  Nested Loop  (cost=0.00..2.17 rows=1 width=30) (actual time=0.020..0.021 rows=1.00 loops=1)
               Join Filter: (s.staff_id = o.staff_id)
               Buffers: shared hit=2
               ->  Seq Scan on order_ticket o  (cost=0.00..1.12 rows=1 width=21) (actual time=0.013..0.014 rows=1.00 loops=1)
                     Filter: (order_id = 1)
                     Rows Removed by Filter: 9
                     Buffers: shared hit=1
               ->  Seq Scan on staff s  (cost=0.00..1.02 rows=2 width=17) (actual time=0.004..0.005 rows=1.00 loops=1)
                     Buffers: shared hit=1
         ->  Hash Join  (cost=1.27..2.42 rows=2 width=30) (actual time=0.066..0.068 rows=2.00 loops=1)
               Hash Cond: (m.item_id = l.item_id)
               Buffers: shared hit=2
               ->  Seq Scan on menu_item m  (cost=0.00..1.11 rows=11 width=21) (actual time=0.005..0.005 rows=11.00 loops=1)
                     Buffers: shared hit=1
               ->  Hash  (cost=1.25..1.25 rows=2 width=17) (actual time=0.015..0.015 rows=2.00 loops=1)
                     Buckets: 1024  Batches: 1  Memory Usage: 9kB
                     Buffers: shared hit=1
                     ->  Seq Scan on order_line_item l  (cost=0.00..1.25 rows=2 width=17) (actual time=0.006..0.008 rows=2.00 loops=1)
                           Filter: (order_id = 1)
                           Rows Removed by Filter: 18
                           Buffers: shared hit=1
   ->  Materialize  (cost=0.00..1.04 rows=3 width=13) (actual time=0.004..0.004 rows=2.00 loops=2)
         Storage: Memory  Maximum Storage: 17kB
         Buffers: shared hit=1
         ->  Seq Scan on menu_category c  (cost=0.00..1.03 rows=3 width=13) (actual time=0.006..0.006 rows=3.00 loops=1)
               Buffers: shared hit=1
 Planning:
   Buffers: shared hit=373 read=1
 Planning Time: 7.513 ms
 Execution Time: 0.176 ms
(36 rows)
```

#### Interpretation
1. **Execution Time:** `0.176 ms`.
2. **Buffer Hits:** `shared hit = 5` (100% cache hit, 0 physical disk reads during query execution).
3. **Join Strategy:** The query planner built an in-memory hash table for `order_line_item` (9 kB), executed a `Hash Join` with `menu_item`, and combined `staff` and `menu_category` via `Nested Loops` and a lightweight `Materialize` node (17 kB) with zero disk spills.

---

## 2.7 Prioritized Recommendations & Technical Justification

| Priority | Action Item | Technical Justification |
|---|---|---|
| **No Action Required (Current)** | Retain current schema indexes | Both explicit performance indexes (`idx_order_ticket_timestamp` and `idx_order_line_item_item_id`) and all primary/foreign key indexes are properly structured. Query execution times are well under 0.2 ms with 100% buffer cache hits. |
| **Follow-up Action** | Composite Index for High-Volume Register Operations | When scaling past 50,000 orders in enterprise production, filtering daily sales by timestamp and payment method simultaneously will benefit from a composite index: `CREATE INDEX idx_order_ticket_timestamp_payment ON order_ticket (order_timestamp, payment_method);`. |
| **Follow-up Action** | Automated Maintenance Script via Task Scheduler | Deploy a scheduled weekly maintenance job invoking `VACUUM (ANALYZE)` during off-hours (e.g. Sunday 02:00 AM) to reclaim dead tuples generated by frequent product price updates and seasonal item deactivations. |

---

# ACTIVITY 6: Database Backup, Restoration, and Recovery

## 3.1 Backup Planning & Architecture

### Strategy Matrix
| Parameter | Plan for `grp_brewposdb` | Technical Justification |
|---|---|---|
| **Target Database & Objects** | `grp_brewposdb` (Schema: `public`)<br>• 5 Relational Tables: `staff`, `menu_category`, `menu_item`, `order_ticket`, `order_line_item`<br>• 4 Sequences, Primary Keys, Foreign Keys, Unique/Check Constraints, Indexes, Table Grants | Full consistency across cashier staff, product categories, active/inactive menu items, completed customer order tickets, and itemized composite line items with historical sold prices. |
| **Backup Format** | **PostgreSQL Custom Archive Format (`-Fc` / Custom)** | Compressed binary format; supports selective table-level restoration and parallel processing via `pg_restore`. |
| **Storage & Security** | Dedicated protected directory: `C:\Users\jorpe\OneDrive\Documents\pg_backups\`<br>Filename: `grp_brewposdb_activity6.dump` | Restricted to database administrators. Kept out of web roots and excluded from Git commits via `.gitignore`. |
| **RPO & RTO** | **RPO (Recovery Point Objective):** 24 Hours<br>**RTO (Recovery Time Objective):** 2 Hours | Nightly dumps at 01:00 AM are sufficient for café POS transaction volumes. RTO of 2 hours provides ample buffer to provision a standby instance, restore schemas, and repoint application DSNs. |
| **Retention Policy** | 7 Daily Backups + 4 Weekly Snapshots | Balances disk consumption with multi-week disaster recovery compliance. |
| **Activity 4 Roles Re-creation** | PostgreSQL roles (`brewpos_app`, `brewpos_auditor`, `brewpos_backup`) are **cluster-wide** and are **not** stored inside a single-database dump. | On a new server instance, Activity 4 role scripts (`01_roles_and_grants.sql`) must run **prior** to or immediately following restore to ensure object ownership and ACLs attach cleanly. |

---

## 3.2 Backup Creation, Checksum & Archive Inspection

### Backup Execution
Executed using `pg_dump` with custom archive format (`-Fc`) using the dedicated `brewpos_backup` role:
```bash
pg_dump -U brewpos_backup -h localhost -p 5432 -Fc -d grp_brewposdb -f "C:\Users\jorpe\OneDrive\Documents\pg_backups\grp_brewposdb_activity6.dump"
```

### File Metadata & Checksum Verification (PowerShell)
- **PowerShell Commands:**
  ```powershell
  Get-FileHash -Path "C:\Users\jorpe\OneDrive\Documents\pg_backups\grp_brewposdb_activity6.dump" -Algorithm SHA256 | Format-List
  Get-Item "C:\Users\jorpe\OneDrive\Documents\pg_backups\grp_brewposdb_activity6.dump" | Select-Object Name, Length, LastWriteTime
  ```
- **Recorded Details:**
  ```text
  Algorithm : SHA256
  Hash      : 03A4DAE6DED7EAD5A24380A6E81F287B6EA05AD329A1A71AB8264985E65731E5
  Path      : C:\Users\jorpe\OneDrive\Documents\pg_backups\grp_brewposdb_activity6.dump

  Name                         Length LastWriteTime        
  ----                         ------ -------------        
  grp_brewposdb_activity6.dump  19493 11/5/2026 4:22:50 PM
  ```

### Archive Inspection (`pg_restore --list`)
Inspecting the archive table of contents (`pg_restore --list`) confirmed **57 TOC entries**, including all 5 tables (`staff`, `menu_category`, `menu_item`, `order_ticket`, `order_line_item`), sequences, primary keys, check constraints, foreign keys, indexes, and ACL grants.

*DBA Justification:* An archive file existing on disk is not proof of recoverability. Physical corruption, missing dependencies, or incompatible cluster versions can cause silent failures. A complete restore drill into an isolated environment is required.

---

## 3.3 Restoration into Separate Test Database (`grp_brewposdb_restore_test`)

1. **Created Test Database:**
   ```bash
   createdb -U postgres -h localhost -p 5432 grp_brewposdb_restore_test
   ```
2. **Restored Backup Archive:**
   ```bash
   pg_restore -U postgres -h localhost -p 5432 -d grp_brewposdb_restore_test "C:\Users\jorpe\OneDrive\Documents\pg_backups\grp_brewposdb_activity6.dump"
   ```
   *Outcome:* Executed cleanly with exit code 0.

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
     table_name    | table_type |  owner   
  -----------------+------------+----------
   menu_category   | BASE TABLE | postgres
   menu_item       | BASE TABLE | postgres
   order_line_item | BASE TABLE | postgres
   order_ticket    | BASE TABLE | postgres
   staff           | BASE TABLE | postgres
  (5 rows)
  ```

### 2. Verify Record Counts Across All Tables
- **Query:**
  ```sql
  SELECT 'staff' AS tbl, count(*) FROM staff
  UNION ALL SELECT 'menu_category', count(*) FROM menu_category
  UNION ALL SELECT 'menu_item', count(*) FROM menu_item
  UNION ALL SELECT 'order_ticket', count(*) FROM order_ticket
  UNION ALL SELECT 'order_line_item', count(*) FROM order_line_item;
  ```
- **Actual Output:**
  ```text
         tbl       | count 
  -----------------+-------
   staff           |     2
   menu_category   |     3
   menu_item       |    11
   order_ticket    |    10
   order_line_item |    20
  (5 rows)
  ```
  *Analysis:* Record counts match the source database 100%.

### 3. Verify Activity 4 Access Control on Restored Database
- **Runtime User Test (`brewpos_app`):**
  ```bash
  psql -U brewpos_app -h localhost -p 5432 -d grp_brewposdb_restore_test -c "SELECT item_id, item_name, price FROM menu_item LIMIT 3;"
  ```
  *Output:*
  ```text
   item_id | item_name  | price  
  ---------+------------+--------
         2 | Espresso   |  80.00
         3 | Cappuccino | 120.00
         4 | Cafe Latte | 120.00
  (3 rows)
  ```
- **Runtime Restriction Test (`brewpos_app` attempting to update `order_ticket`):**
  ```bash
  psql -U brewpos_app -h localhost -p 5432 -d grp_brewposdb_restore_test -c "UPDATE order_ticket SET payment_method = 'CASH' WHERE order_id = 1;"
  ```
  *Output:*
  ```text
  ERROR:  permission denied for table order_ticket
  ```
- **Auditor Read Test (`brewpos_auditor` reading orders):**
  ```bash
  psql -U brewpos_auditor -h localhost -p 5432 -d grp_brewposdb_restore_test -c "SELECT o.order_id, o.payment_method, count(l.item_id) FROM order_ticket o JOIN order_line_item l ON o.order_id = l.order_id GROUP BY o.order_id, o.payment_method ORDER BY o.order_id LIMIT 3;"
  ```
  *Output:*
  ```text
   order_id | payment_method | count 
  ----------+----------------+-------
          1 | CASH           |     2
          2 | ONLINE         |     2
          3 | CASH           |     1
  (3 rows)
  ```
- **Auditor Restriction Test (`brewpos_auditor` attempting to insert into `menu_category`):**
  ```bash
  psql -U brewpos_auditor -h localhost -p 5432 -d grp_brewposdb_restore_test -c "INSERT INTO menu_category (category_name) VALUES ('Hacked Category');"
  ```
  *Output:*
  ```text
  ERROR:  permission denied for table menu_category
  ```
  *Conclusion:* Least-privilege ACLs, sequence privileges, and sales immutability transferred seamlessly into the restored database.

---

## 3.5 Controlled Recovery Simulation (Incident & Recovery Drill)

### Step 1: Pre-Incident Baseline State
In `grp_brewposdb_restore_test`, a disposable test sales order was established:
- **Query:**
  ```sql
  INSERT INTO order_ticket (order_id, staff_id, order_timestamp, payment_method)
  VALUES (999, 1, CURRENT_TIMESTAMP, 'CASH');

  INSERT INTO order_line_item (order_id, item_id, quantity, sold_price)
  VALUES (999, 2, 3, 80.00);

  SELECT o.order_id, o.order_timestamp, o.payment_method, l.item_id, l.quantity, l.sold_price
  FROM order_ticket o
  JOIN order_line_item l ON o.order_id = l.order_id
  WHERE o.order_id = 999;
  ```
- **Actual Output:**
  ```text
   order_id |      order_timestamp       | payment_method | item_id | quantity | sold_price 
  ----------+----------------------------+----------------+---------+----------+------------
        999 | 2026-11-05 16:29:13.543537 | CASH           |       2 |        3 |      80.00
  (1 row)
  ```

### Step 2: Simulated Data-Loss Incident
Accidental catastrophic deletion was simulated:
- **Query:**
  ```sql
  DELETE FROM order_line_item WHERE order_id = 999;
  DELETE FROM order_ticket WHERE order_id = 999;
  SELECT count(*) AS count_after_deletion FROM order_ticket WHERE order_id = 999;
  ```
- **Actual Output:**
  ```text
  DELETE 1
  DELETE 1
   count_after_deletion 
  ----------------------
                      0
  (1 row)
  ```
  *Observation:* Record `999` is missing; data loss confirmed.

### Step 3: Targeted Recovery
Targeted restoration was executed to reinstate the records from baseline:
- **Query:**
  ```sql
  INSERT INTO order_ticket (order_id, staff_id, order_timestamp, payment_method)
  VALUES (999, 1, '2026-11-05 16:29:13.543537', 'CASH')
  ON CONFLICT (order_id) DO NOTHING;

  INSERT INTO order_line_item (order_id, item_id, quantity, sold_price)
  VALUES (999, 2, 3, 80.00)
  ON CONFLICT (order_id, item_id) DO NOTHING;

  SELECT o.order_id, o.order_timestamp, o.payment_method, l.item_id, l.quantity, l.sold_price
  FROM order_ticket o
  JOIN order_line_item l ON o.order_id = l.order_id
  WHERE o.order_id = 999;
  ```
- **Actual Output:**
  ```text
   order_id |      order_timestamp       | payment_method | item_id | quantity | sold_price 
  ----------+----------------------------+----------------+---------+----------+------------
        999 | 2026-11-05 16:29:13.543537 | CASH           |       2 |        3 |      80.00
  (1 row)
  ```

### Step 4: Post-Recovery Verification and Drill Cleanup
The sales ticket and line item were verified intact with original cashier ID, timestamp, quantities, and unit price preserved. The drill records were subsequently cleaned up:
```sql
DELETE FROM order_line_item WHERE order_id = 999;
DELETE FROM order_ticket WHERE order_id = 999;
```

---

## 3.6 Limitations, Evaluation & Production Recommendations

### Post-Restore Considerations
1. **Cluster-Wide Roles Dependency:** Single-database dumps do not store database user roles. If restoring to a brand-new PostgreSQL server instance, `db-access-control/group-04-brewpos/01_roles_and_grants.sql` must be applied to define `brewpos_runtime_grp`, `brewpos_app`, `brewpos_auditor`, etc., before permissions can attach.
2. **Production Backup Recommendations:**
   - **Automated Nightly Dumps:** Configure a scheduled PowerShell script via Windows Task Scheduler to execute `pg_dump -Fc` nightly at 01:00 AM, appending the ISO date (`grp_brewposdb_YYYY-MM-DD.dump`) and purging backups older than 14 days.
   - **Continuous WAL Archiving (PITR):** For high-volume multi-branch café POS deployments where even a 24-hour RPO poses financial risk, configure Write-Ahead Logging (`archive_mode = on`, `archive_command`) to achieve sub-minute Point-in-Time Recovery.

---

# CONSOLIDATED CLASS GOOGLE SHEETS TRACKER ENTRIES

Below are the exact values to record in the class Google Sheets tracker:

### Activity 4 Log Tab
| Column Header | Value |
|---|---|
| **Project** | Group 4 - BrewPOS: Café Point-of-Sale System |
| **Repository cloned** | `https://github.com/Nycri/brewpos`, Branch: `main` |
| **Database setup result** | Success (Verified PostgreSQL 18.6 on port 5432, executed schema DDL and seed data, 5 tables loaded). |
| **Access-control folder link** | `https://github.com/jeffersonorpesa2-ops/grp07-campussafe/tree/main/db-access-control/group-04-brewpos/` |
| **Access-control status** | Completed |
| **Feedback sent to owners** | (05/11/2026) |
| **PDF progress document** |  |
| **Last updated** | 2026-11-05 |

### Activity 5 Log Tab
| Column Header | Value |
|---|---|
| **Project** | Group 4 - BrewPOS: Café Point-of-Sale System |
| **Database inspected** | `grp_brewposdb` (PostgreSQL 18.6) |
| **Account and role used** | `postgres` (DBA Maintenance), `brewpos_app` (Runtime), `brewpos_auditor` (Audit) |
| **Health check result** | Healthy (0 conflicts, 0 deadlocks, 8.4 MB footprint, 100% buffer cache hits) |
| **Maintenance performed** | `ANALYZE; VACUUM (VERBOSE, ANALYZE) on menu_item, order_ticket, order_line_item via postgres` |
| **Query analyzed** | Daily sales date filter with sort (Seq scan, 0.068 ms, 4 buffer hits) & Multi-table receipt join (Nested loops/Hash join, 0.176 ms) |
| **Recommendation priority** | No action required (Current queries execute in < 0.18 ms with 100% buffer cache hits) |
| **Evidence folder link** | `https://github.com/jeffersonorpesa2-ops/grp07-campussafe/tree/main/db-maintenance/group-04-brewpos/` |
| **Feedback sent to owners** | (05/11/2026) |
| **PDF progress document** |  |
| **Last updated** | 2026-11-05 |

### Activity 6 Log Tab
| Column Header | Value |
|---|---|
| **Project** | Group 4 - BrewPOS: Café Point-of-Sale System |
| **Database and backup file** | `grp_brewposdb`, `grp_brewposdb_activity6.dump`, Size: 19,493 bytes, SHA256: `03A4DAE6DED7EAD5A24380A6E81F287B6EA05AD329A1A71AB8264985E65731E5` |
| **Backup method** | pg_dump custom format (`-Fc`), compressed binary dump (2026-11-05 16:22:50) |
| **Restore test result** | Success (Restored into `grp_brewposdb_restore_test`; all 5 tables, constraints, and data verified) |
| **Access control after restore** | (Activity 4 roles and permissions validated; `brewpos_app` denied UPDATE on `order_ticket`, `brewpos_auditor` denied INSERT) |
| **Recovery simulation result** | Recovered (Simulated deleted test sales order and line items successfully restored from baseline state) |
| **Proposed RPO and RTO** | RPO: 24 hours, RTO: 2 hours |
| **Evidence folder link** | `https://github.com/jeffersonorpesa2-ops/grp07-campussafe/tree/main/db-backup-recovery/group-04-brewpos/` |
| **Feedback sent to owners** | (05/11/2026) |
| **PDF progress document** |  |
| **Last updated** | 2026-11-05 |

---

# AI USAGE DECLARATION

- **AI Tools Used:** Google Gemini 3.8 Flash (via Antigravity AI assistant).
- **Tasks Performed:** 
  1. Inspecting database schema definitions, constraints, and composite relationship hierarchies for Group 4's BrewPOS platform.
  2. Formulating and executing PostgreSQL least-privilege verification test suites for Activity 4 (narrow immutability scoping for sales data).
  3. Diagnosing runtime maintenance boundaries, executing `VACUUM` and `ANALYZE`, and profiling execution plans (`EXPLAIN (ANALYZE, BUFFERS)`) for Activity 5.
  4. Executing custom archive backup creation with `pg_dump`, SHA256 checksum computation, test database restoration with `pg_restore`, and controlled recovery simulation drill for Activity 6.
  5. Compiling and formatting comprehensive progress documentation adhering to course rubric guidelines.
- **Validation:** Every SQL query, maintenance command, backup job, and verification statement was executed and validated directly on PostgreSQL 18.6 in pgAdmin 4 / `psql`. Real outputs, timings, and checksums are recorded in this report.
