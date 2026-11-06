# Activity 4: Access Control Plan — Group HabalGo (HabalGo Evaluation)

**Evaluating Group:** Group 7 (Alba, Arreza, Orpesa, Robiso, Santos)  
**Target Group:** HabalGo Team (`https://github.com/jeanaroyo/HabalGo`)  
**Target Project:** HabalGo — Ride and Booking Management System  
**Database:** `grp00_habalgodb` (PostgreSQL 18.6)  
**Schema:** `habalgo`  

---

## 1. Access-Control Architecture & PoLP Design

HabalGo is a ride-hailing and booking management platform managing passenger bookings, driver assignments, vehicle fleet records, location tracking, fare payments, and customer rating feedback. In default or monolithic setups where applications connect using the superuser `postgres` or an unrestricted account with `ALL PRIVILEGES` across all tables:
- Any software vulnerability or exposed API endpoint could allow drivers or riders to alter collected fare amounts or mark payments completed before settlement.
- Booking audit trails could be purged to conceal cancelled or disputed trips.
- Driver profiles or active vehicle registrations could be deleted, causing fleet disconnections.
- Entire tables could be dropped, leading to total operational outage.

To enforce the **Principle of Least Privilege (PoLP)** and preserve audit integrity, we implemented a three-tier Role-Based Access Control (RBAC) architecture:

- **Group Roles (`NOLOGIN`):** `habalgo_runtime_grp`, `habalgo_readonly_grp`, `habalgo_backup_grp`.
- **Login Accounts (`LOGIN`):** `habalgo_app` (Application Runtime), `habalgo_report` (Auditor / Reporting Inspector), `habalgo_backup` (Backup Operator).
- **Financial Ledger Immutability:** The runtime account `habalgo_app` is granted `SELECT, INSERT` on `habalgo.payment`. `UPDATE` and `DELETE` privileges are **strictly revoked**, ensuring completed payments cannot be tampered with.
- **Booking Audit Trail Protection:** `habalgo_app` can advance booking statuses (`SELECT, INSERT, UPDATE` on `habalgo.booking`), but `DELETE` is **strictly denied** to preserve historical trip audit trails.
- **Fleet Protection:** `habalgo_app` can register and update `driver`, `vehicle`, and `driver_vehicle` assignments, but `DELETE` is prohibited through runtime.
- **Auditor Read-Only Isolation:** `habalgo_report` is granted read-only `SELECT` on all operational tables in `habalgo` for billing reconciliation and performance monitoring, while completely denying all DML write operations (`INSERT`, `UPDATE`, `DELETE`).
- **Backup Isolation:** The dedicated backup operator `habalgo_backup` is authorized for `pg_dump` logical dumps with read-only permissions across all tables and sequences, with DML and DDL privileges completely denied.
- **Administrative Boundary:** Non-administrative accounts are revoked from creating databases or accessing other group databases on the cluster (`REVOKE CONNECT ON DATABASE grp07_campussafedb FROM PUBLIC;`).

---

## 2. Access Control Matrix

| Login Account | Group Role (`NOLOGIN`) | Application Role Served | Responsibilities | Assigned Privileges | Technical Justification |
|---|---|---|---|---|---|
| `habalgo_app` | `habalgo_runtime_grp` | PHP Runtime (api.php) | Handles customer management, ride booking dispatch, status transitions, driver-vehicle assignment, and payment recording | • `CONNECT` on `grp00_habalgodb`<br>• `USAGE` on schema `habalgo`<br>• `SELECT, INSERT, UPDATE, DELETE` on `customer`, `location`, `rating_feedback`<br>• `SELECT, INSERT, UPDATE` on `booking`<br>• `SELECT, INSERT` on `payment`<br>• `SELECT, INSERT, UPDATE` on `driver`, `vehicle`, `driver_vehicle`<br>• `USAGE, SELECT` on all sequences in `habalgo` | Allows normal day-to-day ride-booking operations while strictly preventing deletion of booking audit records, alterations of payment amounts, or unauthorized fleet purging. |
| `habalgo_report` | `habalgo_readonly_grp` | Financial Auditor / Fleet Inspector | Audits trip completions, daily gross revenue, payment method breakdowns, and driver ratings | • `CONNECT` on `grp00_habalgodb`<br>• `USAGE` on schema `habalgo`<br>• `SELECT` on all tables in schema `habalgo`<br>• `USAGE, SELECT` on all sequences in schema `habalgo` | Full read transparency for ride metrics and financial reconciliation without any risk of accidental or malicious data modification. |
| `habalgo_backup` | `habalgo_backup_grp` | Backup Operator | Runs logical database backups (`pg_dump -Fc`) | • `CONNECT` on `grp00_habalgodb`<br>• `USAGE` on schema `habalgo`<br>• `SELECT` on all tables & sequences | Grants non-destructive read access required for consistent backups while preventing data modification or schema alterations. |
| `postgres` | *(Superuser)* | Database Administrator | Schema provisioning, indexing, routine maintenance (`VACUUM`/`ANALYZE`), disaster recovery drills | Superuser / Owner privileges | Reserved strictly for DBA operations; never configured in application connection strings or `.env`. |
