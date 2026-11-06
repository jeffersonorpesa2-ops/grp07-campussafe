# Activity 4: Access Control Plan — Group OJT-RMA (OJT Management System Evaluation)

**Evaluating Group:** Group 7 (Alba, Arreza, Orpesa, Robiso, Santos)  
**Target Group:** OJT RMA Team (`https://github.com/swvenz/Project-OJT-RMA-System`)  
**Target Project:** OJT Management System (`Project-OJT-RMA-System`)  
**Database:** `ojt_managementdb` (PostgreSQL 18.6)  

---

## 1. Access-Control Architecture & PoLP Design

The OJT Management System is a Java-based enterprise application managing student internship placements, company partnerships, daily attendance logs, requirement submissions, and supervisor performance evaluations. In default configurations where application backends connect using the superuser `postgres`, any software flaw, connection leak, or SQL injection vulnerability exposes student academic data, supervisor credentials, and allows malicious falsification of student attendance and evaluation scores.

To safeguard system integrity, we designed and implemented a three-tier Role-Based Access Control (RBAC) architecture enforcing the **Principle of Least Privilege (PoLP)**:

- **Group Roles (`NOLOGIN`):** `ojt_runtime_grp`, `ojt_readonly_grp`, `ojt_backup_grp`.
- **Login Accounts (`LOGIN`):** `ojt_app`, `ojt_report`, `ojt_backup`.
- **Attendance Log Immutability:** `ojt_app` is granted `SELECT, INSERT, UPDATE` on `attendance` (allowing time-in and time-out updates), but `DELETE` privileges are strictly denied to preserve audit integrity and prevent falsification of completed OJT hours.
- **Evaluation Record Tamper Protection:** `ojt_app` can insert and read `evaluations`, but `DELETE` privileges are denied.
- **Credential Protection:** `ojt_report` is granted read-only `SELECT` on student, company, placement, attendance, and evaluation records, but is **explicitly denied `SELECT` on `users`** to prevent exposure of user passwords and authentication tokens to analytics or reporting interfaces.
- **Administrative & Cluster Isolation:** Non-administrative accounts are revoked from creating databases or accessing other group databases on the cluster (`REVOKE CONNECT ON DATABASE grp07_campussafedb FROM PUBLIC;`).

---

## 2. Access Control Matrix

| Login Account | Group Role (NOLOGIN) | Application Role Served | Responsibilities | Assigned Privileges | Technical Justification |
|---|---|---|---|---|---|
| `ojt_app` | `ojt_runtime_grp` | Java Application Runtime | Manages student profiles, company supervisor links, placement applications, requirement tracking, and attendance logs | • `CONNECT` on `ojt_managementdb`<br>• `USAGE` on schema `public`<br>• `SELECT, INSERT, UPDATE, DELETE` on `students`, `companies`, `academic_supervisors`, `company_supervisors`, `requirements`, `student_requirements`, `ojt_applications`, `ojt_placements`<br>• `SELECT, INSERT, UPDATE` on `attendance`<br>• `SELECT, INSERT, UPDATE` on `evaluations`<br>• `SELECT, INSERT, UPDATE` on `users`<br>• `USAGE, SELECT` on all sequences | Allows operational day-to-day internship workflows while strictly denying deletion of verified attendance logs, evaluation scores, or core user accounts. Prevents DDL tampering. |
| `ojt_report` | `ojt_readonly_grp` | Academic Dean / OJT Coordinator Auditor | Analyzes internship progress, rendered hours completion, and student evaluations across companies | • `CONNECT` on `ojt_managementdb`<br>• `USAGE` on schema `public`<br>• `SELECT` on `students`, `companies`, `ojt_placements`, `attendance`, `evaluations`, `requirements`, `student_requirements`<br>*(No access to `users`)* | Grants transparent access to internship performance metrics while completely isolating user password hashes and credentials from reporting endpoints. |
| `ojt_backup` | `ojt_backup_grp` | Backup Operator | Executes logical backups (`pg_dump -Fc`) | • `CONNECT` on `ojt_managementdb`<br>• `USAGE` on schema `public`, `lending`<br>• `SELECT` on all tables & sequences | Grants non-destructive read access required for consistent cluster backups without any DML or DDL privileges. |
| `postgres` | *(Superuser)* | Database Administrator | Schema provisioning, indexing, maintenance, disaster recovery drills | Superuser / Owner privileges | Reserved strictly for administrative maintenance and disaster recovery operations. Never exposed in runtime application configurations. |
