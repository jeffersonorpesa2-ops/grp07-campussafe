# COMP 018 Midterm Examination - Flaw Register (Designer Role)

**Evaluating Group:** Group 7 (CampusSafe)  
**Assigned Project:** `[TO BE FILLED LIVE BASED ON PROFESSOR ASSIGNMENT]`  
**Target Repository:** `[PEER GITHUB URL]`  
**Database Engine:** PostgreSQL 18.6 on x86_64 Windows  

---

## Flaw Register Table

| Flaw ID | Owning Group & Project | Reported By | Area & Activity | Flaw Description & Evidence Link | Severity | Owner Status | Recommended Fix |
|---|---|---|---|---|---|---|---|
| **FLAW-01** | `[Assigned Group]` | Group 7 | Access Control (Activity 4) | Direct runtime role lacks explicit `USAGE, SELECT` privileges on identity sequences, causing `INSERT` failures when not connected as superuser. | Medium | Open | Execute `GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO <app_role>;`. |
| **FLAW-02** | `[Assigned Group]` | Group 7 | Relational Schema & Security (Activity 3/4) | User credential table (`app_user` / `accounts`) exposes bcrypt password hashes to read-only/auditor roles without an abstraction view. | High | Open | Create security view `v_user_directory` selecting non-sensitive columns and grant `SELECT` only on the view. |
| **FLAW-03** | `[Assigned Group]` | Group 7 | Query Performance & Maintenance (Activity 5) | Missing partial/composite index on high-frequency status lookup columns (`status = 'PENDING'`), forcing full sequential scan with stale table statistics. | Medium | Open | Create targeted index `CREATE INDEX idx_status ON ...` and execute `VACUUM (VERBOSE, ANALYZE)`. |
| **FLAW-04** | `[Assigned Group]` | Group 7 | Backup & Recovery (Activity 6) | Dedicated backup account lacks global read-only privileges (`pg_read_all_data`), causing `pg_dump` failures when run under least privilege. | High | Open | Grant `pg_read_all_data` to the dedicated backup service account (`GRANT pg_read_all_data TO <backup_role>;`). |
| **FLAW-05** | `[Assigned Group]` | Group 7 | Concurrency & Data Integrity (Activity 2/3) | Primary key sequence counter desynchronization risk if seed scripts manually insert explicit IDs without updating sequence current values. | Low / Risk | Open | Execute `SELECT setval('<seq_name>', (SELECT MAX(id) FROM <table>));` after bulk data migrations. |

---

### Quick Peer Mapping (If Assigned to One of Our 8 Pre-Evaluated Peers)

If the professor assigns one of the 8 groups Group 7 already audited:
- **Group 2 (Park-It):** [`GROUP_02_PARKIT_EVALUATION_REPORT.md`](file:///E:/programming%20project/Data%20Ad/progress-report/GROUP_02_PARKIT_EVALUATION_REPORT.md)
- **Group 3 (OJT RMA):** [`GROUP_03_OJT_RMA_EVALUATION_REPORT.md`](file:///E:/programming%20project/Data%20Ad/progress-report/GROUP_03_OJT_RMA_EVALUATION_REPORT.md)
- **Group 4 (BrewPOS):** [`GROUP_04_BREWPOS_EVALUATION_REPORT.md`](file:///E:/programming%20project/Data%20Ad/progress-report/GROUP_04_BREWPOS_EVALUATION_REPORT.md)
- **Group 5 (Lost & Found):** [`GROUP_05_LOSTANDFOUND_EVALUATION_REPORT.md`](file:///E:/programming%20project/Data%20Ad/progress-report/GROUP_05_LOSTANDFOUND_EVALUATION_REPORT.md)
- **Group 6 (HabalGo):** [`GROUP_06_HABALGO_EVALUATION_REPORT.md`](file:///E:/programming%20project/Data%20Ad/progress-report/GROUP_06_HABALGO_EVALUATION_REPORT.md)
- **Group 8 (Campus Canteen):** [`GROUP_08_CANTEEN_EVALUATION_REPORT.md`](file:///E:/programming%20project/Data%20Ad/progress-report/GROUP_08_CANTEEN_EVALUATION_REPORT.md)
- **Group 10 (Restaurant):** [`GROUP_10_RESTAURANT_EVALUATION_REPORT.md`](file:///E:/programming%20project/Data%20Ad/progress-report/GROUP_10_RESTAURANT_EVALUATION_REPORT.md)
- **Group 11 (BoardTrack):** [`GROUP_11_BOARDTRACK_EVALUATION_REPORT.md`](file:///E:/programming%20project/Data%20Ad/progress-report/GROUP_11_BOARDTRACK_EVALUATION_REPORT.md)
