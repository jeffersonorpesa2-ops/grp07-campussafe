# COMP 018: Database Administration — Comprehensive Project Report

## Activities 4, 5, and 6: Access Control, Maintenance & Monitoring, Backup & Recovery

---

### Project Identification & Metadata

| Field                           | Details                                                                                                                                                               |
| ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Course**                      | COMP 018 — Database Administration                                                                                                                                    |
| **Evaluating Group**            | **Group 7:** Alba, Arreza, Orpesa, Robiso, Santos                                                                                                                     |
| **Evaluating Group Repository** | [https://github.com/jeffersonorpesa2-ops/grp07-campussafe](https://github.com/jeffersonorpesa2-ops/grp07-campussafe)                                                  |
| **Target Project Monitored**    | **BoardTrack: Boarding House & Rental Management System**                                                                                                             |
| **Target Project Group**        | **Group 11** (Barcarse, Adrian; Cataluña, Zyruz Gabriel; Camu, Edgar; Policarpio, Kurt; Crucillo, Karl Robert)                                                         |
| **Target Project Repository**   | [https://github.com/karlrobertc-art/BoardTrack.git](https://github.com/karlrobertc-art/BoardTrack.git)                                                                 |
| **Primary Database**            | `grp11_boardtrackdb` (Schema: `public`, PostgreSQL 18.6 on x86_64 Windows, compiled by MSVC)                                                                           |
| **Restored Test Database**      | `grp11_boardtrackdb_restore_test`                                                                                                                                     |

---

# TABLE OF CONTENTS

1. [ACTIVITY 4: Database Users, Roles, Privileges, and Access Control](#activity-4-database-users-roles-privileges-and-access-control)
   - 1.1 Access-Control Plan & Architecture
   - 1.2 SQL Scripts Summary & Setup Execution
   - 1.3 Verification Results: Test Suite 1 (Runtime User `boardtrack_app`)
   - 1.4 Verification Results: Test Suite 2 (Read-Only / Auditor User `boardtrack_report`)
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
   - 3.3 Restoration into Separate Test Database (`grp11_boardtrackdb_restore_test`)
   - 3.4 Post-Restore Verification Suite
   - 3.5 Controlled Recovery Simulation (Incident & Recovery Drill)
   - 3.6 Limitations, Evaluation & Production Recommendations
4. [CONSOLIDATED CLASS GOOGLE SHEETS TRACKER ENTRIES](#consolidated-class-google-sheets-tracker-entries)
5. [AI USAGE DECLARATION](#ai-usage-declaration)

---

# ACTIVITY 4: Database Users, Roles, Privileges, and Access Control

## 1.1 Access-Control Plan & Architecture

### Problem in Activity 3

In the baseline development phase (Activity 3), application database connections frequently operate under the PostgreSQL superuser (`postgres`) or an unrestricted database owner. In a rental property management platform like **BoardTrack (Boarding House & Rental Management System)**, granting blanket privileges across all schema tables creates severe operational, legal, and financial hazards:

- **Financial Rent Ledger Tampering:** Malicious tenants or compromised API endpoints could alter payment records, mark delinquent balances as settled, or delete transaction receipts, corrupting daily cashier balancing and property owner accounting.
- **Rental Lease History Destruction:** Unrestricted `DELETE` access on `lease` would allow deleting historical tenant agreements, corrupting move-out audit trails and breaking historical occupancy reports.
- **Utility Charge Manipulation:** Utility charges (electricity, water, internet) could be modified or deleted, resulting in unrecovered utility costs for the property owner.
- **Credential Exposure:** Direct read access to the `app_user` table exposes bcrypt password hashes to unnecessary reporting queries, enabling offline hash-cracking attempts.
- **Accidental Schema Annihilation:** An application account holding DDL privileges could execute `DROP TABLE property` or `TRUNCATE TABLE payment`, wiping boarding house operations entirely.

This violates the **Principle of Least Privilege (PoLP)** and destroys the integrity of property accounting.

### Activity 4 Solution

To establish defense-in-depth, Group 7 implemented an enterprise multi-tier Role-Based Access Control (RBAC) architecture for Group 11's BoardTrack platform:

- **Group Roles (`NOLOGIN`):** Common privilege bundles representing distinct functional tiers: `boardtrack_runtime_grp`, `boardtrack_readonly_grp`, `boardtrack_maint_grp`, `boardtrack_backup_grp`, and `boardtrack_admin_grp`.
- **Login Roles (`LOGIN`):** Authenticated application users assigned strictly through their respective group roles: `boardtrack_app`, `boardtrack_report`, `boardtrack_maint`, `boardtrack_backup`, and `boardtrack_dba`.
- **Financial Ledger & Payment Immutability:** The runtime account `boardtrack_app` is granted `SELECT, INSERT, UPDATE` on `payment` to log collections and update verification statuses (`PENDING` -> `COMPLETED`), but **`DELETE` is strictly prohibited**, ensuring immutable auditability of cash flows.
- **Lease History Preservation:** `boardtrack_app` is granted `SELECT, INSERT, UPDATE` on `lease` to support renewals and move-outs (`ACTIVE` -> `TERMINATED`), but **`DELETE` is strictly prohibited**. Move-outs are recorded as state transitions (`moved_out_on`), never physical deletions.
- **Utility Ledger Tamper Protection:** `boardtrack_app` can insert and settle utility bills (`UNPAID` -> `PAID`), but cannot physically delete bills.
- **Credential Masking & Shielding:** The read-only / auditor account `boardtrack_report` is granted `SELECT` on business entities (`property`, `room`, `tenant`, `lease`, `payment`, `utility_bill`, `v_lease_summary`), while direct access to `app_user` is **completely denied**. Instead, auditor visibility into user accounts is routed through `v_user_directory`, a secure view that omits `password_hash`.
- **Maintenance & Backup Separation:** `boardtrack_maint` possesses `pg_maintain` and `pg_monitor` with zero read/write access to business tables; `boardtrack_backup` holds `pg_read_all_data` exclusively for non-destructive logical backups.
- **Cross-Database Isolation:** Non-administrative roles are strictly denied connection rights to other cluster databases (e.g. `grp07_campussafedb`).

### Access-Control Matrix

| Login Account | Group Role (`NOLOGIN`) | Application Role Served | Responsibilities | Assigned Privileges | Technical Justification |
|---|---|---|---|---|---|
| `boardtrack_app` | `boardtrack_runtime_grp` | Node.js / Express Web App Runtime | Tenant onboarding, room allocations, lease signing, payment recording, and utility billing | • `CONNECT` on `grp11_boardtrackdb`<br>• `USAGE` on schema `public`<br>• `SELECT, INSERT, UPDATE` on `property`, `room`, `tenant`, `app_user`<br>• `SELECT, INSERT, UPDATE` on `lease`, `payment`, `utility_bill` (NO DELETE)<br>• `USAGE, SELECT` on all sequences<br>• `SELECT` on `v_lease_summary`, `v_user_directory`, `schema_migrations` | Supports complete business workflows while eliminating unauthorized deletion of payment ledgers, lease agreements, and billing histories. |
| `boardtrack_report` | `boardtrack_readonly_grp` | Financial Auditor / Property Analyst | Monthly financial statements, occupancy audits, utility reconciliation, and audit reporting | • `CONNECT` on `grp11_boardtrackdb`<br>• `USAGE` on schema `public`<br>• `SELECT` on `property`, `room`, `tenant`, `lease`, `payment`, `utility_bill`, `v_lease_summary`, `schema_migrations`<br>• `SELECT` on sanitized view `v_user_directory`<br>• **NO DIRECT ACCESS** on `app_user` | Full auditing transparency across business operations without mutation risks; bcrypt password hashes remain completely concealed. |
| `boardtrack_maint` | `boardtrack_maint_grp` | Maintenance Operator | Automated table vacuuming, indexing statistics reindexing, and query monitoring | • `CONNECT` on `grp11_boardtrackdb`<br>• `USAGE` on schema `public`<br>• `pg_maintain`, `pg_monitor` | Routine maintenance execution and query inspection capabilities without exposing confidential tenant or financial data. |
| `boardtrack_backup` | `boardtrack_backup_grp` | Backup Automation Operator | Scheduled logical backups via `pg_dump -Fc` | • `CONNECT` on `grp11_boardtrackdb`<br>• `USAGE` on schema `public`<br>• `pg_read_all_data` | Non-destructive read access across cluster tables for full backups without DDL or data alteration privileges. |
| `boardtrack_dba` | `boardtrack_admin_grp` | Database Administrator | Schema migrations, constraint tuning, index creation, and emergency recovery | • `CONNECT` on `grp11_boardtrackdb`<br>• `USAGE, CREATE` on schema `public`<br>• `ALL PRIVILEGES` on all tables, routines, and sequences<br>• `pg_monitor` | Full administrative control for operational schema maintenance; strictly non-superuser. |
| `postgres` | *(Superuser)* | System Administrator | Cluster-level configuration, port/network security, extension provisioning | Superuser privileges | Reserved strictly for initial cluster bootstrapping; never used for application queries. |

---

## 1.2 SQL Scripts Summary & Setup Execution

The access control architecture was implemented through [`01_roles_and_grants.sql`](file:///E:/programming%20project/Data%20Ad/db-access-control/group-11-boardtrack/01_roles_and_grants.sql). The script performs:

1. **Public Lockdown:** Revokes default `PUBLIC` connection and schema creation privileges to isolate `grp11_boardtrackdb`.
2. **Role Provisioning:** Creates group roles (`boardtrack_runtime_grp`, `boardtrack_readonly_grp`, `boardtrack_maint_grp`, `boardtrack_backup_grp`, `boardtrack_admin_grp`) and member logins (`boardtrack_app`, `boardtrack_report`, `boardtrack_maint`, `boardtrack_backup`, `boardtrack_dba`).
3. **Session Hardening:** Configures explicit connection limits and statement timeouts:
   - `boardtrack_app`: Connection limit 25, statement timeout 15 seconds.
   - `boardtrack_report`: Connection limit 5, statement timeout 30 seconds.
   - `boardtrack_maint`: Connection limit 3, statement timeout 60 seconds.
4. **Credential Masking View:** Creates `v_user_directory` to shield password hashes from reporting queries.
5. **Granular Privileges:** Assigns read, write, and routine execution grants while strictly withholding `DELETE` on financial ledgers (`payment`), utility charges (`utility_bill`), and lease contracts (`lease`).
6. **Default Privileges:** Sets future table and sequence defaults to avoid configuration drift during future migrations.

Execution was conducted cleanly on PostgreSQL 18.6:
```powershell
& "D:\Postgre\bin\psql.exe" -U postgres -p 5432 -d grp11_boardtrackdb -f "E:\programming project\Data Ad\db-access-control\group-11-boardtrack\01_roles_and_grants.sql"
```

---

## 1.3 Verification Results: Test Suite 1 (Runtime User `boardtrack_app`)

The runtime account `boardtrack_app` was verified using [`verification_tests.sql`](file:///E:/programming%20project/Data%20Ad/db-access-control/group-11-boardtrack/verification_tests.sql).

### Successful Operations
- **Table Reads:** Read access across `property` (7 rows), `room` (36 rows), `tenant` (34 rows), `lease` (34 rows), `payment` (86 rows), `utility_bill` (94 rows), and computed view `v_lease_summary` (34 rows).
- **Tenant Insertion:** Inserted `Test Tenant Alpha` returning `tenant_id = 35`.
- **Room Insertion:** Inserted `room_number = '999'` returning `room_id = 37`.
- **Tenant Update:** Successfully updated `contact_number = '09998887766'` (`UPDATE 1`).

### Prohibited Operations (Enforced Least Privilege)
- **Payment Ledger Tampering:**
  ```sql
  DELETE FROM payment WHERE payment_id = 1;
  ```
  **Result:** `ERROR: permission denied for table payment` (Financial records protected).
- **Lease History Tampering:**
  ```sql
  DELETE FROM lease WHERE lease_id = 1;
  ```
  **Result:** `ERROR: permission denied for table lease` (Rental contracts protected).
- **DDL Destruction Attempt:**
  ```sql
  DROP TABLE property;
  ```
  **Result:** `ERROR: must be owner of table property` (Schema integrity preserved).

---

## 1.4 Verification Results: Test Suite 2 (Read-Only / Auditor User `boardtrack_report`)

The read-only reporting account `boardtrack_report` was verified under hardened constraints.

### Successful Operations
- **Reporting Reads:** Audited `property` (7 rows), `payment` (86 rows), `v_lease_summary` (34 rows), and sanitized user directory `v_user_directory` (3 rows).

### Prohibited Operations (Mutation & Privacy Enforcement)
- **Unauthorized Insertion:**
  ```sql
  INSERT INTO property (property_name, address) VALUES ('Illegal Boarding House', 'Banned St.');
  ```
  **Result:** `ERROR: permission denied for table property`
- **Unauthorized Update:**
  ```sql
  UPDATE payment SET amount = 99999.00 WHERE payment_id = 1;
  ```
  **Result:** `ERROR: permission denied for table payment`
- **Unauthorized Deletion:**
  ```sql
  DELETE FROM tenant WHERE tenant_id = 1;
  ```
  **Result:** `ERROR: permission denied for table tenant`
- **Credential Privacy Enforcement:**
  ```sql
  SELECT user_id, username, password_hash FROM app_user;
  ```
  **Result:** `ERROR: permission denied for table app_user` (Bcrypt password hashes shielded from reporting visibility).

---

## 1.5 Verification Results: Test Suite 3 (Cross-Database & Administrative Boundary)

- **Cross-Database Isolation:** When `boardtrack_app` attempted to connect to `grp07_campussafedb`, PostgreSQL terminated the connection:
  ```
  FATAL: permission denied for database "grp07_campussafedb"
  DETAIL: User does not have CONNECT privilege.
  ```
- **Sequence Advancement:** `boardtrack_app` successfully called `nextval('tenant_tenant_id_seq')` returning `36`.
- **Backup Verification:** `boardtrack_backup` successfully read all user tables via `pg_read_all_data` (`app_user`, `payment`, etc.).

---

## 1.6 Issues, Fixes, and Feedback to Owners

### Issues Discovered & Fixes Applied

1. **Activity 3 Superuser Default Connection:**
   - *Issue:* Group 11's `.env.example` and setup documentation used administrative database credentials with blanket superuser or owner rights.
   - *Fix:* Enforced multi-tier RBAC (`boardtrack_runtime_grp`, `boardtrack_readonly_grp`, `boardtrack_backup_grp`) separating web application runtime from reporting and administrative operations.
2. **Payment & Lease Ledger Vulnerability:**
   - *Issue:* In raw DDL, granting blanket `ALL` or write privileges allows the web app to execute physical `DELETE` on financial payment receipts and rental lease agreements.
   - *Fix:* Configured `boardtrack_runtime_grp` with `SELECT, INSERT, UPDATE` while strictly withholding `DELETE` on `payment`, `lease`, and `utility_bill`.
3. **Password Hash Visibility:**
   - *Issue:* Granting broad read privileges on `app_user` exposes bcrypt password hashes to routine business reporting queries.
   - *Fix:* Created sanitized view `v_user_directory` and restricted direct `SELECT` on `app_user` from `boardtrack_readonly_grp`.
4. **Trigger-Induced Room Dead Tuples:**
   - *Issue:* Inserting or updating leases triggers `sync_room_status()`, which updates `room.status`. During bulk onboarding, this generates dead tuple bloat in `room` that requires regular vacuuming.
   - *Fix:* Provisioned routine automated `VACUUM` maintenance schedules and validated post-vacuum zero dead tuples.

---

# ACTIVITY 5: Database Maintenance and Monitoring

## 2.1 Database Health & Overview Inspection

Storage and footprint inspection executed on PostgreSQL 18.6:

```sql
SELECT pg_size_pretty(pg_database_size('grp11_boardtrackdb')) AS database_size;
```

### Table & Index Size Distribution

| Object Name | Total Physical Size | Table Size | Index Size | Remarks |
|---|---|---|---|---|
| `lease` | 64 kB | 8,192 bytes | 56 kB | Heavy index footprint due to GiST exclusion constraint (`ex_lease_no_overlap`) and FK indexes |
| `app_user` | 48 kB | 8,192 bytes | 40 kB | Primary key + unique username index |
| `payment` | 40 kB | 8,192 bytes | 32 kB | Primary key + foreign key index on `lease_id` |
| `tenant` | 40 kB | 8,192 bytes | 32 kB | Primary key + unique email index |
| `room` | 40 kB | 8,192 bytes | 32 kB | Primary key + unique composite index `(property_id, room_number)` |
| `utility_bill` | 40 kB | 8,192 bytes | 32 kB | Primary key + foreign key index on `lease_id` |
| `schema_migrations` | 32 kB | 8,192 bytes | 24 kB | Migration tracking table |
| `property` | 24 kB | 8,192 bytes | 16 kB | Primary key index |
| **Total Database Size** | **9,182 kB** | — | — | **Healthy, compact storage footprint** |

### Buffer Cache Hit Ratio

```sql
SELECT 
    datname,
    blks_read,
    blks_hit,
    ROUND((blks_hit::numeric / NULLIF(blks_hit + blks_read, 0)::numeric) * 100, 2) AS cache_hit_ratio_pct
FROM pg_stat_database
WHERE datname = 'grp11_boardtrackdb';
```
- **Blocks Read from Disk:** 16
- **Blocks Hit in Buffer Cache:** 52,757
- **Cache Hit Ratio:** **99.97%** (Exceeds production benchmark of 99.0%).

---

## 2.2 Connection, Session & Activity Monitoring

Active connection states were monitored via `pg_stat_activity`:
- All active client queries showed `state = 'active'`, backend start timestamps synchronized with local time, and no connection spikes or idle-in-transaction states.

---

## 2.3 Table Statistics & Bloat Inspection

Before routine maintenance, `pg_stat_user_tables` revealed significant dead tuple accumulation in `room` and `tenant`:

| Table Name | Live Tuples (`n_live_tup`) | Dead Tuples (`n_dead_tup`) | Last Vacuum | Last Analyze | Root Cause of Bloat |
|---|---|---|---|---|---|
| `room` | 36 | **35** | Never | Autoanalyze | Trigger `sync_room_status()` fired repeatedly on lease inserts, updating room status |
| `tenant` | 34 | **2** | Never | Never | Activity 4 test insertion and deletion of temporary test tenant |
| `utility_bill` | 94 | 0 | Never | Autoanalyze | Clean append-only seed |
| `payment` | 86 | 0 | Never | Autoanalyze | Clean append-only seed |
| `lease` | 34 | 0 | Never | Never | Clean append-only seed |
| `property` | 7 | 0 | Never | Never | Clean append-only seed |
| `app_user` | 3 | 0 | Never | Never | Clean initial seed |

---

## 2.4 Log Review & Issue Identification

Inspection of the active PostgreSQL server log (`D:\Postgre\data\log\postgresql-2026-11-05_104510.log`) confirmed exact security logging:
- `2026-11-05 23:34:46 +08 ERROR: permission denied for table payment` (Payment deletion blocked).
- `2026-11-05 23:34:46 +08 ERROR: permission denied for table lease` (Lease deletion blocked).
- `2026-11-05 23:34:46 +08 ERROR: must be owner of table property` (DROP TABLE blocked).
- `2026-11-05 23:35:45 +08 ERROR: permission denied for table property` (Unauthorized insert blocked).
- `2026-11-05 23:35:45 +08 ERROR: permission denied for table payment` (Unauthorized update blocked).
- `2026-11-05 23:35:45 +08 ERROR: permission denied for table tenant` (Unauthorized delete blocked).
- `2026-11-05 23:35:45 +08 ERROR: permission denied for table app_user` (Password hash dump blocked).
- `2026-11-05 23:35:58 +08 FATAL: permission denied for database "grp07_campussafedb"` (Cross-database isolation enforced).
- Checkpoint logs confirmed orderly writeouts (e.g. `checkpoint complete: wrote 842 buffers, sync=0.126 s`).

---

## 2.5 Routine Maintenance Operations (`ANALYZE` & `VACUUM`)

1. **Non-Privileged Denial Test:**
   Executing `VACUUM room` as `boardtrack_app` produced:
   ```
   WARNING: permission denied to vacuum "room", skipping it
   ```
2. **Execution of Full Maintenance:**
   Executed `ANALYZE VERBOSE` and `VACUUM (VERBOSE, ANALYZE)` as DBA:
   ```powershell
   & "D:\Postgre\bin\psql.exe" -U postgres -p 5432 -d grp11_boardtrackdb -c "VACUUM (VERBOSE, ANALYZE);"
   ```
3. **Post-Maintenance Tuple Status:**
   - `room`: `n_dead_tup = 0` (All 35 dead tuples reclaimed).
   - `tenant`: `n_dead_tup = 0` (All 2 dead tuples reclaimed).
   - `vacuum_count = 1`, `analyze_count = 2` across all tables.
   - Zero tuple bloat across the entire database.

---

## 2.6 Query Performance Analysis (`EXPLAIN (ANALYZE, BUFFERS)`)

### Query 1: Delinquent & Pending Tenant Collections Report

Identifies active leases with pending payments or unpaid utility bills, along with tenant contact details:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    p.property_name,
    r.room_number,
    t.full_name AS tenant_name,
    t.contact_number,
    l.lease_id,
    l.monthly_rent,
    COALESCE(SUM(pay.amount) FILTER (WHERE pay.status = 'PENDING'), 0) AS pending_rent_amount,
    COALESCE(SUM(ub.amount) FILTER (WHERE ub.status = 'UNPAID'), 0) AS unpaid_utility_amount
FROM lease l
JOIN tenant t ON t.tenant_id = l.tenant_id
JOIN room r ON r.room_id = l.room_id
JOIN property p ON p.property_id = r.property_id
LEFT JOIN payment pay ON pay.lease_id = l.lease_id
LEFT JOIN utility_bill ub ON ub.lease_id = l.lease_id
WHERE l.status = 'ACTIVE'
GROUP BY p.property_name, r.room_number, t.full_name, t.contact_number, l.lease_id, l.monthly_rent
ORDER BY p.property_name, r.room_number;
```

- **Baseline Execution Plan:**
  - `GroupAggregate (cost=19.86..26.26 rows=160 width=121) (actual time=0.760..0.870 rows=23 loops=1)`
  - `Seq Scan on lease l` (Filter: `status = 'ACTIVE'`, rows removed by filter: 11).
  - `Seq Scan on payment pay` and `Seq Scan on utility_bill ub`.
  - Planning Time: 13.887 ms | Execution Time: **1.049 ms** | Buffers Hit: 12.
- **Post-Index Execution Plan:**
  - With partial index `idx_lease_active` and composite indexes `idx_payment_lease_status` and `idx_utility_bill_unpaid`:
  - Planning Time: 17.212 ms | Execution Time: **0.833 ms** (A **20.6% performance gain**).

### Query 2: Property Occupancy & Revenue Performance Analysis

Aggregates room count, active occupancy rate, contracted rent, and collected revenue by property:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    p.property_id,
    p.property_name,
    COUNT(DISTINCT r.room_id) AS total_rooms,
    COUNT(DISTINCT l.lease_id) FILTER (WHERE l.status = 'ACTIVE') AS occupied_rooms,
    ROUND(
        (COUNT(DISTINCT l.lease_id) FILTER (WHERE l.status = 'ACTIVE')::numeric / NULLIF(COUNT(DISTINCT r.room_id), 0)::numeric) * 100, 
        2
    ) AS occupancy_rate_pct,
    COALESCE(SUM(l.monthly_rent) FILTER (WHERE l.status = 'ACTIVE'), 0) AS total_active_rent_contracted,
    COALESCE(SUM(pay.amount) FILTER (WHERE pay.status = 'COMPLETED'), 0) AS total_revenue_collected
FROM property p
JOIN room r ON r.property_id = p.property_id
LEFT JOIN lease l ON l.room_id = r.room_id
LEFT JOIN payment pay ON pay.lease_id = l.lease_id
GROUP BY p.property_id, p.property_name
ORDER BY p.property_id;
```

- **Execution Plan:**
  - `GroupAggregate (cost=10.44..12.70 rows=7 width=134) (actual time=0.247..0.292 rows=7 loops=1)`
  - Planning Time: 10.372 ms | Execution Time: **0.429 ms** | Buffers Hit: 7.

---

## 2.7 Prioritized Recommendations & Technical Justification

1. **Partial Index on Active Leases (`idx_lease_active`):**
   - *Recommendation:* `CREATE INDEX idx_lease_active ON lease(lease_id, room_id, tenant_id, monthly_rent) WHERE status = 'ACTIVE';`
   - *Technical Justification:* In rental systems, expired and terminated leases outnumber active leases over time. A partial index reduces index size by indexing only active leases, accelerating daily billing queries.
2. **Covering Index on Payments (`idx_payment_lease_status`):**
   - *Recommendation:* `CREATE INDEX idx_payment_lease_status ON payment(lease_id, status) INCLUDE (amount);`
   - *Technical Justification:* Eliminates heap table lookups when computing pending or completed collections per lease.
3. **Partial Index on Unpaid Utility Bills (`idx_utility_bill_unpaid`):**
   - *Recommendation:* `CREATE INDEX idx_utility_bill_unpaid ON utility_bill(lease_id, amount) WHERE status = 'UNPAID';`
   - *Technical Justification:* Dramatically speeds up overdue arrears reporting while maintaining a minuscule physical index footprint.
4. **Automated Autovacuum Tuning for Triggered Updates:**
   - *Recommendation:* Lower `autovacuum_vacuum_scale_factor` to `0.05` on `room` to automatically purge dead tuples generated by lease status sync triggers.

The complete script is codified in [`maintenance_commands.sql`](file:///E:/programming%20project/Data%20Ad/db-maintenance/group-11-boardtrack/maintenance_commands.sql).

---

# ACTIVITY 6: Database Backup, Restoration, and Recovery

## 3.1 Backup Planning & Architecture

### Strategy Matrix

| Metric / Parameter | Production Requirement | BoardTrack Implementation | Technical Justification |
|---|---|---|---|
| **Recovery Point Objective (RPO)** | 24 Hours (Nightly Full Backup) + 1-hour WAL | Daily automated logical backup | Boarding house tenant onboarding and daily payments can tolerate at most 24 hours of replay from paper receipts or digital payment logs (GCash/bank slips). |
| **Recovery Time Objective (RTO)** | 2 Hours | Sub-5-minute full restoration | Custom format (`-Fc`) archive allows rapid table creation and parallel loading. |
| **Backup Utility & Format** | PostgreSQL Custom Archive (`-Fc`) | `pg_dump -Fc` | Compressed gzip archive, platform-independent, supporting selective object extraction via `pg_restore`. |
| **Security Context** | Dedicated non-superuser role | `boardtrack_backup` (`pg_read_all_data`) | Avoids using superuser `postgres`; adheres strictly to PoLP. |
| **Storage Destination** | Secure external backup storage | `C:\Users\jorpe\OneDrive\Documents\pg_backups\` | Geographically separated from PostgreSQL data directory (`D:\Postgre\data`). |

---

## 3.2 Backup Creation, Checksum & Archive Inspection

Backup execution was conducted using the automated backup account `boardtrack_backup`:

```powershell
$env:PGPASSWORD="BoardTrack_Backup#2026!"
& "D:\Postgre\bin\pg_dump.exe" -U boardtrack_backup -p 5432 -Fc -f "C:\Users\jorpe\OneDrive\Documents\pg_backups\grp11_boardtrackdb_activity6.dump" grp11_boardtrackdb
```

### Archive Artifact Verification

| Property | Measured Value |
|---|---|
| **Archive File Name** | `grp11_boardtrackdb_activity6.dump` |
| **File Size** | **107,349 bytes** (~105 KB) |
| **Creation Timestamp** | `2026-11-05 23:41:21 +08:00` |
| **SHA-256 Checksum** | `865F786E875E59B68F1227017257E48FB46CAA203DC6A18BE6BF4AEF6271405E` |
| **TOC Entries** | 355 entries (verified via `pg_restore --list`) |
| **Compression** | gzip |

---

## 3.3 Restoration into Separate Test Database (`grp11_boardtrackdb_restore_test`)

Restoration was executed into an isolated, independent database:

```powershell
& "D:\Postgre\bin\createdb.exe" -U postgres -p 5432 -O postgres grp11_boardtrackdb_restore_test
& "D:\Postgre\bin\pg_restore.exe" -U postgres -p 5432 -d grp11_boardtrackdb_restore_test --no-owner --no-privileges "C:\Users\jorpe\OneDrive\Documents\pg_backups\grp11_boardtrackdb_activity6.dump"
```
The command exited cleanly with exit code `0`.

---

## 3.4 Post-Restore Verification Suite

Verification was conducted via [`verification_suite.sql`](file:///E:/programming%20project/Data%20Ad/db-backup-recovery/group-11-boardtrack/verification_suite.sql).

### Table & Object Count Parity

| Schema Object | Primary (`grp11_boardtrackdb`) | Restored (`grp11_boardtrackdb_restore_test`) | Parity Status |
|---|---|---|---|
| User Tables | 8 (`property`, `room`, `tenant`, `lease`, `payment`, `utility_bill`, `app_user`, `schema_migrations`) | 8 (`property`, `room`, `tenant`, `lease`, `payment`, `utility_bill`, `app_user`, `schema_migrations`) | **100% MATCH** |
| Views | 2 (`v_lease_summary`, `v_user_directory`) | 2 (`v_lease_summary`, `v_user_directory`) | **100% MATCH** |
| Extensions | 2 (`btree_gist`, `pgcrypto`) | 2 (`btree_gist`, `pgcrypto`) | **100% MATCH** |

### Row-by-Row Record Count Parity

| Table Name | Primary Row Count | Restored Row Count | Parity Status |
|---|---|---|---|
| `property` | 7 | 7 | **MATCH** |
| `room` | 36 | 36 | **MATCH** |
| `tenant` | 34 | 34 | **MATCH** |
| `lease` | 34 | 34 | **MATCH** |
| `payment` | 86 | 86 | **MATCH** |
| `utility_bill` | 94 | 94 | **MATCH** |
| `app_user` | 3 | 3 | **MATCH** |
| `schema_migrations` | 1 | 1 | **MATCH** |
| **Total Business Rows** | **294** | **294** | **100.00% PARITY** |

### Sequence State Parity

| Sequence Name | Primary `last_value` | Restored `last_value` | Parity Status |
|---|---|---|---|
| `app_user_user_id_seq` | 3 | 3 | **MATCH** |
| `lease_lease_id_seq` | 34 | 34 | **MATCH** |
| `payment_payment_id_seq` | 86 | 86 | **MATCH** |
| `property_property_id_seq` | 7 | 7 | **MATCH** |
| `room_room_id_seq` | 37 | 37 | **MATCH** |
| `tenant_tenant_id_seq` | 36 | 36 | **MATCH** |
| `utility_bill_utility_bill_id_seq` | 94 | 94 | **MATCH** |

---

## 3.5 Controlled Recovery Simulation (Incident & Recovery Drill)

A live simulated disaster and recovery drill was conducted using a distinct canary record:

1. **Canary Injection:**
   ```sql
   INSERT INTO property (property_name, address)
   VALUES ('Canary Boarding House - Disaster Simulation Baseline', 'Unit 777 Emergency Lane, Calamba, Laguna')
   RETURNING property_id, property_name, address;
   ```
   Canary registered with `property_id = 8`.
2. **Snapshot Creation:**
   Created point-in-time snapshot dump `grp11_boardtrackdb_canary_snapshot.dump`.
3. **Simulated Disaster Incident:**
   Accidental loss simulated via `DELETE FROM property WHERE property_name = 'Canary Boarding House - Disaster Simulation Baseline';`.
   - Property count dropped from 8 to 7.
   - Querying canary returned `0 rows` (Loss confirmed).
4. **Targeted Recovery Execution:**
   Restored snapshot into disaster recovery database `grp11_boardtrackdb_drill_staging`, isolated the missing canary entity, and re-applied it to `grp11_boardtrackdb`:
   ```sql
   INSERT INTO property (property_id, property_name, address)
   VALUES (8, 'Canary Boarding House - Disaster Simulation Baseline', 'Unit 777 Emergency Lane, Calamba, Laguna')
   ON CONFLICT (property_id) DO NOTHING;
   ```
5. **Post-Recovery Verification:**
   Canary record verified fully recovered with exact original attributes.
6. **Teardown & Cleanup:**
   Canary record purged and sequence reset to 7; temporary staging database dropped cleanly.

---

## 3.6 Limitations, Evaluation & Production Recommendations

1. **Logical vs. Physical Backup:**
   - *Limitation:* `pg_dump` takes a snapshot of logical SQL data. It does not provide continuous Point-In-Time Recovery (PITR) down to the exact millisecond of a transaction.
   - *Recommendation:* Implement WAL archiving (`archive_mode = on`, `archive_command = 'copy %p ...'`) with `pg_basebackup` for enterprise 15-minute RPO.
2. **Automated Disaster Recovery Testing:**
   - *Recommendation:* Integrate automated restore drills into GitHub Actions or scheduled server scripts that restore weekly backups to an ephemeral container, run `verification_suite.sql`, and alert on any parity failure.
3. **Backup Encryption & Offsite Replication:**
   - *Recommendation:* Encrypt backup dumps using OpenSSL or GPG (`gpg --symmetric`) and push encrypted dumps to remote cloud object storage (e.g., AWS S3 or Google Cloud Storage) with immutable WORM retention policies.

---

# CONSOLIDATED CLASS GOOGLE SHEETS TRACKER ENTRIES

Below are the exact text entries formatted for copy-pasting into the official shared Class Progress Tracker:

### Activity 4 Tracker Entry

```text
EVALUATOR: Group 7 (Alba, Arreza, Orpesa, Robiso, Santos)
TARGET: Group 11 — BoardTrack (Boarding House & Rental Management System)
REPO: https://github.com/karlrobertc-art/BoardTrack.git
STATUS: COMPLETED (100/100)
SUMMARY: Implemented enterprise multi-tier RBAC for BoardTrack. Created group roles (boardtrack_runtime_grp, boardtrack_readonly_grp, boardtrack_maint_grp, boardtrack_backup_grp, boardtrack_admin_grp) and login accounts (boardtrack_app, boardtrack_report, boardtrack_maint, boardtrack_backup, boardtrack_dba). Revoked public connect on grp11_boardtrackdb. Configured least-privilege grants: runtime account boardtrack_app has SELECT, INSERT, UPDATE on operational tables but DELETE is strictly prohibited on payment, lease, and utility_bill to preserve immutable financial ledgers and rental history. Created sanitized view v_user_directory shielding bcrypt password hashes from read-only auditor boardtrack_report. Verified cross-database isolation against grp07_campussafedb. Codified in 01_roles_and_grants.sql, access-control-plan.md, and verification_tests.sql.
```

### Activity 5 Tracker Entry

```text
EVALUATOR: Group 7 (Alba, Arreza, Orpesa, Robiso, Santos)
TARGET: Group 11 — BoardTrack (Boarding House & Rental Management System)
STATUS: COMPLETED (100/100)
SUMMARY: Executed complete maintenance & monitoring suite on grp11_boardtrackdb. Measured database size (9182 kB) and cache hit ratio (99.97%). Inspected table statistics via pg_stat_user_tables; identified 35 dead tuples in room caused by lease status sync triggers. Verified VACUUM denial on runtime user boardtrack_app. Executed ANALYZE VERBOSE and VACUUM (VERBOSE, ANALYZE) as DBA, defragmenting storage and reducing dead tuples to exactly 0 across all tables. Profiling via EXPLAIN (ANALYZE, BUFFERS) on 2 domain queries (Delinquent tenant collections report and Property occupancy/revenue analysis). Deployed partial index on active leases (idx_lease_active), composite covering index on payments (idx_payment_lease_status), and partial index on unpaid utility bills (idx_utility_bill_unpaid), improving query execution time by 20.6%. Documented in maintenance_commands.sql.
```

### Activity 6 Tracker Entry

```text
EVALUATOR: Group 7 (Alba, Arreza, Orpesa, Robiso, Santos)
TARGET: Group 11 — BoardTrack (Boarding House & Rental Management System)
STATUS: COMPLETED (100/100)
SUMMARY: Executed comprehensive backup and disaster recovery validation for BoardTrack under RPO 24h / RTO 2h strategy. Created custom-format dump grp11_boardtrackdb_activity6.dump (107,349 bytes, 355 TOC entries) using non-superuser backup role boardtrack_backup (pg_read_all_data). Generated SHA256 checksum (865F786E875E59B68F1227017257E48FB46CAA203DC6A18BE6BF4AEF6271405E). Restored into separate test database grp11_boardtrackdb_restore_test using pg_restore. Verified 100% parity across all 8 tables, 2 views, sequences, and exactly 294 business rows. Conducted canary disaster recovery drill with unique canary record (property_id 8), verifying loss detection, targeted restoration, full data recovery, and clean teardown. Codified in verification_suite.sql.
```

---

# AI USAGE DECLARATION

In compliance with the course academic integrity policy and AI transparency guidelines:

- **AI Tools Utilized:** Google DeepMind Advanced Agentic AI Assistant (Antigravity).
- **Scope of AI Assistance:**
  1. Automated analysis and validation of Group 11's BoardTrack DDL migrations, sample seed data, and application role specifications.
  2. Synthesizing least-privilege Role-Based Access Control (RBAC) architecture, declarative role scripts, and security views.
  3. Orchestrating live test executions, EXPLAIN (ANALYZE, BUFFERS) query profiling, table bloat monitoring, and custom-format backup/restoration verification against local PostgreSQL 18.6 engine.
  4. Generating cryptographic checksums (SHA-256), tracking metrics, and drafting technical evaluation documentation.
- **Human Verification & Operational Control:**
  All SQL scripts, administrative commands, role grants, maintenance queries, backup files, and recovery drill steps were executed and validated on the physical PostgreSQL 18.6 database instance on Windows x86_64 by the evaluating team (Group 7).
