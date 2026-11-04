# CampusSafe — Master Data CRUD Documentation

**System:** CampusSafe: Campus Hazard & Safety Reporting System  
**Course:** COMP 018 Database Administration &bull; Group 7  
**Module:** Administrative Master Data Management (Activity 3 Deliverable)  

---

## 1. Definition: Master Data vs. Transactional Data

| Data Classification | Description | CampusSafe Tables |
|---|---|---|
| **Master Reference Data** | Core reference entities that provide context for operational reporting. They have a long lifecycle and are maintained by Administrators. | `hazard_category`<br>`campus_location`<br>`app_user`<br>`role` |
| **Transactional Data** | Dynamic incident records generated during daily campus operations, which reference Master Data through Foreign Keys. | `hazard_report`<br>`assignment`<br>`report_status_history`<br>`maintenance_action`<br>`attachment` |

---

## 2. Why Soft Deactivation is Used Instead of Hard Deletion

A primary database administration requirement in CampusSafe is **Referential Integrity Preservation**:
- If an administrator were to execute a hard SQL delete (`DELETE FROM campus_location WHERE location_id = 1`), any historical hazard reports referencing that location would either fail due to foreign key restrictions (`RESTRICT`) or be destroyed if set to cascade.
- **Solution (Soft Deactivation):** Instead of deleting records, CampusSafe utilizes boolean status flags (`is_active = TRUE/FALSE`) and account statuses (`active`, `inactive`, `suspended`).
  - Inactive locations and categories are excluded from dropdowns on `/reports/new.php` via `WHERE is_active = TRUE`.
  - Historical reports, statistics, and audit timelines remain 100% intact.

---

## 3. Master Data CRUD Matrix & Test Evidence

### 3.1 Campus Locations (`campus_location`)
- **Route:** `public/admin/locations.php`
- **Model:** `src/models/Location.php`

| CRUD Operation | Method / Action | SQL Operation Performed | Validation & Constraints |
|---|---|---|---|
| **Create** | Form submit `action=create` | `INSERT INTO campus_location (building, floor, room_area, location_description, is_active) VALUES (...)` | `building` and `room_area` cannot be empty. |
| **Read** | Page load `Location::getAll()` | `SELECT * FROM campus_location ORDER BY building, floor, room_area` | Displays all locations with active/inactive badges. |
| **Update** | Form submit `action=update` | `UPDATE campus_location SET building = :b, floor = :f, room_area = :r, ... WHERE location_id = :id` | Updates fields while preserving `location_id`. |
| **Delete (Soft)** | Button submit `action=toggle_active` | `UPDATE campus_location SET is_active = NOT is_active WHERE location_id = :id` | Toggles availability without destroying linked reports. |

---

### 3.2 Hazard Categories (`hazard_category`)
- **Route:** `public/admin/categories.php`
- **Model:** `src/models/Category.php`

| CRUD Operation | Method / Action | SQL Operation Performed | Validation & Constraints |
|---|---|---|---|
| **Create** | Form submit `action=create` | `INSERT INTO hazard_category (category_name, description, is_active) VALUES (...)` | `category_name` must be unique (`UNIQUE`). |
| **Read** | Page load `Category::getAll()` | `SELECT * FROM hazard_category ORDER BY category_name` | Lists all hazard classifications. |
| **Update** | Form submit `action=update` | `UPDATE hazard_category SET category_name = :n, description = :d WHERE category_id = :id` | Renames or updates scope description. |
| **Delete (Soft)** | Button submit `action=toggle_active` | `UPDATE hazard_category SET is_active = NOT is_active WHERE category_id = :id` | Soft-deactivates category from report dropdown. |

---

### 3.3 User Accounts (`app_user`)
- **Route:** `public/admin/users.php`
- **Model:** `src/models/User.php`

| CRUD Operation | Method / Action | SQL Operation Performed | Validation & Constraints |
|---|---|---|---|
| **Create** | Form submit `action=create` | `INSERT INTO app_user (role_id, full_name, email, username, password_hash, account_status) VALUES (...)` | `username` and `email` must be unique; passwords hashed with bcrypt. |
| **Read** | Page load `User::getAll()` | `SELECT u.*, r.role_name FROM app_user u JOIN role r ON ...` | Lists users, roles, and status tags. |
| **Update** | Form submit `action=update` | `UPDATE app_user SET full_name = :f, email = :e, role_id = :r WHERE user_id = :id` | Profile and role modification. |
| **Delete (Soft)** | Status toggle `action=toggle_status` | `UPDATE app_user SET account_status = :status WHERE user_id = :id` | Sets `inactive` or `suspended`; prevents self-deactivation. |

---

## 4. Evidence Checklist for PDF Progress Report

When preparing your Activity 3 PDF progress report, take screenshots of:
1. `public/admin/categories.php`: Creating a new category and toggling its status.
2. `public/admin/locations.php`: Creating a new campus building/room.
3. `public/admin/users.php`: Adding a new technician account and editing user roles.
4. `public/reports/new.php`: Showing that deactivated categories or locations no longer appear in the reporting dropdown.
