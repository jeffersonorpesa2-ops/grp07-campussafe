# Activity 4: Access Control Plan — Group 10 (Restaurant Ordering & Reservation System Evaluation)

**Evaluating Group:** Group 7 (Alba, Arreza, Orpesa, Robiso, Santos)  
**Target Group:** Group 10 (Sandoval, Cellyn; Callos, Kathlen Mae; Romingquit, Arika; Tambio, Jenny Mae; Tungol, Jaimie; Gordonas, John Benedick)  
**Target Project:** Binary Sisters — Restaurant Online Ordering & Table Reservation System  
**Repository:** [https://github.com/kathlenmaecallos11-arch/Restaurant-Online-Ordering-Table-Reservation-System](https://github.com/kathlenmaecallos11-arch/Restaurant-Online-Ordering-Table-Reservation-System)  
**Database:** `grp_binarysisters_projectdb` (PostgreSQL 18.6)  
**Schema:** `public`  

---

## 1. Access-Control Architecture & PoLP Design

The **Restaurant Online Ordering & Table Reservation System** manages customer accounts, food catalog and pricing, physical dining tables, online food orders, line items, customer reservations with anti-overlap protection, and payment settlements. In default or monolithic deployments where applications connect using the superuser `postgres` or an unrestricted account with blanket privileges across all tables:
- A malicious actor or compromised endpoint could modify settled payment amounts, mark unpaid meals as paid, or delete transaction receipts.
- Historical orders could be deleted, corrupting revenue ledgers and kitchen preparation audit trails.
- Customer reservation histories could be deleted or double-booked without auditability.
- Entire tables could be dropped, causing catastrophic restaurant downtime during busy dining service.

To enforce the **Principle of Least Privilege (PoLP)** and preserve transactional immutability, we implemented an enterprise three-tier Role-Based Access Control (RBAC) architecture:

- **Group Roles (`NOLOGIN`):** Common privilege bundles representing distinct administrative profiles: `rors_runtime_grp`, `rors_readonly_grp`, `rors_maint_grp`, `rors_backup_grp`, and `rors_admin_grp`.
- **Login Roles (`LOGIN`):** Authenticated application users assigned exclusively through their respective group roles: `rors_app`, `rors_report`, `rors_maint`, `rors_backup`, and `rors_dba`.
- **Order Audit Trail Preservation:** The runtime account `rors_app` is granted `SELECT, INSERT, UPDATE` on `orders` to advance lifecycle states (`pending` -> `confirmed` -> `preparing` -> `ready` -> `completed` / `cancelled`), but `DELETE` is **strictly revoked** to guarantee full audit traceability of all sales.
- **Order Line Item Immutability:** `rors_app` is granted `SELECT, INSERT` on `order_item`. `UPDATE` and `DELETE` privileges are **strictly revoked**, ensuring that once an item is placed in an order at a snapshot price (`unit_price`), it cannot be altered or deleted.
- **Payment Tamper Protection:** `rors_app` can record and update payment status (`pending` -> `paid`), but `DELETE` is prohibited.
- **Credential Masking:** The read-only / auditor role `rors_report` is granted direct access to operational tables (`orders`, `order_item`, `menu_item`, `restaurant_table`, `reservation`, `payment`), while direct access to `customer` and `staff` is strictly withheld. The auditor accesses customer and staff directories exclusively through sanitized views (`v_customer_directory`, `v_staff_directory`) that omit password hashes.
- **Maintenance & Backup Isolation:** `rors_maint` is granted `pg_maintain` and `pg_monitor` with zero direct access to business data; `rors_backup` is granted `pg_read_all_data` for non-destructive logical backups via `pg_dump`.
- **Administrative Boundary:** Non-administrative accounts are revoked from creating databases or accessing other group databases on the cluster (`REVOKE CONNECT ON DATABASE grp07_campussafedb FROM PUBLIC;`).

---

## 2. Access Control Matrix

| Login Account | Group Role (`NOLOGIN`) | Application Role Served | Responsibilities | Assigned Privileges | Technical Justification |
|---|---|---|---|---|---|
| `rors_app` | `rors_runtime_grp` | PHP Web Application Runtime | Customer ordering, checkout, reservation dispatch, menu management, and table occupancy | • `CONNECT` on `grp_binarysisters_projectdb`<br>• `USAGE` on schema `public`<br>• `SELECT, INSERT, UPDATE` on `customer`, `orders`, `payment`<br>• `SELECT, INSERT, UPDATE, DELETE` on `menu_item`, `restaurant_table`, `reservation`, `staff`<br>• `SELECT, INSERT` on `order_item`<br>• `USAGE, SELECT` on all sequences<br>• `SELECT` on `v_order_summary`, `v_reservation_schedule` | Allows normal restaurant operations while strictly preventing deletion of customer orders, alteration of historical line items, or tampering with payment records. |
| `rors_report` | `rors_readonly_grp` | Financial Auditor / Revenue Inspector | Audits restaurant revenues, daily order summaries, reservation schedules, and item sales | • `CONNECT` on `grp_binarysisters_projectdb`<br>• `USAGE` on schema `public`<br>• `SELECT` on `menu_item`, `restaurant_table`, `orders`, `order_item`, `reservation`, `payment`<br>• `SELECT` on sanitized views (`v_customer_directory`, `v_staff_directory`, `v_order_summary`, `v_reservation_schedule`) | Full read transparency for financial auditing while preventing any data mutation and shielding password hashes from exposure. |
| `rors_maint` | `rors_maint_grp` | Operations Maintenance Operator | Routine vacuuming, index maintenance, and activity monitoring | • `CONNECT` on `grp_binarysisters_projectdb`<br>• `USAGE` on schema `public`<br>• `pg_maintain`, `pg_monitor` | Grants maintenance execution and activity monitoring capabilities without granting read or write access to application data tables. |
| `rors_backup` | `rors_backup_grp` | Automated Backup Operator | Executes automated logical backups via `pg_dump -Fc` | • `CONNECT` on `grp_binarysisters_projectdb`<br>• `USAGE` on schema `public`<br>• `pg_read_all_data` | Non-destructive read access required for consistent database dumps without write or schema alteration privileges. |
| `rors_dba` | `rors_admin_grp` | Database Administrator (DBA) | Schema migrations, DDL adjustments, table management, and recovery | • `CONNECT` on `grp_binarysisters_projectdb`<br>• `USAGE, CREATE` on schema `public`<br>• `ALL PRIVILEGES` on all tables and sequences<br>• `pg_monitor` | DBA administrative role for day-to-day operations; non-superuser. |
| `postgres` | *(Superuser)* | System Administrator | Cluster-level configuration, superuser operations | Superuser privileges | Reserved strictly for initial cluster bootstrapping; never used by application runtime. |
