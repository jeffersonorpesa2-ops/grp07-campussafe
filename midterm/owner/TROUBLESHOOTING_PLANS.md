# COMP 018 Midterm Examination - Troubleshooting Plans (Owner Role)

**Project Under Defense:** CampusSafe: Campus Hazard & Safety Reporting System  
**Defending Group:** Group 7 (Jefferson Orpesa Lead, Alba, Arreza, Robiso, Santos)  
**Assigned Designer Group:** `[TO BE FILLED LIVE BASED ON PROFESSOR ASSIGNMENT]`  
**Target Disposable Database:** `grp07_campussafedb_disposable`  

---

## 🛠️ Step 0: Disposable Database Spin-Up Protocol (RUN FIRST)
Before touching any incident or applying any fault script, Group 7 executes this single command to spin up an isolated disposable copy:

```powershell
# In PowerShell / Command Prompt
createdb -U postgres -h localhost -p 5432 -T grp07_campussafedb grp07_campussafedb_disposable
```
*Note: `-T grp07_campussafedb` creates an instant, exact clone of the primary database without altering live data.*

---

## Troubleshooting Plan & Incident Resolution Template

Copy this template for each of the 5 incidents released by your peer designer group:

---

### Incident #[X]: [Brief Title from Peer Group]

#### 1. Incident Brief & Reported Symptoms (Public Brief)
- **Incident ID:** `[e.g., GXX-INC1]`
- **Reported Symptoms:** `[Exact quote from peer group brief]`
- **Reported Affected Area:** `[Privileges / Objects / Performance / Maintenance / Backup]`

#### 2. Baseline Comparison & Evidence Gathered
- **Baseline Document Reference:** Activities 3, 4, 5, or 6
- **Observed Deviations from Baseline:**
  - `[Run owner_diagnostic_suite.sql]`
  - Output observed: `[Attach exact SQL / error output]`

#### 3. Hypotheses Formulated
- **Hypothesis A (Primary):** `[Explanation linked to evidence]`
- **Hypothesis B (Alternative):** `[Alternative explanation]`
- **Testing & Ruling Out:** `[How Hypothesis B was disproven]`

#### 4. Planned Corrective Action
- **Target Account Used:** `[e.g., campussafe_dba or postgres for schema fix - NO unnecessary superuser]`
- **Risk Assessment:** `[Risks of the change]`
- **Rollback Option:** `[How to undo if it fails]`

#### 5. Execution of Corrective Action
```sql
-- [Exact SQL command(s) executed on grp07_campussafedb_disposable]
```

#### 6. Verification & Regression Testing
- **Positive Test (Fix Proven):** `[Query / command that now succeeds]`
- **Negative Test (Least Privilege Preserved):** `[Unauthorized command that is still denied]`
- **Application Test:** `[Web portal functionality verified]`

#### 7. Root Cause Statement & Classification
- **Confirmed Root Cause:** `[Definitive cause supported by evidence]`
- **Responsible Area:** `[DBA / Application Developer / System Administrator / Network]`
- **Resolution Status:** `RESOLVED (100%)`

#### 8. Preventive Recommendation
- **Operational / Architecture Improvement:** `[Specific preventive measure to stop recurrence]`

---

## ⚡ Quick-Lookup Emergency Fix Catalog for CampusSafe

If the designer group attacks any of these common areas, here are the exact surgical fixes:

| Attacked Vector | Observed Symptom | Quick Diagnostic Query | Surgical Corrective Action (Fix) |
|---|---|---|---|
| **Sequence Revocation** | `permission denied for sequence ...` on `INSERT` | `SELECT * FROM information_schema.role_usage_grants;` | `GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_runtime_grp;` |
| **Table Revocation** | `permission denied for table ...` | `SELECT * FROM information_schema.role_table_grants WHERE grantee='app_runtime_grp';` | `GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO app_runtime_grp;` |
| **Sequence Desync** | `duplicate key value violates unique constraint "hazard_report_pkey"` | `SELECT last_value FROM hazard_report_report_id_seq; SELECT MAX(report_id) FROM hazard_report;` | `SELECT setval('hazard_report_report_id_seq', (SELECT MAX(report_id) FROM hazard_report));` |
| **Dropped View** | `relation "v_user_directory" does not exist` | `\dv` in psql | Re-run view creation from `database/03_roles_and_privileges.sql` and grant to `app_readonly_grp`. |
| **Dropped Index** | High query latency (> 3s), sequential scan | `EXPLAIN (ANALYZE, BUFFERS) SELECT ...` | `CREATE INDEX idx_hazard_report_status ON hazard_report(status); ANALYZE hazard_report;` |
| **Table Bloat / Dead Tuples** | Stale stats, bad planner row estimates | `SELECT relname, n_dead_tup FROM pg_stat_user_tables;` | `VACUUM (VERBOSE, ANALYZE) hazard_report;` |
| **Backup Role Revocation** | `pg_dump` fails with permission denied | `SELECT rolname FROM pg_roles WHERE rolname='campussafe_backup';` | `GRANT pg_read_all_data TO campussafe_backup;` |
| **Active Lock Blocker** | Query hangs indefinitely | `SELECT pid, state, query FROM pg_stat_activity WHERE state != 'idle';` | `SELECT pg_terminate_backend(<pid>);` |
