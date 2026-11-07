# COMP 018 Midterm Examination - Technical Defense Guide (Group 7)

## Group Member Role Allocation & Anticipated Defense Questions

| Member | Specialization Area | Midterm Focus (Designer Role) | Midterm Focus (Owner Role) |
|---|---|---|---|
| **Jefferson Orpesa (Lead)** | Security, Access Control & Governance | Privilege flaw identification & Incident 1 design | Access control troubleshooting, RBAC enforcement & PoLP |
| **Alba** | Database Architecture & Schema Integrity | Schema, constraint & missing PK/FK flaw identification | Object, constraint & schema validation |
| **Arreza** | System Integration & Application Connectivity | Connection string, driver & configuration flaws | Connection debugging, PDO error parsing & runtime testing |
| **Robiso** | Performance Tuning & Database Maintenance | Query latency, unindexed FKs & bloat flaw identification | `EXPLAIN (ANALYZE, BUFFERS)` profiling, VACUUM/ANALYZE fixes |
| **Santos** | Backup, Recovery & Quality Assurance | Backup failure, archive permission & TOC flaws | Restore verification, SHA-256 hashing & canary drills |

---

## 🎤 Member 1: Jefferson Orpesa (Security & Access Control Lead)

### Anticipated Questions & Strong Technical Answers:

**Q1: "Why did your group create group roles like `app_runtime_grp` instead of granting privileges directly to individual users?"**
> **Answer:** *"In accordance with Role-Based Access Control (RBAC) best practices, granting privileges directly to user accounts creates administrative drift and security vulnerabilities when staff leave or change roles. We separate privileges into functional group roles (`app_runtime_grp`, `app_readonly_grp`, `app_backup_grp`) that hold no login permissions (`NOLOGIN`). Login accounts (`campussafe_app`, `campussafe_auditor`, `campussafe_backup`) inherit their permissions by membership. This allows auditing, rotating credentials, and revoking rights cleanly without altering table-level grant statements."*

**Q2: "In your troubleshooting, why didn't you just grant `ALL PRIVILEGES` to fix the permission denied error?"**
> **Answer:** *"Granting `ALL PRIVILEGES` violates the Principle of Least Privilege (PoLP). An application runtime account only needs `SELECT, INSERT, UPDATE` on transaction tables and `USAGE, SELECT` on sequences. Granting `ALL PRIVILEGES` gives `DELETE, TRUNCATE, TRIGGER, REFERENCES`, which allows SQL injection attacks or application bugs to wipe entire tables or alter schema definitions."*

**Q3: "How does your group prevent password hash exposure to auditors?"**
> **Answer:** *"We withhold direct `SELECT` permissions on the `app_user` table from the auditor role. Instead, we provide an abstraction view `v_user_directory` that selects only non-sensitive columns (`user_id, username, full_name, role_name, created_at`) and omits `password_hash`. The auditor is granted `SELECT` only on this view."*

---

## 🎤 Member 2: Alba (Database Architecture & Schema Integrity)

### Anticipated Questions & Strong Technical Answers:

**Q1: "Explain how your schema ensures referential integrity when a hazard category or user is deleted."**
> **Answer:** *"We used `ON DELETE RESTRICT` (the PostgreSQL default) on critical foreign keys like `category_id` and `reporter_user_id` in `hazard_report`. This strictly prevents accidental deletion of historical records if related reports exist, preserving auditability and legal compliance. Only child logging tables like `hazard_photo` cascade from parent reports."*

**Q2: "What check constraints did you implement, and what happened when invalid data was tested?"**
> **Answer:** *"We enforced check constraints like `chk_hazard_status` (`CHECK (status IN ('Submitted', 'Under Review', 'Assigned', 'In Progress', 'Resolved', 'Dismissed'))`). When an invalid status string was inserted, PostgreSQL rejected the transaction with error code `23514 (check_violation)`, protecting the database from dirty state corruption before application logic even evaluates it."*

**Q3: "How do you detect if a peer group's schema is missing primary keys or foreign keys?"**
> **Answer:** *"We query `information_schema.table_constraints` joined against `information_schema.tables`. Any table where `constraint_type = 'PRIMARY KEY'` is `NULL` represents a severe flaw because relational databases require unique entity identifiers to enforce ACID consistency and avoid duplicate rows."*

---

## 🎤 Member 3: Arreza (Application & System Integration)

