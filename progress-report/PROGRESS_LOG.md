# CampusSafe & Peer Evaluation — Master Development Progress Log

**Course:** COMP 018 — Database Administration  
**Project:** CampusSafe: Campus Hazard & Safety Reporting System  
**Evaluating Group:** Group 7 (Alba, Arreza, Orpesa, Robiso, Santos)  
**Repository:** [https://github.com/jeffersonorpesa2-ops/grp07-campussafe](https://github.com/jeffersonorpesa2-ops/grp07-campussafe)  
**Status:** All Activities 1 to 6 & 8 Peer Evaluations Fully Complete (100/100)  

---

## 1. Team Member Roles & Focus Areas

| Member Name | Assigned Focus | Key Primary Deliverables | Peer Evaluation Focus |
|---|---|---|---|
| **Jefferson Orpesa** (Lead) | Database Architecture & Administration | Schema DDL (`01_schema.sql`), Seed data (`02_seed.sql`), Table Constraints, Reset scripts, Activity 4 Roles Script | RBAC architecture design, privilege matrix formulation, and cross-database boundary lockdown |
| **Alba** | Backend Security & Transactions | Authentication (`Auth.php`), Session RBAC, CSRF defense, Transactional status transitions (`Report.php`) | Verification test suites (Test Suites 1, 2, and 3), security auditing, password hash shielding views |
| **Arreza** | Administration & Maintenance Modules | Verification queue (`verify.php`), Dispatch assignments (`assign.php`), Master data CRUD (`users.php`, `categories.php`, `locations.php`) | Table bloat inspection (`pg_stat_user_tables`), vacuuming/analyzing, and query optimization (`EXPLAIN ANALYZE BUFFERS`) |
| **Robiso** | Technician Portal & Reporting UI | Frontend UI design (`style.css`, `app.js`), Work order resolution (`update.php`), Search & filter (`list.php`), Attachments | Backup strategy execution (`pg_dump -Fc`), TOC verification, and SHA-256 checksum generation |
| **Santos** | Quality Assurance, Recovery & QA Testing | Documentation, System Architecture, Troubleshooting guide, Backup strategy (Activity 6), PDF progress reporting | Restoration verification (`pg_restore`), record parity audits, and Canary disaster recovery drills |

---

## 2. CampusSafe Internal Milestones (Activities 1 – 6)

| Milestone | Phase | Description | Deliverables | Status |
|---|---|---|---|---|
| **Activity 1** | Requirements & Proposal | Campus safety domain definition, user stories, stakeholder requirements, and functional scope. | Project Proposal, Requirements Matrix | COMPLETED |
| **Activity 2** | Relational Modeling & Schema | ER modeling, normalization to 3NF, table constraints, foreign key cascades, and check constraints. | ERD, Data Dictionary, `01_schema.sql` | COMPLETED |
| **Activity 3** | Application Implementation | Full MVC-lite PHP web portal with 10 functional modules, session auth, CSRF defense, and file uploads. | Full Web Application, 1-Click Setup, Seed Data | COMPLETED |
| **Activity 4** | Access Control & Security | Multi-tier RBAC (`app_runtime_grp`, `app_readonly_grp`, `app_backup_grp`), password hash masking, and isolation. | `03_roles_and_privileges.sql`, `db-access-control/` | COMPLETED |
| **Activity 5** | Maintenance & Query Tuning | Server health checks, table statistics, VACUUM/ANALYZE automation, and `EXPLAIN (ANALYZE, BUFFERS)` indexing. | `db-maintenance/`, Performance Audit | COMPLETED |
| **Activity 6** | Backup & Disaster Recovery | RPO 24h / RTO 2h backup strategy, custom-format binary dump, SHA-256 verification, and disaster simulation. | `db-backup-recovery/`, Canary Drill | COMPLETED |

---

## 3. Peer Evaluation Master Tracker (Activities 4, 5, and 6)

Group 7 conducted rigorous, hands-on, live-engine Database Administration evaluations for **8 classmate project teams** on PostgreSQL 18.6:

| Target Group | Target Project Name | Target Repository | Scope Evaluated | Report Document Link | Evaluation Status |
|---|---|---|---|---|---|
| **Group 4** | BrewPOS: Coffee Shop Point-of-Sale System | [BrewPOS Repository](https://github.com/Nycri/brewpos) | Activities 4, 5, 6 | [`GROUP_04_BREWPOS_EVALUATION_REPORT.md`](file:///E:/programming%20project/Data%20Ad/progress-report/GROUP_04_BREWPOS_EVALUATION_REPORT.md) | **100/100 COMPLETED** |
| **Group 2** | Park-It: Smart Parking Lot Management System | [Park-It Repository](https://github.com/HelloP0/PARK-IT-DATABASE-MANAGEMENT-SYSTEM) | Activities 4, 5, 6 | [`GROUP_02_PARKIT_EVALUATION_REPORT.md`](file:///E:/programming%20project/Data%20Ad/progress-report/GROUP_02_PARKIT_EVALUATION_REPORT.md) | **100/100 COMPLETED** |
| **Group 3** | Project OJT RMA: Internship Management System | [OJT RMA Repository](https://github.com/swvenz/Project-OJT-RMA-System.git) | Activities 4, 5, 6 | [`GROUP_03_OJT_RMA_EVALUATION_REPORT.md`](file:///E:/programming%20project/Data%20Ad/progress-report/GROUP_03_OJT_RMA_EVALUATION_REPORT.md) | **100/100 COMPLETED** |
| **Group 5** | Lost & Found Management System | [grp05_lostandfound](https://github.com/grp05-dba/grp05_lostandfound) | Activities 4, 5, 6 | [`GROUP_05_LOSTANDFOUND_EVALUATION_REPORT.md`](file:///E:/programming%20project/Data%20Ad/progress-report/GROUP_05_LOSTANDFOUND_EVALUATION_REPORT.md) | **100/100 COMPLETED** |
| **Group 6** | HabalGo: Motorcycle Ride-Hailing Platform | [HabalGo Repository](https://github.com/jeanaroyo/HabalGo) | Activities 4, 5, 6 | [`GROUP_06_HABALGO_EVALUATION_REPORT.md`](file:///E:/programming%20project/Data%20Ad/progress-report/GROUP_06_HABALGO_EVALUATION_REPORT.md) | **100/100 COMPLETED** |
| **Group 8** | bwisIT Solutions: Campus Canteen Pre-Order System | [Campus Canteen Repository](https://github.com/EclipseChan/bwisIT-Solutions---Campus-Canteen-Pre-Order-and-Queue-Management-System) | Activities 4, 5, 6 | [`GROUP_08_CANTEEN_EVALUATION_REPORT.md`](file:///E:/programming%20project/Data%20Ad/progress-report/GROUP_08_CANTEEN_EVALUATION_REPORT.md) | **100/100 COMPLETED** |
| **Group 10** | Binary Sisters: Restaurant Online Ordering & Table Reservation | [Restaurant System](https://github.com/kathlenmaecallos11-arch/Restaurant-Online-Ordering-Table-Reservation-System) | Activities 4, 5, 6 | [`GROUP_10_RESTAURANT_EVALUATION_REPORT.md`](file:///E:/programming%20project/Data%20Ad/progress-report/GROUP_10_RESTAURANT_EVALUATION_REPORT.md) | **100/100 COMPLETED** |
| **Group 11** | BoardTrack: Boarding House & Rental Management System | [BoardTrack Repository](https://github.com/karlrobertc-art/BoardTrack.git) | Activities 4, 5, 6 | [`GROUP_11_BOARDTRACK_EVALUATION_REPORT.md`](file:///E:/programming%20project/Data%20Ad/progress-report/GROUP_11_BOARDTRACK_EVALUATION_REPORT.md) | **100/100 COMPLETED** |

---

## 4. Responsible AI Usage Statement (Activities 1 – 6)

| Phase / Date | AI Tool Utilized | Specific Task Prompted | Human Validation & Modifications Made by Team | Verified By |
|---|---|---|---|---|
| **Activity 1 & 2** | Gemini / Antigravity | Relational schema constraint drafting and table generation | Verified PostgreSQL 14+ compatibility; added explicit `chk_verified_pair` and `chk_resolved_has_date` constraints; ensured cascade rules align with business requirements. | Jefferson Orpesa |
| **Activity 3** | Gemini / Antigravity | PDO transaction pattern boilerplate for status transitions & CSRF | Reviewed exception handling; added explicit row locking (`FOR UPDATE`) to prevent race conditions during concurrent admin reviews. | Alba |
| **Activity 4** | Antigravity AI Assistant | Role-Based Access Control matrix formulation, security view generation, and least-privilege testing scripts | Verified role segregation, verified that financial tables (`payment`, `order_item`, `lease`) have `DELETE` revoked; tested cross-database isolation against `grp07_campussafedb`. | Alba & Orpesa |
| **Activity 5** | Antigravity AI Assistant | `EXPLAIN (ANALYZE, BUFFERS)` execution plan extraction, dead tuple bloat calculation, and indexing strategy | Executed all `VACUUM` and `ANALYZE` commands live on PostgreSQL 18.6; verified 0 dead tuples post-vacuum; validated index query speedups. | Arreza |
| **Activity 6** | Antigravity AI Assistant | Backup automation script formatting, TOC parser, SHA-256 generation, and canary drill script structure | Ran live `pg_dump -Fc` and `pg_restore` into separate restore test databases; computed physical SHA-256 hashes; executed live canary disaster drills. | Robiso & Santos |

**AI Ethics Declaration:** All AI-assisted code was manually inspected, line-by-line reviewed for SQL injection, authenticated role checks, cross-site scripting vulnerabilities, and relational schema integrity prior to team sign-off.

---

## 5. Master Issues & Resolutions Table

| # | Problem Encountered | Root Cause | Technical Resolution Applied |
|---|---|---|---|
| **1** | `Database Connection Error: could not find driver (SQLSTATE[08006])` | PHP CLI launched without an active `php.ini` file; PostgreSQL PDO drivers (`pdo_pgsql`, `pgsql`) were not loaded. | Created `D:\php\php.ini`, configured `extension_dir = "ext"`, enabled `extension=pdo_pgsql` and `extension=pgsql`, and restarted the server. |
| **2** | `Database Connection Error: FATAL: password authentication failed for user "postgres"` | Template `.env` password (`DB_PASSWORD=postgres`) mismatched local PostgreSQL master credentials. | Synchronized local environment configuration by updating `DB_PASSWORD` in `.env` to match the local workstation credentials. |
| **3** | Port conflict between PostgreSQL 14 and PostgreSQL 18 (Port 5432 vs. 5433) | Workstation had multiple PostgreSQL versions installed with different listening ports. | Used `Get-NetTCPConnection` to identify active port 5432, parameterized `DB_PORT` in `.env`, and updated connection DSN. |
| **4** | `Permission denied for sequence ..._seq` when inserting records using runtime account | In PostgreSQL, granting `INSERT` on a table does not automatically grant `USAGE` / `SELECT` on its auto-increment sequence. | Added explicit sequence grant: `GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO <group_role>;`. |
| **5** | Password hash exposure in read-only / auditor reporting queries | Granting direct `SELECT` on user credential tables (`app_user`, `customer`, `staff`, `accounts`) exposes bcrypt hashes. | Created sanitized security views (`v_user_directory`, `v_customer_directory`, `v_staff_directory`) that omit password hashes, granting `SELECT` on views while withholding direct table access. |
| **6** | Trigger-induced dead tuple bloat in tables with automated status sync | Inserting leases/orders triggers automated status updates on parent rooms/tables, producing high MVCC dead tuple bloat. | Scheduled routine automated `VACUUM (VERBOSE, ANALYZE)` operations, reducing dead tuples from 35+ down to exactly 0. |
| **7** | Accidental financial ledger or contract deletion via runtime account | Default full CRUD grants allow web application code to delete historical payments, lease agreements, or line items. | Enforced strict Least Privilege: granted `SELECT, INSERT, UPDATE` while strictly withholding `DELETE` on financial ledgers (`payment`, `order_item`, `lease`). |
| **8** | Sequence out-of-sync error after manual or seed ID insertions | Explicit primary key insertions during testing/seeding do not advance PostgreSQL serial sequences. | Executed `SELECT setval(pg_get_serial_sequence('...', '...'), (SELECT MAX(...) FROM ...));` post-seed and verified in post-restore suite. |
| **9** | Cross-database access breach in shared PostgreSQL cluster | Default `PUBLIC` role possessed `CONNECT` privilege on cluster databases, allowing accounts to connect to other groups' databases. | Executed `REVOKE CONNECT ON DATABASE <db> FROM PUBLIC;` and granted `CONNECT` exclusively to designated group roles. |
