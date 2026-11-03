# Activity 4: Database Access Control & Privilege Management

**System:** CampusSafe: Campus Hazard & Safety Reporting System  
**Course:** COMP 018 Database Administration &bull; Group 7  

---

## 1. Objectives & Overview

In Activity 4, your team evaluates peer group repositories, inspects their database structure, designs an access-control matrix, and executes role-based permissions scripts adhering to the **Principle of Least Privilege (PoLP)**.

This folder serves as the central repository for Activity 4 work performed on peer groups and provides the reference access-control plan for CampusSafe.

---

## 2. CampusSafe Reference Access-Control Plan

| Login Account | Group Role (NOLOGIN) | Application Role Served | Database Responsibilities | Granted Privileges |
|---|---|---|---|---|
| `campussafe_app` | `app_runtime_grp` | System Runtime (PHP PDO) | Handles standard application operations (filing hazards, updating status, recording technician actions). | `CONNECT` on DB<br>`USAGE` on schema public<br>`SELECT, INSERT, UPDATE` on all tables<br>`DELETE` on `attachment`, `assignment`<br>`USAGE, SELECT` on all sequences |
| `campussafe_report`| `app_readonly_grp` | Safety Auditor / BI Inspector | Audits safety reports, inspects compliance timelines, views incident trends. | `CONNECT` on DB<br>`USAGE` on schema public<br>`SELECT` on `hazard_report`, `hazard_category`, `campus_location`, `assignment`, `report_status_history`, `maintenance_action`, `attachment`<br>*(No access to `app_user`)* |
| `campussafe_backup`| `app_backup_grp` | Backup Operator (`pg_dump`) | Executes logical backups without modifying database state. | `CONNECT` on DB<br>`USAGE` on schema public<br>`SELECT` on all tables & sequences |

---

## 3. Peer Group Evaluation Workspace Template

When testing other groups' databases in Activity 4, create a subfolder:
```
db-access-control/group-XX/
├── access-control-plan.md
├── 01_roles_and_grants.sql
├── verification_tests.sql
└── evidence_screenshots/
```

### Verification Test Log Matrix Template:

| Test # | Account | Statement Tested | Expected Result | Actual Result | Status |
|---|---|---|---|---|---|
| 1 | Runtime | `SELECT COUNT(*) FROM hazard_report;` | Allowed | Query returned row count | PASS |
| 2 | Runtime | `INSERT INTO report_status_history ...` | Allowed | 1 row inserted | PASS |
| 3 | Runtime | `DELETE FROM hazard_report WHERE report_id = 1;` | Denied | `ERROR: permission denied for table hazard_report` | PASS |
| 4 | Auditor | `SELECT * FROM app_user;` | Denied | `ERROR: permission denied for table app_user` | PASS |
| 5 | Auditor | `UPDATE hazard_report SET priority = 'High';` | Denied | `ERROR: permission denied for table hazard_report` | PASS |
| 6 | Backup | `pg_dump -U campussafe_backup ...` | Allowed | Dump completed cleanly | PASS |
