# Activity 6: Backup, Restoration & Disaster Recovery Simulation

**System:** CampusSafe: Campus Hazard & Safety Reporting System  
**Course:** COMP 018 Database Administration &bull; Group 7  
**Database:** `grp07_campussafedb`  

---

## 1. Backup & Recovery Strategy (CampusSafe Production Proposal)

| Parameter | Specification | Technical Justification |
|---|---|---|
| **Backup Method** | Logical Full Backup via `pg_dump -Fc` (Custom Format) | Custom format allows parallel restoration, table-level selective restoration, and built-in compression. |
| **Backup Frequency** | Daily Full Backup at 01:00 AM | Campus hazard reporting volume is moderate (10–30 reports monthly). Daily backups are sufficient for institutional operations. |
| **Retention Policy** | 7 Daily Backups + 4 Weekly Snapshots | Supports operational rollback for recent errors and historical quarterly compliance auditing. |
| **RPO (Recovery Point Objective)** | &approx; 24 Hours | Acceptable risk window for standard non-financial campus hazard records. *(WAL archiving would be introduced for stricter near-zero RPO).* |
| **RTO (Recovery Time Objective)** | &approx; 2 Hours | Time required for database administrator to provision fresh DB instance, execute `pg_restore`, verify integrity, and repoint application DSN. |
| **Security Account** | `campussafe_backup` (Member of `app_backup_grp`) | Has read-only permissions across all public tables and sequences. Cannot drop, alter, or insert data. |

> **Important Reminder:** Do NOT commit binary `.dump` files to Git. Commit verification scripts, checksums, logs, and simulation evidence only.

---

## 2. Step-by-Step Backup Execution Guide

### Step 1: Perform Custom-Format Logical Backup
Run in PowerShell / Terminal:
```bash
pg_dump -U campussafe_backup -h localhost -p 5432 -Fc -d grp07_campussafedb -f grp07_campussafedb_activity6.dump
```
*(Enter password for `campussafe_backup` when prompted).*

### Step 2: Compute Checksum & File Metadata (Windows PowerShell)
```powershell
Get-FileHash grp07_campussafedb_activity6.dump -Algorithm SHA256
Get-Item grp07_campussafedb_activity6.dump | Select-Object Name, Length, LastWriteTime
```
*Record the SHA256 checksum in your Activity 6 Log.*

### Step 3: Inspect Archive Table of Contents (TOC)
```bash
pg_restore --list grp07_campussafedb_activity6.dump
```
*Confirms that all 9 tables, indexes, constraints, and sequences are present in the archive.*

---

## 3. Step-by-Step Restoration Verification

> **Golden Rule:** NEVER restore over the live production database. Always restore into a newly created test database.

### Step 1: Provision Isolated Test Database
```bash
createdb -U postgres -h localhost -p 5432 grp07_campussafedb_restore_test
```

### Step 2: Execute Archive Restoration
```bash
pg_restore -U postgres -h localhost -p 5432 -d grp07_campussafedb_restore_test grp07_campussafedb_activity6.dump
```

### Step 3: Verify Relational Integrity & Row Counts
```sql
\c grp07_campussafedb_restore_test postgres

-- Verify table row counts match production
SELECT 'hazard_report' AS tbl, count(*) FROM hazard_report
UNION ALL SELECT 'app_user', count(*) FROM app_user
UNION ALL SELECT 'assignment', count(*) FROM assignment;

-- Verify constraints
\d hazard_report
```

### Step 4: Re-apply Roles and Privileges
*Note: Logical dumps created by `pg_dump` contain schema objects and data, but do NOT contain global cluster roles. Roles must be recreated using `database/03_roles_and_privileges.sql`.*
```bash
psql -U postgres -h localhost -p 5432 -d grp07_campussafedb_restore_test -f database/03_roles_and_privileges.sql
```

---

## 4. Disaster Recovery Simulation (Point-in-Time Loss Simulation)

This simulation demonstrates how data loss is handled and recovered.

### 1. Simulated Incident (Data Loss in Restored DB)
```sql
-- Connect to test database
\c grp07_campussafedb_restore_test postgres

-- Insert a tracked test hazard report
INSERT INTO hazard_report (reporter_user_id, location_id, category_id, description, status)
VALUES (4, 1, 1, 'TEST-RECOVERY: Damaged chemical shutoff valve in Room 304', 'Submitted')
RETURNING report_id;

-- Record report state, then simulate accidental catastrophic deletion
DELETE FROM hazard_report WHERE description LIKE 'TEST-RECOVERY%';
```

### 2. Recovery Execution
1. Restore clean backup archive into a fresh secondary recovery database:
   ```bash
   createdb -U postgres -h localhost -p 5432 grp07_campussafedb_recovery_temp
   pg_restore -U postgres -h localhost -p 5432 -d grp07_campussafedb_recovery_temp grp07_campussafedb_activity6.dump
   ```
2. Verify historical rows are intact and recover needed records.

### 3. Post-Incident Analysis:
- **If the incident occurred prior to the latest backup:** The data is 100% recovered from the dump archive.
- **If the incident occurred after the latest backup:** Transactions committed after the 01:00 AM backup window are lost under the 24-hour RPO. Mitigating this would require continuous WAL archiving (Write-Ahead Logging) and Point-In-Time Recovery (PITR).
