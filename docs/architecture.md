# CampusSafe — System Architecture Document

**System:** CampusSafe: Campus Hazard & Safety Reporting System  
**Stack:** HTML5/CSS3/JavaScript &rarr; PHP 8.2 &rarr; PostgreSQL 14+  

---

## 1. High-Level Architecture Overview

CampusSafe employs a clean, layered **MVC-Lite** architecture designed for auditability, security, and portability:

```
[ Web Browser / Client ]
           │
           │ HTTP/HTTPS Request (GET / POST)
           ▼
[ public/ Web Root ] ───────────┐
  ├── index.php                 │ Static Asset Handling
  ├── login.php / logout.php    │ (CSS, JS, Uploaded Files)
  ├── reports/ (views & forms)  │
  ├── admin/ (dispatch & master)│
  └── maintenance/ (work orders)│
           │                    │
           ▼                    ▼
[ src/ Core Application Engine ]
  ├── auth/     ──> Auth.php (Session RBAC), Csrf.php (Token Validation)
  ├── config/   ──> Env.php (.env parser), Database.php (PDO Singleton)
  ├── models/   ──> Report, User, Assignment, Action, Attachment, Location, Category
  └── helpers/  ──> functions.php (XSS Escaping, Flash Alerts, File Upload)
           │
           │ PDO SQL via 'campussafe_app' (Least Privilege)
           ▼
[ PostgreSQL 14 Database ]
  ├── Tables & Relational Integrity (PK, FK, CASCADE)
  ├── Business Rule Constraints (CHECK chk_verified_pair, chk_resolved_has_date)
  └── Query Performance Indexes
```

---

## 2. Layer Responsibilities

### 2.1 Presentation & Routing Layer (`public/`)
- Acts as the web server's document root (`-t public`).
- Enforces user authentication and role guards at the entry of each page (`Auth::requireRole()`).
- Form submissions are verified against CSRF tokens before any controller action occurs (`Csrf::enforce()`).
- Separates presentation templates from database business logic.

### 2.2 Security & Authentication Layer (`src/auth/`)
- **Session Management:** Hardened session settings (`cookie_httponly`, `use_only_cookies`, `cookie_samesite = Lax`).
- **Session Fixation Prevention:** Calls `session_regenerate_id(true)` immediately upon credential verification.
- **Role Verification:** Evaluates role access against authenticated database roles. Unauthorized access triggers an immediate `403 Forbidden` exit.
- **CSRF Defense:** Generates cryptographically secure 32-byte pseudo-random tokens validated using constant-time string comparisons (`hash_equals()`).

### 2.3 Domain Model & Data Access Layer (`src/models/`)
- Encapsulates all SQL logic. **Zero direct SQL queries are written in view templates.**
- Employs 100% prepared statements with parameterized input bindings to eliminate SQL injection.
- Multi-step operations (e.g. creating a report + first status history, or verifying a report + setting priority) are executed inside atomic PDO transactions (`beginTransaction()`, `commit()`, `rollBack()`).

### 2.4 Configuration & Infrastructure Layer (`src/config/`)
- **`Env.php`:** Lightweight `.env` reader that loads environment variables without requiring external dependencies (like Composer).
- **`Database.php`:** Singleton connection factory that manages a persistent PDO handle configured with `PDO::ERRMODE_EXCEPTION` and emulated prepares disabled.

---

## 3. Request Lifecycle

1. **Client Request:** User requests a page or submits a form.
2. **Bootstrapping:** The endpoint includes `Database.php`, `Auth.php`, `functions.php`, and relevant models.
3. **Authentication Guard:** `Auth::requireRole()` checks if `$_SESSION['user']` is active and holds the appropriate role. If not, the request terminates.
4. **CSRF Enforcement:** On POST requests, `Csrf::enforce()` validates `csrf_token`.
5. **Model Execution:** The model executes parameterized SQL inside a transaction if necessary.
6. **Flash & Redirect:** On completion, a flash alert is queued, and the user is redirected via HTTP 302, preventing duplicate submissions on page refresh (PRG pattern).
