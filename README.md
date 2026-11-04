# CampusSafe: Campus Hazard & Safety Reporting System

[![PHP Version](https://img.shields.io/badge/PHP-8.2%2B-777BB4?logo=php&logoColor=white)](https://www.php.net/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-14%2B-336791?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Architecture](https://img.shields.io/badge/Architecture-MVC--Lite-0ea5e9)](#system-architecture)
[![Status](https://img.shields.io/badge/Activity_3-Ready_for_Testing-10b981)](#)

**COMP 018 Database Administration &bull; Group 7**  
A centralized, enterprise-grade campus safety and physical hazard reporting platform. Enables students, faculty, and campus staff to file safety hazard reports, allows safety administrators to verify and prioritize risks, and dispatches on-duty maintenance technicians to remediate hazards through an auditable 6-stage lifecycle.

---

## 1. System Overview & Key Features

CampusSafe implements all 10 core functional modules specified in the approved design:

1. **Configurable Database Connection:** Secure PDO singleton with `.env` configuration for custom hosts, ports (`5432` or `5433`), databases, and credentials.
2. **Robust Authentication & RBAC:** Secure login with `password_hash()` (bcrypt), session fixation protection (`session_regenerate_id`), and server-side role gating (`Auth::requireRole`).
3. **Hazard Report Submission:** Intuitive submission form with active category and location dropdowns, input validation, and transactional insertion of reports and status history.
4. **Photo & Document Attachments:** Secure multi-format file uploads (JPG, PNG, WEBP, PDF up to 5MB) with real MIME verification and unguessable random hashes.
5. **Admin Hazard Verification:** Real-time verification queue where administrators inspect submitted hazards, assign priority (`Low`, `Medium`, `High`, `Critical`), and record findings.
6. **Maintenance Dispatch & Assignment:** Dispatch interface allowing administrators to assign verified hazards to active maintenance personnel with work instructions.
7. **Technician Work Queue & Resolution:** Dedicated technician portal to accept work orders, log repair activities, and mark hazards resolved with verified timestamps.
8. **Advanced Search & Audit Timeline:** Multi-criteria search and filter (status, priority, category, location, date range) with complete status transition timelines.
9. **Interactive Safety Statistics:** Live dashboard visualizing hazard distribution by lifecycle status, severity level, category, and building.
10. **Administrative Master Data CRUD:** Management suites for users, hazard categories, and campus locations with soft deactivation (`is_active` / `account_status`).

---

## 2. Technology Stack & Prerequisites

- **Server-Side Language:** PHP 8.2 or higher
- **PHP Extensions Required:** `pdo`, `pdo_pgsql`, `pgsql`, `fileinfo`, `session`
- **Database Server:** PostgreSQL 14+ (Verified on PostgreSQL 14.24; compatible with PostgreSQL 15, 16, 17, and 18)
- **Web Server:** PHP Built-in Server (`php -S`) or Apache/Nginx

---

## 3. Installation Guide

### ⚡ Easy 1-Click Setup for Classmates (Recommended!)

No manual database creation, no terminal commands, and no manual `.env` editing required! Choose either method below:

#### Option A: Web Setup Wizard (Browser-Based)
1. **Double-click `start.bat`** in the project folder.
2. Your browser will automatically open to the **CampusSafe 1-Click Setup Wizard** (`http://localhost:8000/install.php`).
3. Check your PostgreSQL settings (defaults to `localhost:5432`, user `postgres`), type your password (default `postgres`), and click **"🚀 Run 1-Click Installation & Seed Database"**.
4. The wizard will automatically create the database, run all 3 SQL scripts, generate sample hazard photos, write `.env`, and provide a direct button to launch the portal!

#### Option B: Automated Batch Setup (Double-Click Script)
1. **Double-click `setup.bat`** in the project folder.
2. It automatically locates your PHP executable, verifies PostgreSQL extensions, connects to PostgreSQL, creates the database, and loads all schema and seed records.
3. When prompted, press Enter to immediately launch the local server (`start.bat`).

---

### 🛠️ Manual Installation Guide (For Advanced Users / Mac / Linux)

If you prefer to configure and run everything manually step-by-step:

### Step 1: Configure Environment Variables
Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```
*(On Windows PowerShell: `Copy-Item .env.example .env`)*

Edit `.env` to match your local PostgreSQL configuration:
```env
DB_HOST=localhost
# Use port 5433 if your PostgreSQL instance runs on 5433; otherwise 5432
DB_PORT=5432
DB_NAME=grp07_campussafedb
# Primary runtime account (Activity 4 least-privilege role)
DB_USER=campussafe_app
DB_PASSWORD=change_me_locally
# (Note: For initial script execution in Step 4, connect as the 'postgres' superuser).
```

### Step 2: Enable `pdo_pgsql` Extension in PHP
If not already enabled, open your `php.ini` file and uncomment the following lines (remove the leading `;`):
```ini
extension=pdo_pgsql
extension=pgsql
```
Verify the extension is active:
```bash
php -m | findstr pgsql
```

### Step 3: Create the PostgreSQL Database
Connect to PostgreSQL using `psql` and create the project database:
```sql
CREATE DATABASE grp07_campussafedb;
```

### Step 4: Run the Database Scripts in Order
Execute the three database scripts while connected to `grp07_campussafedb`:

> **⚠️ WARNING:** `01_schema.sql` drops existing tables and `02_seed.sql` truncates all rows. Only re-run these if you intend to perform a complete database wipe/reset!

```bash
# 1. Create tables, constraints, and indexes
psql -U postgres -h localhost -p 5432 -d grp07_campussafedb -f database/01_schema.sql

# 2. Populate realistic seed data across all 6 lifecycle stages
psql -U postgres -h localhost -p 5432 -d grp07_campussafedb -f database/02_seed.sql

# 3. Configure Activity 4 least-privilege roles and permissions
psql -U postgres -h localhost -p 5432 -d grp07_campussafedb -f database/03_roles_and_privileges.sql
```

#### Step 4b: Set Your Local Role Passwords
After running `03_roles_and_privileges.sql`, set secure local passwords for the newly created login accounts:
```sql
ALTER ROLE campussafe_app WITH PASSWORD 'your_secure_password';
ALTER ROLE campussafe_report WITH PASSWORD 'your_secure_password';
ALTER ROLE campussafe_backup WITH PASSWORD 'your_secure_password';
```
Then update `DB_PASSWORD=your_secure_password` in your `.env` file.

*(Optional: You can also run `php database/seed_users.php` to dynamically generate user password hashes based on `DEMO_PASSWORD` in your `.env` file).*

### Step 5: Start the Built-in Web Server
From the root directory of the project, launch the PHP web server targeting the `public/` directory:
```bash
php -S localhost:8000 -t public
```

Open your browser and navigate to: **[http://localhost:8000](http://localhost:8000)**

---

## 4. Pre-Configured Demo Accounts

All seed accounts share the standard demonstration password: **`Password123!`**  
*(Quick-click buttons on the login page will autofill these credentials for instant evaluation).*

| Role | Username | Email | Responsibilities & Test Scope |
|---|---|---|---|
| **Administrator** | `demo_admin` | `admin@campussafe.edu` | Full oversight: verification, assignment, user CRUD, master data, stats |
| **Maintenance Lead** | `demo_maint1` | `davis@campussafe.edu` | View assigned work, start jobs, log actions, mark hazards resolved |
| **Maintenance Tech** | `demo_maint2` | `reyes@campussafe.edu` | Work order execution and electrical repairs |
| **Student (Reporter)** | `demo_student` | `santos@campussafe.edu` | Submit reports, attach evidence, view own report history |
| **Faculty (Reporter)** | `demo_faculty` | `hernandez@campussafe.edu` | Submit academic hazards, view own reports |
| **Safety Auditor** | `demo_auditor` | `kim@campussafe.edu` | Read-only compliance inspection, incident registries, and analytics |

---

## 5. Directory Structure

```
├── .env.example                # Configuration template
├── .gitignore                  # Git ignore rules (.env, uploads/*, *.dump)
├── README.md                   # Primary project guide
├── HOW_IT_WORKS.md             # Comprehensive architecture and operation walkthrough
├── database/
│   ├── 01_schema.sql           # DDL: 9 tables, constraints, checks, indexes
│   ├── 02_seed.sql             # 16 realistic incidents covering all states
│   ├── 03_roles_and_privileges.sql # Activity 4 access control & grants
│   ├── 99_reset.sql            # Clean schema drop script
│   ├── seed_users.php          # Dynamic CLI bcrypt user seeder
│   └── verify.sql              # Database sanity verification queries
├── docs/
│   ├── user-roles.md           # Application roles -> Database roles mapping
│   ├── database.md             # Full Data Dictionary and constraint specs
│   ├── db-user-role-setup.md   # Activity 4 setup & test matrix
│   ├── testing-guide.md        # Comprehensive testing matrix & QA guide
│   ├── master-data-crud.md     # Master Data CRUD documentation & rationale
│   ├── troubleshooting.md      # Common errors and verified fixes
│   ├── erd.md                  # Entity-Relationship diagram in Mermaid & ASCII
│   └── architecture.md         # Layered MVC-lite system architecture
├── public/                     # Web root document directory
│   ├── index.php               # Portal dashboard & landing page
│   ├── login.php / logout.php  # Authentication with demo quick-switcher
│   ├── reports/                # Submit, inspect, search, and edit hazards
│   ├── admin/                  # Verification, assignment, stats, master CRUD
│   ├── maintenance/            # Technician work queue and progress logging
│   └── assets/                 # Custom responsive stylesheet & JavaScript
├── src/                        # Protected core application engine
│   ├── auth/                   # Auth.php (Session RBAC), Csrf.php (Defense)
│   ├── config/                 # Env.php (.env parser), Database.php (PDO)
│   ├── models/                 # Report, User, Assignment, Action, Attachment
│   └── helpers/                # Functions, XSS escaping, header, footer
├── uploads/                    # User file upload directory (.gitkeep)
├── db-access-control/          # Activity 4 peer evaluation folders
├── db-maintenance/             # Activity 5 maintenance & EXPLAIN queries
├── db-backup-recovery/         # Activity 6 backup scripts & recovery simulation
└── progress-report/            # Progress log, team split, AI usage declaration
```

---

## 6. How the Activities Connect

- **Activity 3 (Build & Deploy):** Complete, self-contained, reproducible codebase that can be cloned and run from this README alone.
- **Activity 4 (Access Control):** Uses `database/03_roles_and_privileges.sql` and `docs/db-user-role-setup.md` to enforce the Principle of Least Privilege.
- **Activity 5 (Maintenance & Health):** Uses `db-maintenance/README.md` to analyze queries (`EXPLAIN ANALYZE`), table bloat, and `VACUUM` / `ANALYZE`.
- **Activity 6 (Backup & Disaster Recovery):** Uses `db-backup-recovery/README.md` to perform `pg_dump -Fc` backups, calculate SHA-256 checksums, and conduct point-in-time disaster simulations.

---

## 7. Additional Documentation Links

- [How Does It Work? Detailed Deep-Dive](HOW_IT_WORKS.md)
- [Comprehensive Testing & QA Guide](docs/testing-guide.md)
- [Application Roles & Database Privileges](docs/user-roles.md)
- [Database Schema & Data Dictionary](docs/database.md)
- [Master Data CRUD Documentation](docs/master-data-crud.md)
- [Activity 4 Setup Instructions](docs/db-user-role-setup.md)
- [Troubleshooting & FAQ](docs/troubleshooting.md)
- [Entity-Relationship Diagram (ERD)](docs/erd.md)
- [System Architecture](docs/architecture.md)
- [Development Progress & AI Declaration](progress-report/PROGRESS_LOG.md)
