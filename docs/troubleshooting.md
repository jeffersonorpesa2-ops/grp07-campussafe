# CampusSafe — Troubleshooting & Common Issues Guide

This guide provides tested solutions to the most common configuration and runtime errors encountered when deploying CampusSafe.

> **💡 Fast Fix for Classmates:** You can bypass manual configuration entirely by double-clicking **`setup.bat`** or opening **`http://localhost:8000/install.php`** which automatically verifies PHP drivers, creates the database, and populates all demo tables with sample data.

---

## 1. PHP Extension: `pdo_pgsql` Driver Not Found

### Symptoms:
- Web page shows `could not find driver` or `Class "PDO" error`.
- Running `php -m` does not list `pdo_pgsql`.

### Cause:
The PostgreSQL PDO driver is installed in PHP's `ext/` folder but disabled in `php.ini`.

### Solution:
1. Open your active `php.ini` file (e.g. in XAMPP: `E:\xampp\php\php.ini` or `C:\xampp\php\php.ini`).
2. Search for `pdo_pgsql`.
3. Remove the leading semicolon `;` from both lines:
   ```ini
   extension=pdo_pgsql
   extension=pgsql
   ```
4. Save the file and restart your PHP built-in server or Apache.
5. Verify via CLI:
   ```bash
   php -m | findstr pgsql
   ```
   *Output must show:*
   ```
   pdo_pgsql
   pgsql
   ```

---

## 2. PostgreSQL Port Discrepancy (Port 5432 vs. 5433)

### Symptoms:
- `Connection refused` (error 10061 / 2002).
- Cannot reach PostgreSQL server.

### Cause:
Workstations running both PostgreSQL 14 and newer versions (15, 16, 17, or 18) often map instance 14 to port **5433** and instance 17/18 to **5432**.

### Solution:
Check your local PostgreSQL port in `postgresql.conf` or using PowerShell:
```powershell
Get-NetTCPConnection -State Listen | Where-Object { $_.LocalPort -in 5432, 5433 }
```
Then update `.env` to match your active port:
```env
DB_PORT=5433
```

---

## 3. Password Authentication Failed for User `campussafe_app`

### Symptoms:
- `FATAL: password authentication failed for user "campussafe_app"`

### Cause:
The password in `.env` differs from the password assigned in `database/03_roles_and_privileges.sql`.

### Solution:
1. Reset the role password in `psql` as superuser:
   ```sql
   ALTER ROLE campussafe_app WITH PASSWORD 'my_secure_local_password';
   ```
2. Set the exact same value in `.env`:
   ```env
   DB_USER=campussafe_app
   DB_PASSWORD=my_secure_local_password
   ```

---

## 4. `permission denied for sequence ..._seq`

### Symptoms:
- Submitting a report or creating a user produces:
  `ERROR: permission denied for sequence hazard_report_report_id_seq`

### Cause:
PostgreSQL manages auto-incrementing serial values through internal sequences. In PostgreSQL 14+, granting `INSERT` on a table does **not** automatically grant sequence access.

### Solution:
Connect as database owner/superuser and execute:
```sql
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_runtime_grp;
```

---

## 5. `permission denied for table ...`

### Symptoms:
- `ERROR: permission denied for table hazard_report`

### Cause:
The connecting account does not have sufficient DML privileges or `PUBLIC` schema permissions were revoked.

### Solution:
Verify that your database user is a member of `app_runtime_grp`:
```sql
GRANT app_runtime_grp TO campussafe_app;
GRANT USAGE ON SCHEMA public TO app_runtime_grp;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO app_runtime_grp;
```

---

## 6. Uploads Folder Not Writable

### Symptoms:
- `Failed to move uploaded file to destination storage`

### Cause:
The `uploads/` directory lacks write permissions or does not exist.

### Solution:
1. Verify the `uploads/` directory exists in the project root:
   ```powershell
   Test-Path uploads
   ```
2. Grant write permissions on Windows / Linux:
   - **Windows:** Right click `uploads` folder &rarr; Properties &rarr; Security &rarr; Ensure your current user has Modify/Write permissions.
   - **Linux/macOS:** `chmod -R 775 uploads/`

---

## 7. Role Already Exists When Re-running Scripts

### Symptoms:
- `ERROR: role "app_runtime_grp" already exists`

### Cause:
PostgreSQL roles are cluster-wide (global) objects, not tied to a single database. Re-running a script containing raw `CREATE ROLE` causes duplicate name errors.

### Solution:
Use our pre-configured `database/03_roles_and_privileges.sql` script, which contains defensive `DO $$ BEGIN IF NOT EXISTS (...) END $$;` blocks that safely skip existing roles.
