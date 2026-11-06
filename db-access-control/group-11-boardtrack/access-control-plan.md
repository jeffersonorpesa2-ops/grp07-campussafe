# Activity 4: Access Control Plan — Group 11 (BoardTrack Evaluation)

**Evaluating Group:** Group 7 (Alba, Arreza, Orpesa, Robiso, Santos)  
**Target Group:** Group 11 (Barcarse, Adrian; Cataluña, Zyruz Gabriel; Camu, Edgar; Policarpio, Kurt; Crucillo, Karl Robert)  
**Target Project:** BoardTrack — Boarding House & Rental Management System  
**Repository:** [https://github.com/karlrobertc-art/BoardTrack.git](https://github.com/karlrobertc-art/BoardTrack.git)  
**Database:** `grp11_boardtrackdb` (PostgreSQL 18.6 on x86_64 Windows)  
**Schema:** `public`  

---

## 1. Access-Control Architecture & PoLP Design

The **BoardTrack Boarding House & Rental Management System** manages boarding house properties, rentable rooms, tenant profiles, rental lease contracts (enforced with GiST exclusion constraints preventing temporal overlaps), financial rent payments, and utility bill tracking. In baseline development phases (Activity 3), applications typically connect using the PostgreSQL superuser (`postgres`) or an unconstrained database owner with blanket privileges across all schema tables. In a property rental management system, this design introduces catastrophic risks:

- **Financial Rent Ledger Tampering:** Malicious tenants or compromised API endpoints could alter payment amounts, mark delinquent balances as settled, or delete payment receipts, corrupting monthly revenue auditing and owner distributions.
- **Rental Lease History Destruction:** Unrestricted `DELETE` access on `lease` would allow deleting historical tenant agreements, corrupting move-out audit trails and breaking historical occupancy reports.
- **Utility Charge Manipulation:** Utility charges (electricity, water, internet) could be modified or deleted, resulting in unrecovered utility costs for the property owner.
- **Credential Exposure:** Direct read access to the `app_user` table exposes bcrypt password hashes to unnecessary reporting queries, enabling offline hash-cracking attempts.
- **Accidental Schema Annihilation:** An application account with DDL permissions could execute `DROP TABLE property` or `TRUNCATE TABLE payment`, causing fatal system downtime and data loss.

To enforce the **Principle of Least Privilege (PoLP)** and protect transactional integrity, Group 7 designed and deployed a comprehensive Role-Based Access Control (RBAC) architecture:

- **Group Roles (`NOLOGIN`):** Common privilege bundles representing distinct functional tiers: `boardtrack_runtime_grp`, `boardtrack_readonly_grp`, `boardtrack_maint_grp`, `boardtrack_backup_grp`, and `boardtrack_admin_grp`.
- **Login Roles (`LOGIN`):** Authenticated application users assigned strictly through their respective group roles: `boardtrack_app`, `boardtrack_report`, `boardtrack_maint`, `boardtrack_backup`, and `boardtrack_dba`.
- **Financial Ledger & Payment Immutability:** The runtime account `boardtrack_app` is granted `SELECT, INSERT, UPDATE` on `payment` to log collections and update verification statuses (`PENDING` -> `COMPLETED`), but **`DELETE` is strictly prohibited**, ensuring immutable auditability of cash flows.
- **Lease History Preservation:** `boardtrack_app` is granted `SELECT, INSERT, UPDATE` on `lease` to support renewals and move-outs (`ACTIVE` -> `TERMINATED`), but **`DELETE` is strictly prohibited**. Move-outs are recorded as state transitions (`moved_out_on`), never physical deletions.
- **Utility Ledger Tamper Protection:** `boardtrack_app` can insert and settle utility bills (`UNPAID` -> `PAID`), but cannot physically delete bills.
- **Credential Masking & Shielding:** The read-only / auditor account `boardtrack_report` is granted `SELECT` on business entities (`property`, `room`, `tenant`, `lease`, `payment`, `utility_bill`, `v_lease_summary`), while direct access to `app_user` is **completely denied**. Instead, auditor visibility into user accounts is routed through `v_user_directory`, a secure view that omits `password_hash`.
- **Maintenance & Backup Separation:** `boardtrack_maint` possesses `pg_maintain` and `pg_monitor` with zero read/write access to business tables; `boardtrack_backup` holds `pg_read_all_data` exclusively for non-destructive logical backups.
- **Cross-Database Isolation:** Non-administrative roles are strictly denied connection rights to other cluster databases (e.g. `grp07_campussafedb`).

---

## 2. Access Control Matrix

| Login Account | Group Role (`NOLOGIN`) | Application Role Served | Responsibilities | Assigned Privileges | Technical Justification |
|---|---|---|---|---|---|
| `boardtrack_app` | `boardtrack_runtime_grp` | Node.js / Express Web App Runtime | Tenant onboarding, room allocations, lease signing, payment recording, and utility billing | • `CONNECT` on `grp11_boardtrackdb`<br>• `USAGE` on schema `public`<br>• `SELECT, INSERT, UPDATE` on `property`, `room`, `tenant`, `app_user`<br>• `SELECT, INSERT, UPDATE` on `lease`, `payment`, `utility_bill` (NO DELETE)<br>• `USAGE, SELECT` on all sequences<br>• `SELECT` on `v_lease_summary`, `v_user_directory`, `schema_migrations` | Supports complete business workflows while eliminating unauthorized deletion of payment ledgers, lease agreements, and billing histories. |
| `boardtrack_report` | `boardtrack_readonly_grp` | Financial Auditor / Property Analyst | Monthly financial statements, occupancy audits, utility reconciliation, and audit reporting | • `CONNECT` on `grp11_boardtrackdb`<br>• `USAGE` on schema `public`<br>• `SELECT` on `property`, `room`, `tenant`, `lease`, `payment`, `utility_bill`, `v_lease_summary`, `schema_migrations`<br>• `SELECT` on sanitized view `v_user_directory`<br>• **NO DIRECT ACCESS** on `app_user` | Full auditing transparency across business operations without mutation risks; bcrypt password hashes remain completely concealed. |
| `boardtrack_maint` | `boardtrack_maint_grp` | Maintenance Operator | Automated table vacuuming, indexing statistics reindexing, and query monitoring | • `CONNECT` on `grp11_boardtrackdb`<br>• `USAGE` on schema `public`<br>• `pg_maintain`, `pg_monitor` | Routine maintenance execution and query inspection capabilities without exposing confidential tenant or financial data. |
| `boardtrack_backup` | `boardtrack_backup_grp` | Backup Automation Operator | Scheduled logical backups via `pg_dump -Fc` | • `CONNECT` on `grp11_boardtrackdb`<br>• `USAGE` on schema `public`<br>• `pg_read_all_data` | Non-destructive read access across cluster tables for full backups without DDL or data alteration privileges. |
| `boardtrack_dba` | `boardtrack_admin_grp` | Database Administrator | Schema migrations, constraint tuning, index creation, and emergency recovery | • `CONNECT` on `grp11_boardtrackdb`<br>• `USAGE, CREATE` on schema `public`<br>• `ALL PRIVILEGES` on all tables, routines, and sequences<br>• `pg_monitor` | Full administrative control for operational schema maintenance; strictly non-superuser. |
| `postgres` | *(Superuser)* | System Administrator | Cluster-level configuration, port/network security, extension provisioning | Superuser privileges | Reserved strictly for initial cluster bootstrapping; never used for application queries. |

---

## 3. SQL Implementation Scripts

The access control architecture is fully codified in two dedicated SQL files:
1. [`01_roles_and_grants.sql`](file:///E:/programming%20project/Data%20Ad/db-access-control/group-11-boardtrack/01_roles_and_grants.sql): Declarative role provisioning, privilege grants, sanitized view creation, and default privilege configurations.
2. [`verification_tests.sql`](file:///E:/programming%20project/Data%20Ad/db-access-control/group-11-boardtrack/verification_tests.sql): Rigorous multi-tier verification test suite executed across runtime, auditor, backup, and boundary levels.

---

## 4. Verification Test Results Summary

| Test ID | User Context | Target Operation | Expected Result | Actual Result | Verification Status |
|---|---|---|---|---|---|
| **T1.1** | `boardtrack_app` | `SELECT` on operational tables and `v_lease_summary` | Success (Full read) | Success (Returned 7 properties, 36 rooms, 34 tenants, 34 leases, 86 payments, 94 utility bills) | **PASS** |
| **T1.2** | `boardtrack_app` | `INSERT` into `tenant` and `room` | Success (Insert permitted) | Success (`tenant_id` 35, `room_id` 37 created) | **PASS** |
| **T1.3** | `boardtrack_app` | `UPDATE` on `tenant` contact number | Success (Update permitted) | Success (`UPDATE 1`) | **PASS** |
| **T1.4** | `boardtrack_app` | `DELETE` from `payment` (financial ledger) | Denied (`permission denied for table payment`) | Error: `permission denied for table payment` | **PASS** |
| **T1.5** | `boardtrack_app` | `DELETE` from `lease` (contract history) | Denied (`permission denied for table lease`) | Error: `permission denied for table lease` | **PASS** |
| **T1.6** | `boardtrack_app` | `DROP TABLE property` (DDL lockdown) | Denied (`must be owner of table property`) | Error: `must be owner of table property` | **PASS** |
| **T2.1** | `boardtrack_report` | `SELECT` on business tables, views, and `v_user_directory` | Success (Read permitted) | Success (Full reporting read) | **PASS** |
| **T2.2** | `boardtrack_report` | `INSERT` into `property` | Denied (`permission denied for table property`) | Error: `permission denied for table property` | **PASS** |
| **T2.3** | `boardtrack_report` | `UPDATE` on `payment` amount | Denied (`permission denied for table payment`) | Error: `permission denied for table payment` | **PASS** |
| **T2.4** | `boardtrack_report` | `DELETE` from `tenant` | Denied (`permission denied for table tenant`) | Error: `permission denied for table tenant` | **PASS** |
| **T2.5** | `boardtrack_report` | `SELECT password_hash FROM app_user` | Denied (`permission denied for table app_user`) | Error: `permission denied for table app_user` | **PASS** |
| **T3.1** | `boardtrack_app` | `CONNECT` to `grp07_campussafedb` | Denied (`permission denied for database`) | Fatal: `permission denied for database "grp07_campussafedb"` | **PASS** |
| **T3.2** | `boardtrack_app` | Advance sequence `tenant_tenant_id_seq` | Success (Returns next value) | Success (Returned value 36) | **PASS** |
| **T3.3** | `boardtrack_backup` | Read all tables via `pg_read_all_data` | Success (Unrestricted read for dump) | Success (Read `app_user` and `payment`) | **PASS** |
