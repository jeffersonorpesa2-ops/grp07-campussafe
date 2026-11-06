# Activity 4: Access Control Plan — Group 8 (Campus Canteen Pre-Order Evaluation)

**Evaluating Group:** Group 7 (Alba, Arreza, Orpesa, Robiso, Santos)  
**Target Group:** Group 8 (Borreta, Joshua; Bola, Martin Lawrence; Juatchon, Joaquin Phillip; Marcos, Karl Raphael; Pacheco Jr., Sancho; Vera Cruz, Euan Joseph)  
**Target Project:** bwisIT Solutions — Campus Canteen Pre-Order and Queue Management System  
**Repository:** [https://github.com/EclipseChan/bwisIT-Solutions---Campus-Canteen-Pre-Order-and-Queue-Management-System](https://github.com/EclipseChan/bwisIT-Solutions---Campus-Canteen-Pre-Order-and-Queue-Management-System)  
**Database:** `grp08_canteendb` (PostgreSQL 18.6)  
**Schema:** `public`  

---

## 1. Access-Control Architecture & PoLP Design

The **Campus Canteen Pre-Order and Queue Management System** coordinates student meal pre-orders, vendor menu and stall management, order processing pipelines, daily queue dispatching, and notification delivery. In Activity 3, the application connected using `canteen_admin` (the schema owner), which had unconstrained permissions across the entire database:
- Any web injection or rogue API request could execute destructive DDL commands (`DROP TABLE`, `ALTER TABLE`).
- Malicious actors could delete or alter completed customer orders, manipulate queue entries, or falsify historical sales and item prices.
- Line items in submitted orders could be deleted or modified retroactively, breaking billing integrity and inventory reconciliation.
- Direct table purges could wipe student identities and stall configuration records.

To enforce the **Principle of Least Privilege (PoLP)** and preserve transactional immutability, we implemented an enterprise three-tier Role-Based Access Control (RBAC) architecture:

- **Group Roles (`NOLOGIN`):** Common privilege bundles representing distinct responsibility profiles (`canteen_runtime_grp`, `canteen_readonly_grp`, and `canteen_backup_grp`).
- **Login Roles (`LOGIN`):** Individual authenticated accounts assigned to their corresponding group roles (`canteen_app`, `canteen_report`, and `canteen_backup`).
- **Order Audit Trail Protection:** The runtime account `canteen_app` is granted `SELECT, INSERT, UPDATE` on `customer_order` to advance lifecycle states (`pending` -> `preparing` -> `ready` -> `completed` / `cancelled`), but `DELETE` is **strictly revoked** to guarantee full audit traceability of all sales.
- **Order Line Item Immutability:** `canteen_app` is granted `SELECT, INSERT` on `order_item`. `UPDATE` and `DELETE` privileges are **strictly revoked**, ensuring that once an item is placed in an order at a snapshot price (`price_at_order`), it cannot be altered or deleted.
- **Queue Sequence Integrity:** `canteen_app` can assign and progress queue tokens (`waiting` -> `called` -> `served`), but cannot delete queue entries.
- **Menu Lifecycle Flexibility:** Vendors can manage menu items with full CRUD (`SELECT, INSERT, UPDATE, DELETE`) on `menu_item`, aligning with Group 8's design where items without past orders can be removed.
- **Auditor Read-Only Isolation:** `canteen_report` is granted read-only `SELECT` across all operational tables for financial reporting and administrative inspection, with all DML write operations (`INSERT`, `UPDATE`, `DELETE`) and DDL completely denied.
- **Backup Isolation:** The dedicated backup operator `canteen_backup` is authorized for `pg_dump` logical dumps with read-only permissions across all tables and sequences, with DML and DDL privileges completely denied.
- **Administrative Boundary:** Non-administrative accounts are revoked from creating databases or accessing other group databases on the cluster (`REVOKE CONNECT ON DATABASE grp07_campussafedb FROM PUBLIC;`).

---

## 2. Access Control Matrix

| Login Account | Group Role (`NOLOGIN`) | Application Role Served | Responsibilities | Assigned Privileges | Technical Justification |
|---|---|---|---|---|---|
| `canteen_app` | `canteen_runtime_grp` | Spring Boot REST API Runtime | Handles student pre-orders, vendor menu maintenance, order workflow progression, queue number allocation, and notifications | • `CONNECT` on `grp08_canteendb`<br>• `USAGE` on schema `public`<br>• `SELECT, INSERT, UPDATE` on `student`, `vendor`<br>• `SELECT, INSERT, UPDATE, DELETE` on `menu_item`<br>• `SELECT, INSERT, UPDATE` on `customer_order`<br>• `SELECT, INSERT` on `order_item`<br>• `SELECT, INSERT, UPDATE` on `queue_entry`<br>• `SELECT, INSERT, UPDATE, DELETE` on `notification`<br>• `USAGE, SELECT` on all sequences in `public` | Enables daily canteen transactions while strictly prohibiting deletion of customer orders, alteration of historical line items, or deletion of user records. |
| `canteen_report` | `canteen_readonly_grp` | Canteen Auditor / Revenue Inspector | Audits sales reports, stall revenue splits, top-selling items, order cycle times, and queue throughput | • `CONNECT` on `grp08_canteendb`<br>• `USAGE` on schema `public`<br>• `SELECT` on all 7 tables in `public`<br>• `USAGE, SELECT` on all sequences in `public` | Read-only transparency for financial auditing, vendor revenue reconciliations, and academic administration without any modification risks. |
| `canteen_backup` | `canteen_backup_grp` | Automated Backup Operator | Executes automated logical backups via `pg_dump -Fc` | • `CONNECT` on `grp08_canteendb`<br>• `USAGE` on schema `public`<br>• `SELECT` on all tables & sequences<br>• `pg_read_all_data` | Non-destructive read access required for consistent database dumps without write or schema alteration privileges. |
| `postgres` / `canteen_admin` | *(Superuser / Owner)* | Database Administrator (DBA) | Schema migrations, DDL adjustments, vacuuming, query optimization, and disaster recovery | Superuser / Owner privileges | Reserved strictly for administrative DBA tasks; never configured in application runtime properties or `.env`. |
