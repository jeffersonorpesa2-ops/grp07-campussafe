# Activity 4: Access Control Plan — Group 5 (PUP-SPOT Campus Lost and Found Evaluation)

**Evaluating Group:** Group 7 (Alba, Arreza, Orpesa, Robiso, Santos)  
**Target Group:** Group 5 (`https://github.com/grp05-dba/grp05_lostandfound`)  
**Target Project:** PUP-SPOT — Campus Lost and Found (`grp05_lostandfound`)  
**Database:** `grp05_lostandfounddb` (PostgreSQL 18.6)  

---

## 1. Access-Control Architecture & PoLP Design

PUP-SPOT is a campus Lost and Found management platform where students and visitors can browse found items, submit lost-item reports, file claim requests with reference codes, and upload verification photos. Campus marshals and staff administrators review claim evidence, resolve matches, update found-item statuses, and archive records.

In standard installations where backends connect with superuser privileges or blanket database owner accounts:
- Any malicious user or client exploiting public endpoints could alter existing found-item descriptions or statuses (marking items claimed before retrieval).
- Students could approve their own claim requests without campus marshal verification.
- Claim histories or lost-item audit trails could be purged.
- Crucial database tables could be dropped.

To address these vulnerabilities, we designed and implemented a three-tier Role-Based Access Control (RBAC) architecture strictly enforcing the **Principle of Least Privilege (PoLP)**:

- **Group Roles (`NOLOGIN`):** `lostandfound_admin_grp`, `lostandfound_public_grp`, `lostandfound_backup_grp`.
- **Login Accounts (`LOGIN`):** `lostandfound_app` (Campus Marshal/Staff Admin), `lostandfound_public` (Public Guest/Student API), `lostandfound_backup` (Backup Operator).
- **Claim Workflow Tamper Protection:** The public account `lostandfound_public` is allowed to submit new claims (`INSERT ON claims`), but is **strictly denied `UPDATE` and `DELETE` on `claims`**. Only authorized campus staff (`lostandfound_app`) have `UPDATE` permissions to approve or reject claims.
- **Found Item Protection:** `lostandfound_public` can browse items (`SELECT ON items`), but cannot modify or delete them (`UPDATE, DELETE` denied).
- **Public Report Self-Service:** `lostandfound_public` is permitted column-level update `UPDATE (status) ON lost_reports` specifically to cancel their own reported lost item, while preventing alteration of reported dates, student numbers, or item categories.
- **Backup Isolation:** The dedicated backup operator `lostandfound_backup` is authorized for `pg_dump` logical dumps with read-only permissions across all tables and sequences, with DML and DDL privileges completely denied.
- **Administrative Boundary:** Non-administrative accounts are revoked from creating databases or accessing other group databases on the cluster (`REVOKE CONNECT ON DATABASE grp07_campussafedb FROM PUBLIC;`).

---

## 2. Access Control Matrix

| Login Account | Group Role (`NOLOGIN`) | Application Role Served | Responsibilities | Assigned Privileges | Technical Justification |
|---|---|---|---|---|---|
| `lostandfound_public` | `lostandfound_public_grp` | Public Student/Guest API (Port 8000) | Browses found items, submits lost reports, files claim requests, uploads photos, tracks status | • `CONNECT` on `grp05_lostandfounddb`<br>• `USAGE` on schema `public`<br>• `SELECT` on `categories`, `items`, `lost_reports`, `claims`, `potential_matches`, `item_images`, `lost_report_images`<br>• `INSERT` on `lost_reports`, `claims`, `potential_matches`, `lost_report_images`, `claim_images`<br>• `UPDATE (status)` on `lost_reports`<br>• `DELETE` on `potential_matches`<br>• `USAGE, SELECT` on public sequences | Enables public item search and reporting workflows while preventing unauthorized item edits, self-approval of claims, or deletion of filed claims. |
| `lostandfound_app` | `lostandfound_admin_grp` | Campus Marshal Admin API (Port 8001) | Manages found-item catalog, reviews claim verification photos, approves/rejects claims, resolves matches | • `CONNECT` on `grp05_lostandfounddb`<br>• `USAGE` on schema `public`<br>• `SELECT, INSERT, UPDATE` on all tables in `public`<br>• `DELETE` on `potential_matches`, `item_images`, `lost_report_images`, `claim_images`<br>• `USAGE, SELECT` on all sequences | Grants staff necessary management powers to verify claims and update item statuses without possessing table ownership or DDL privileges. |
| `lostandfound_backup` | `lostandfound_backup_grp` | Backup Operator | Runs logical database backups (`pg_dump -Fc`) | • `CONNECT` on `grp05_lostandfounddb`<br>• `USAGE` on schema `public`<br>• `SELECT` on all tables & sequences | Grants non-destructive read access required for consistent backups while preventing data modification or schema alterations. |
| `postgres` | *(Superuser)* | Database Administrator | Schema provisioning, indexing, routine maintenance (`VACUUM`/`ANALYZE`), disaster recovery drills | Superuser / Owner privileges | Reserved strictly for DBA operations; never configured in application connection strings or `.env`. |