### Anticipated Questions & Strong Technical Answers:

**Q1: "When an application gets a `permission denied for sequence ..._seq`, why did that happen if table `INSERT` was already granted?"**
> **Answer:** *"In PostgreSQL, an auto-incrementing `SERIAL` or `IDENTITY` column calls the underlying function `nextval('sequence_name')`. Granting `INSERT` on the table only authorizes row insertion into the relation; it does NOT grant permission to advance the sequence generator. The account must be explicitly granted `USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public`."*

**Q2: "How does your application prevent SQL injection when interacting with PostgreSQL?"**
> **Answer:** *"Our PHP backend uses PDO with parameterized prepared statements (`$stmt->prepare()` and `$stmt->execute([...])`). Query parameters are sent separately from the SQL statement via PostgreSQL's extended query protocol, preventing user input from breaking out into executable SQL syntax."*

**Q3: "How did you configure connection parameters securely in your application?"**
> **Answer:** *"We separated credentials from code using `.env` environment variables (`DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`). The `.env` file is excluded from git via `.gitignore`, while a sanitized `.env.example` template provides configuration structure without exposing passwords."*

---

## 🎤 Member 4: Robiso (Performance Tuning & Maintenance)

### Anticipated Questions & Strong Technical Answers:

**Q1: "Explain the difference between `Seq Scan` and `Index Scan` in `EXPLAIN (ANALYZE, BUFFERS)`."**
> **Answer:** *"A `Seq Scan` (Sequential Scan) reads every single page in the table sequentially from start to end, checking the filter condition on every tuple. An `Index Scan` traverses a B-tree structure to directly pinpoint the exact page and tuple offset matching the condition. In our tests, switching from a `Seq Scan` to an `Index Scan` reduced buffer reads and slashed query execution time from several milliseconds down to sub-millisecond ranges."*

**Q2: "What is a dead tuple, and why is `VACUUM` necessary in PostgreSQL?"**
> **Answer:** *"Because PostgreSQL uses Multi-Version Concurrency Control (MVCC), when a row is updated or deleted, PostgreSQL does not overwrite the disk space immediately; it writes a new version of the row and marks the old version as dead. Over time, accumulated dead tuples cause disk bloat, inflate memory buffer consumption, and slow down table scans. `VACUUM` reclaims that dead tuple space into the Free Space Map (FSM) so future inserts can reuse it."*

**Q3: "Why did you run `ANALYZE` after creating an index or loading data?"**
> **Answer:** *"The PostgreSQL cost-based query planner relies on statistical sample data stored in `pg_statistic` (and `pg_stats`) to estimate row counts and decide between sequential scans, hash joins, or index scans. Running `ANALYZE` updates distribution histograms and page estimates, ensuring the planner selects the most efficient execution plan."*

---

## 🎤 Member 5: Santos (Backup, Recovery & QA Testing)

### Anticipated Questions & Strong Technical Answers:

**Q1: "Why did you choose `pg_dump -Fc` (custom format) over a plain text SQL dump?"**
> **Answer:** *"The custom format (`-Fc`) incorporates built-in zlib compression (saving over 74% disk space), includes a Table of Contents (TOC) metadata header that allows selective object extraction via `pg_restore`, and supports multi-threaded parallel restoration (`pg_restore -j`). Plain SQL dumps cannot be selectively filtered or restored in parallel."*

**Q2: "What does an RPO of 24 hours and an RTO of 2 hours mean in practice?"**
> **Answer:** *"RPO (Recovery Point Objective) is the maximum acceptable age of data that can be lost. An RPO of 24 hours means our daily nightly backup at 01:00 AM accepts at most 24 hours of data loss in a catastrophic failure. RTO (Recovery Time Objective) is the maximum acceptable duration of downtime. An RTO of 2 hours means our team can provision a fresh database instance, decompress and restore the archive, verify integrity, and point the application back to service in under 2 hours."*

**Q3: "How does a Canary Disaster Recovery Drill prove that a backup is valid?"**
> **Answer:** *"A backup file existing on disk does NOT prove recoverability. In our canary drill, we inject a known, timestamped canary record, take an immediate snapshot, simulate catastrophic data loss (`DELETE`), restore the archive into an isolated staging database, and verify that the canary record is recovered 100% intact. This proves both the backup process and the restoration pipeline work end-to-end."*
