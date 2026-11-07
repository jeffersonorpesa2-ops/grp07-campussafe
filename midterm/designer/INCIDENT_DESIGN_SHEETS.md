# COMP 018 Midterm Examination - Incident Design Sheets (Designer Role)

**Evaluating Group:** Group 7 (CampusSafe)  
**Target Assigned Group:** `[Assigned Group]`  
**Target Database:** `[peer_db]`  
**Disposable Test Database:** `[peer_db_disposable]`  

---

## Scenario 1: Privilege & Access Control Issue (Activity 4)
* **Incident ID:** `INC-01` &bull; **Linked Flaw ID:** `FLAW-01`
* **Variant & Activity Area:** Privileges / Access Control &bull; Activity 4
* **Difficulty & Estimated Time:** **Easy** &bull; **15 Minutes**
* **Public Incident Brief (Symptoms Only):**
  > *"Front-end application users report that when attempting to record a new transaction or submit a new form entry, the system immediately crashes with a database permission error, preventing all newly registered transactions from saving."*
* **Public Evidence Available:**
  - Web application error logs: `SQLSTATE[42501]: Insufficient privilege: 7 ERROR: permission denied for sequence ...`
  - PostgreSQL server log entries: `ERROR: permission denied for sequence ..._seq`
* **Private Root Cause (Instructor Pack):**
  - Application runtime role lacks `USAGE, SELECT` privileges on the table's auto-incrementing identity sequence.
* **Private Fault Script:**
  ```sql
  REVOKE USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public FROM <app_runtime_role>;
  ```
* **Private Reset & Corrective Action:**
  ```sql
  GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO <app_runtime_role>;
  ```
* **Private Verification:**
  - Execute `INSERT` under `<app_runtime_role>` credentials (should succeed).
  - Attempt DDL (`DROP SEQUENCE`) under `<app_runtime_role>` (should still be denied).

---

## Scenario 2: Object / Schema & Credential Exposure Issue (Activities 3 & 4)
* **Incident ID:** `INC-02` &bull; **Linked Flaw ID:** `FLAW-02`
* **Variant & Activity Area:** Object / Security Architecture &bull; Activities 3 to 4
* **Difficulty & Estimated Time:** **Medium** &bull; **20 Minutes**
* **Public Incident Brief (Symptoms Only):**
  > *"The external compliance auditor reports that the compliance dashboard fails to load with an 'object not found' error. Simultaneously, an internal security audit warns that granting direct table access to read-only accounts exposes sensitive bcrypt password hashes in clear violation of privacy standards."*
* **Public Evidence Available:**
  - PostgreSQL log: `ERROR: relation "v_user_directory" does not exist`
  - `\d` object catalog listing in `public` schema.
* **Private Root Cause (Instructor Pack):**
  - The security abstraction view `v_user_directory` was accidentally dropped or missing, leaving read-only users without access unless granted raw access to password hashes.
* **Private Fault Script:**
  ```sql
  DROP VIEW IF EXISTS v_user_directory CASCADE;
  ```
* **Private Reset & Corrective Action:**
  ```sql
  CREATE OR REPLACE VIEW v_user_directory AS
  SELECT user_id, username, full_name, role_name, created_at FROM app_user JOIN user_role USING (role_id);
  GRANT SELECT ON v_user_directory TO <readonly_auditor_role>;
  ```
* **Private Verification:**
  - Query `v_user_directory` as auditor (succeeds and displays metadata without password hashes).
  - Query `app_user` directly as auditor (must fail with `permission denied`).

---

## Scenario 3: Performance Degradation & Maintenance Issue (Activity 5)
* **Incident ID:** `INC-03` &bull; **Linked Flaw ID:** `FLAW-03`
* **Variant & Activity Area:** Query Performance & Maintenance &bull; Activity 5
* **Difficulty & Estimated Time:** **Medium** &bull; **25 Minutes**
* **Public Incident Brief (Symptoms Only):**
  > *"Operational supervisors report severe dashboard latency during peak morning hours. Filtering for active/pending records causes page load times to exceed 4 seconds, and PostgreSQL CPU utilization spikes to 95%."*
* **Public Evidence Available:**
  - Execution plan from `EXPLAIN (ANALYZE, BUFFERS)` showing `Seq Scan` with high buffer reads.
  - `pg_stat_user_tables` showing high dead tuple count and stale `last_analyze` timestamps.
