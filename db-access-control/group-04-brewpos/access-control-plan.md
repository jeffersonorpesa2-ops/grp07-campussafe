# Activity 4: Access Control Plan — Group 4 (BrewPOS Evaluation)

**Evaluating Group:** Group 7 (Alba, Arreza, Orpesa, Robiso, Santos)  
**Target Group:** Group 4 (Olivarez, Abangan, Pocsidio, Infantado, and Bartolata)  
**Target Project:** BrewPOS — Café Point-of-Sale System  
**Database:** `grp_brewposdb` (PostgreSQL 18.6)  

---

## 1. Access-Control Architecture & PoLP Design

BrewPOS is an operational café point-of-sale system managing products, cashiers, and transactional customer sales. In default setups, using `postgres` allows any injection or application vulnerability to tamper with historical revenue records.

We established a three-tiered Role-Based Access Control (RBAC) architecture enforcing the **Principle of Least Privilege (PoLP)**:
- **Group Roles (`NOLOGIN`):** `brewpos_runtime_grp`, `brewpos_readonly_grp`, `brewpos_backup_grp`.
- **Login Accounts (`LOGIN`):** `brewpos_app`, `brewpos_auditor`, `brewpos_backup`.
- **Tamper-Proof Sales Immutability:** `brewpos_app` receives `SELECT, INSERT` on `order_ticket` and `order_line_item`. `UPDATE` and `DELETE` are strictly denied, preserving legal and financial transaction logs.
- **Auditor Isolation:** `brewpos_auditor` has read-only `SELECT` across all tables, with zero write permissions.
- **Backup Operator:** `brewpos_backup` is authorized for `pg_dump` read-only operations.

---

## 2. Access Control Matrix

| Login Account | Group Role (NOLOGIN) | Application Role Served | Responsibilities | Assigned Privileges | Technical Justification |
|---|---|---|---|---|---|
| `brewpos_app` | `brewpos_runtime_grp` | Spring Boot Runtime | Operational register checkout, catalog management | • `CONNECT` on `grp_brewposdb`<br>• `USAGE` on schema `public`<br>• `SELECT` on `staff`<br>• `SELECT, INSERT, UPDATE, DELETE` on `menu_category`, `menu_item`<br>• `SELECT, INSERT` on `order_ticket`, `order_line_item`<br>• `USAGE, SELECT` on sequences | Narrow permissions guarantee that menu pricing and items can be managed, while sales history cannot be altered or purged under any circumstance. |
| `brewpos_auditor` | `brewpos_readonly_grp` | Financial Auditor / Inspector | Daily sales reconciliation, transaction audits | • `CONNECT` on `grp_brewposdb`<br>• `USAGE` on schema `public`<br>• `SELECT` on all 5 tables & sequences | Full read-only transparency into historical sales, tender methods, and cashier attributions without risk of data alteration. |
| `brewpos_backup` | `brewpos_backup_grp` | Backup Operator | Executes logical backups via `pg_dump -Fc` | • `CONNECT` on `grp_brewposdb`<br>• `USAGE` on schema `public`<br>• `SELECT` on all tables & sequences | Grants non-destructive read access required for consistent binary dumps while prohibiting DDL/DML. |
| `postgres` | *(Superuser)* | Database Administrator | Schema provisioning, indexing, maintenance, disaster recovery | Superuser / Owner privileges | Reserved strictly for administrative tasks. Never configured in runtime `.env`. |
