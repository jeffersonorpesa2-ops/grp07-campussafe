# Activity 4: Access Control Plan — Group 2 (Park-It Evaluation)

**Evaluating Group:** Group 7 (Alba, Arreza, Orpesa, Robiso, Santos)  
**Target Group:** Group 2 (Devera, Francis, et al.)  
**Target Project:** Park-It Database Management System  
**Database:** `grp_parkitdb` (PostgreSQL 18.6)  

---

## 1. Access-Control Architecture & PoLP Design

Park-It is an operational parking management platform managing parking zones, vehicle entries/exits, staff attendants, and payment collection. In default configurations, running backend queries under `postgres` allows any endpoint vulnerability or injection vector to modify collected parking fees, delete active or past transactions, or drop parking zones.

We implemented a three-tier Role-Based Access Control (RBAC) architecture enforcing the **Principle of Least Privilege (PoLP)**:
- **Group Roles (`NOLOGIN`):** `parkit_runtime_grp`, `parkit_readonly_grp`, `parkit_backup_grp`.
- **Login Accounts (`LOGIN`):** `parkit_app`, `parkit_report`, `parkit_backup`.
- **Financial Ledger Immutability:** `parkit_app` receives `SELECT, INSERT` on `payment`. `UPDATE` and `DELETE` privileges are strictly denied.
- **Audit Trail Protection:** `parkit_app` receives `SELECT, INSERT, UPDATE` on `transaction` (to update exit times and calculate duration), but `DELETE` is strictly denied.
- **Credential Protection:** `parkit_report` has read-only `SELECT` on operational tables (`parking_zone`, `vehicle`, `transaction`, `payment`), but is **explicitly denied `SELECT` on `staff_user`** to prevent exposure of bcrypt password hashes to reporting tools.
- **Backup Operator:** `parkit_backup` is authorized for `pg_dump` read-only operations.

---

## 2. Access Control Matrix

| Login Account | Group Role (NOLOGIN) | Application Role Served | Responsibilities | Assigned Privileges | Technical Justification |
|---|---|---|---|---|---|
| `parkit_app` | `parkit_runtime_grp` | Node.js Runtime | Manages parking zones, vehicle registration, check-ins, check-outs, and payment logging | • `CONNECT` on `grp_parkitdb`<br>• `USAGE` on schema `public`<br>• `SELECT, INSERT, UPDATE, DELETE` on `parking_zone`, `vehicle`<br>• `SELECT, INSERT, UPDATE` on `transaction`<br>• `SELECT, INSERT` on `payment`<br>• `SELECT` on `staff_user`<br>• `USAGE, SELECT` on all sequences | Prevents deletion of historical transactions and alterations of payments, while permitting necessary day-to-day zone updates and vehicle check-in/out workflows. |
| `parkit_report` | `parkit_readonly_grp` | Parking Auditor / Billing Inspector | Audits parking capacity utilization, vehicle turnover rates, and daily revenue collection | • `CONNECT` on `grp_parkitdb`<br>• `USAGE` on schema `public`<br>• `SELECT` on `parking_zone`, `vehicle`, `transaction`, `payment`<br>*(No access to `staff_user`)* | Read-only inspection of parking traffic and fee collections without risk of tampering. Excluding `staff_user` shields attendant password hashes. |
| `parkit_backup` | `parkit_backup_grp` | Backup Operator | Runs logical database backups (`pg_dump`) | • `CONNECT` on `grp_parkitdb`<br>• `USAGE` on schema `public`<br>• `SELECT` on all tables & sequences | Grants non-destructive read access required for consistent logical backups while preventing DDL/DML. |
| `postgres` | *(Superuser)* | Database Administrator | Schema provisioning, indexing, maintenance, disaster recovery | Superuser / Owner privileges | Reserved strictly for administrative DBA tasks. Never configured in runtime `.env`. |