* **Private Root Cause (Instructor Pack):**
  - The supporting status index was dropped, and table statistics are out of date, forcing sequential scans through unpruned dead tuples.
* **Private Fault Script:**
  ```sql
  DROP INDEX IF EXISTS idx_<entity>_status;
  -- Generate dead tuples through non-changing updates
  UPDATE <entity> SET updated_at = NOW() WHERE status = 'PENDING';
  ```
* **Private Reset & Corrective Action:**
  ```sql
  CREATE INDEX idx_<entity>_status ON <entity>(status);
  VACUUM (VERBOSE, ANALYZE) <entity>;
  ```
* **Private Verification:**
  - Run `EXPLAIN (ANALYZE, BUFFERS)` on the dashboard query; verify `Bitmap Index Scan` or `Index Scan` with execution time under 5 ms.

---

## Scenario 4: Backup Service Failure & Data Inaccessibility (Activity 6)
* **Incident ID:** `INC-04` &bull; **Linked Flaw ID:** `FLAW-04`
* **Variant & Activity Area:** Backup, Recovery & Least Privilege &bull; Activity 6
* **Difficulty & Estimated Time:** **Hard** &bull; **30 Minutes**
* **Public Incident Brief (Symptoms Only):**
  > *"The nightly automated backup job failed with exit code 1 at 01:00 AM. The generated archive file is only 0 bytes in size, and subsequent restore tests throw an error that the archive is empty or invalid, risking total data loss in the event of hardware failure."*
* **Public Evidence Available:**
  - Scheduled task output log: `pg_dump: error: query failed: ERROR: permission denied for table ...`
  - Backup directory showing incomplete 0-byte or corrupted `.dump` file.
* **Private Root Cause (Instructor Pack):**
  - The dedicated non-superuser backup role (`*_backup`) was stripped of `pg_read_all_data` privileges or denied `SELECT` on a recently added table, causing `pg_dump` to fail midway.
* **Private Fault Script:**
  ```sql
  REVOKE pg_read_all_data FROM <backup_role>;
  REVOKE SELECT ON ALL TABLES IN SCHEMA public FROM <backup_role>;
  ```
* **Private Reset & Corrective Action:**
  ```sql
  GRANT pg_read_all_data TO <backup_role>;
  -- Re-run backup
  -- pg_dump.exe -U <backup_role> -Fc -f "pg_backups\recovery_test.dump" <peer_db>
  ```
* **Private Verification:**
  - Execute `pg_dump` under `<backup_role>`; confirm clean exit (code 0).
  - Inspect TOC via `pg_restore --list`; verify all tables are present.

---

## Scenario 5: Sequence Desynchronization & Concurrency Failure (Free Choice)
* **Incident ID:** `INC-05` &bull; **Linked Flaw ID:** `FLAW-05`
* **Variant & Activity Area:** Primary Key Sequence State & Data Integrity &bull; Activity 2 & 3
* **Difficulty & Estimated Time:** **Easy** &bull; **15 Minutes**
* **Public Incident Brief (Symptoms Only):**
  > *"Users attempting to submit a new entry receive an immediate database crash with error 'duplicate key value violates unique constraint'. Even though the application claims to generate auto-incrementing IDs, the database insists that ID 1 already exists."*
* **Public Evidence Available:**
  - Application exception: `SQLSTATE[23505]: Unique violation: 7 ERROR: duplicate key value violates unique constraint "..._pkey" Key (id)=(1) already exists.`
  - Query output from `SELECT last_value FROM <sequence_name>;` showing `1` while table `MAX(id)` is substantially higher.
* **Private Root Cause (Instructor Pack):**
  - The identity sequence generator was desynchronized from the table data (e.g. after a manual data migration or restart).
* **Private Fault Script:**
  ```sql
  ALTER SEQUENCE <entity_id_seq> RESTART WITH 1;
  ```
* **Private Reset & Corrective Action:**
  ```sql
  SELECT setval('<entity_id_seq>', (SELECT COALESCE(MAX(<id>), 0) + 1 FROM <entity>), false);
  ```
* **Private Verification:**
  - Execute an `INSERT` statement without specifying primary key ID; verify successful insertion with incremented ID.
