# CampusSafe — Database User & Role Setup Guide (Activity 4)

**Target Database:** `grp07_campussafedb`  
**Purpose:** Setup and verification instructions for Activity 4 access control, intended for external group evaluation and peer testing.  

> **Security Rule:** Never commit real passwords to Git. All passwords shown below are placeholders and must be set via local secrets.

---

## 1. Quick Setup Script Execution

Log in as the PostgreSQL superuser (`postgres`) or database owner (`campussafe_owner`) into `grp07_campussafedb`:

```bash
psql -U postgres -h localhost -p 5432 -d grp07_campussafedb -f database/03_roles_and_privileges.sql
```

*(Note: Adjust `-p 5433` if your PostgreSQL instance runs on port 5433).*

---

## 2. Intended Database Roles & Accounts Hierarchy

```
PostgreSQL Database Server
├── Group Role: app_runtime_grp (NOLOGIN)
│   └── Login Account: campussafe_app (Used by PHP PDO Web App)
├── Group Role: app_readonly_grp (NOLOGIN)
│   └── Login Account: campussafe_report (Used by Safety Auditor / BI)
└── Group Role: app_backup_grp (NOLOGIN)
    └── Login Account: campussafe_backup (Used for Activity 6 pg_dump)
```

---

## 3. Privilege Specifications Table

| Login Account | Member Of | Allowed Database Operations | Denied Operations (Enforced PoLP) |
|---|---|---|---|
| `campussafe_app` | `app_runtime_grp` | `CONNECT` to DB<br>`USAGE` on schema public<br>`SELECT, INSERT, UPDATE` on all tables<br>`DELETE` on `attachment`, `assignment`<br>`USAGE, SELECT` on all sequences | `DELETE` on `hazard_report`<br>`DELETE` on `app_user`<br>`CREATE TABLE`, `DROP TABLE`<br>`CREATE ROLE`, `CREATE DATABASE`<br>Connection to unrelated databases |
| `campussafe_report`| `app_readonly_grp` | `CONNECT` to DB<br>`USAGE` on schema public<br>`SELECT` on `hazard_report`, `hazard_category`, `campus_location`, `assignment`, `report_status_history`, `maintenance_action`, `attachment` | `SELECT` on `app_user` (protects password hashes)<br>Any `INSERT`, `UPDATE`, or `DELETE`<br>Any DDL modifications |
| `campussafe_backup`| `app_backup_grp` | `CONNECT` to DB<br>`USAGE` on schema public<br>`SELECT` on all tables<br>`SELECT` on all sequences | Any `INSERT`, `UPDATE`, or `DELETE`<br>Any DDL modifications |

---

## 4. Activity 4 Verification Test Suite (Allowed vs. Denied Operations)

Run each test in `psql` to produce the evidence required for Activity 4 grading.

### Test 1: Runtime Account Can SELECT & INSERT Operational Data (Expected: ALLOWED)
```sql
-- Connect as runtime user
\c grp07_campussafedb campussafe_app

-- Test SELECT
SELECT COUNT(*) FROM hazard_report;

-- Test INSERT into report_status_history
INSERT INTO report_status_history (report_id, changed_by_user_id, status, notes)
VALUES (1, 1, 'Submitted', 'Activity 4 permission test verification');
```
*Expected Result:* Both queries succeed without errors.

---

### Test 2: Runtime Account CANNOT Delete Hazard Reports (Expected: DENIED)
```sql
-- Connect as runtime user
\c grp07_campussafedb campussafe_app

DELETE FROM hazard_report WHERE report_id = 1;
```
*Expected Result:*
```
ERROR: permission denied for table hazard_report
```

---

### Test 3: Read-Only Account CANNOT Update Data (Expected: DENIED)
```sql
-- Connect as auditor user
\c grp07_campussafedb campussafe_report

UPDATE hazard_report SET priority = 'Critical' WHERE report_id = 1;
```
*Expected Result:*
```
ERROR: permission denied for table hazard_report
```

---

### Test 4: Read-Only Account CANNOT Access User Credentials (Expected: DENIED)
```sql
-- Connect as auditor user
\c grp07_campussafedb campussafe_report

SELECT user_id, username, password_hash FROM app_user;
```
*Expected Result:*
```
ERROR: permission denied for table app_user
```

---

### Test 5: Accounts Cannot Connect to Unrelated Databases (Expected: DENIED)
```bash
psql -U campussafe_app -h localhost -p 5432 -d postgres
```
*Expected Result:*
```
FATAL: permission denied for database "postgres"
DETAIL: User does not have CONNECT privilege.
```

---

## 5. Sequence Grant Verification (Important Troubleshooting Note)

When external testers insert records into serial tables, PostgreSQL evaluates permissions on both the table and its underlying sequence (`tablename_columnname_seq`).
If you receive:
```
ERROR: permission denied for sequence hazard_report_report_id_seq
```
Ensure you have executed the sequence grant from `database/03_roles_and_privileges.sql`:
```sql
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_runtime_grp;
```
