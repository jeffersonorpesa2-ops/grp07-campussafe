# CampusSafe — Database Schema & Data Dictionary

**Database Name:** `grp07_campussafedb`  
**RDBMS:** PostgreSQL 14+ (Verified on PostgreSQL 14.24)  
**Schema:** `public`  
**Group:** Group 7 &bull; COMP 018 Database Administration  

---

## 1. Overview & Entity Relationship Summary

The CampusSafe relational schema consists of 9 core tables designed to model campus safety incident reporting, administrative classification, maintenance dispatching, and audit logging.

```
[role] 1 ────< [app_user] 1 ────< [hazard_report] 1 ────< [assignment]
                     │                   │  1              │
                     │                   │  └────< [attachment]
                     │                   │  1
                     │                   │  └────< [maintenance_action]
                     │                   │  1
                     │                   │  └────< [report_status_history]
                     │                   │
                     ├───────────────────┼──── [campus_location] (M:1)
                     │                   │
                     └───────────────────┴──── [hazard_category] (M:1)
```

---

## 2. Table Data Dictionaries

### 2.1 `role`
Defines system authorization levels.

| Column | Data Type | Nullable | Default | Constraints | Description |
|---|---|---|---|---|---|
| `role_id` | `SERIAL` | No | Auto | `PRIMARY KEY` | Unique role identifier |
| `role_name` | `VARCHAR(50)` | No | — | `UNIQUE` | Role name (`Student`, `Faculty/Staff`, `Maintenance`, `Administrator`, `Auditor`) |
| `description` | `TEXT` | Yes | `NULL` | — | Role scope and responsibilities |

---

### 2.2 `app_user`
Stores account profiles, credentials, and account statuses. Table is explicitly named `app_user` to avoid the PostgreSQL reserved keyword `user`.

| Column | Data Type | Nullable | Default | Constraints | Description |
|---|---|---|---|---|---|
| `user_id` | `SERIAL` | No | Auto | `PRIMARY KEY` | Unique user identifier |
| `role_id` | `INT` | No | — | `REFERENCES role(role_id)` | Foreign key linking user to role |
| `full_name` | `VARCHAR(150)` | No | — | — | First and last name of individual |
| `email` | `VARCHAR(255)` | No | — | `UNIQUE` | Institutional campus email |
| `username` | `VARCHAR(100)` | No | — | `UNIQUE` | Unique system sign-in handle |
| `password_hash` | `TEXT` | No | — | — | Bcrypt password hash |
| `account_status` | `VARCHAR(20)` | No | `'active'` | `CHECK (account_status IN ('active','inactive','suspended'))` | Account access status |
| `created_at` | `TIMESTAMP` | No | `CURRENT_TIMESTAMP` | — | Account creation timestamp |

---

### 2.3 `hazard_category`
Master catalog of hazard classifications.

| Column | Data Type | Nullable | Default | Constraints | Description |
|---|---|---|---|---|---|
| `category_id` | `SERIAL` | No | Auto | `PRIMARY KEY` | Unique category identifier |
| `category_name` | `VARCHAR(80)` | No | — | `UNIQUE` | Category title (e.g., Electrical, Sanitation) |
| `description` | `TEXT` | Yes | `NULL` | — | Examples and classification scope |
| `is_active` | `BOOLEAN` | No | `TRUE` | — | Soft deletion flag |

---

### 2.4 `campus_location`
Physical campus facilities, floors, and specific rooms.

| Column | Data Type | Nullable | Default | Constraints | Description |
|---|---|---|---|---|---|
| `location_id` | `SERIAL` | No | Auto | `PRIMARY KEY` | Unique location identifier |
| `building` | `VARCHAR(120)` | No | — | — | Campus building or facility name |
| `floor` | `VARCHAR(30)` | Yes | `NULL` | — | Floor level (e.g., 3rd Floor, Basement) |
| `room_area` | `VARCHAR(120)` | No | — | — | Specific room or landmark |
| `location_description` | `TEXT` | Yes | `NULL` | — | Nearby landmarks or navigational aids |
| `is_active` | `BOOLEAN` | No | `TRUE` | — | Soft deletion flag |

---

### 2.5 `hazard_report`
Core incident reporting entity.

| Column | Data Type | Nullable | Default | Constraints | Description |
|---|---|---|---|---|---|
| `report_id` | `SERIAL` | No | Auto | `PRIMARY KEY` | Unique report number |
| `reporter_user_id` | `INT` | No | — | `REFERENCES app_user(user_id)` | User who filed the report |
| `location_id` | `INT` | No | — | `REFERENCES campus_location(location_id)` | Physical hazard location |
| `category_id` | `INT` | No | — | `REFERENCES hazard_category(category_id)` | Hazard classification |
| `description` | `TEXT` | No | — | — | Detailed explanation of risk |
| `priority` | `VARCHAR(20)` | **Yes** | `NULL` | `CHECK (priority IN ('Low','Medium','High','Critical'))` | Risk level (`NULL` until verified by admin) |
| `status` | `VARCHAR(30)` | No | `'Submitted'` | `CHECK (status IN ('Submitted','Verified','Assigned','In Progress','Resolved','Closed'))` | Lifecycle state |
| `submitted_at` | `TIMESTAMP` | No | `CURRENT_TIMESTAMP` | — | Submission timestamp |
| `verified_by_user_id` | `INT` | Yes | `NULL` | `REFERENCES app_user(user_id)` | Administrator who verified report |
| `verified_at` | `TIMESTAMP` | Yes | `NULL` | — | Timestamp of verification |
| `resolved_at` | `TIMESTAMP` | Yes | `NULL` | — | Timestamp of physical repair |

#### Table Constraints:
1. `chk_verified_pair`:
   ```sql
   CHECK (
       (verified_by_user_id IS NULL AND verified_at IS NULL) OR
       (verified_by_user_id IS NOT NULL AND verified_at IS NOT NULL)
   )
   ```
   *Guarantees a report cannot have a verifier recorded without a verification timestamp, or vice-versa.*

2. `chk_resolved_has_date`:
   ```sql
   CHECK (
       status NOT IN ('Resolved', 'Closed') OR resolved_at IS NOT NULL
   )
   ```
   *Guarantees reports in Resolved or Closed status always retain an explicit timestamp of resolution.*

---

### 2.6 `assignment`
Technician dispatch records.

| Column | Data Type | Nullable | Default | Constraints | Description |
|---|---|---|---|---|---|
| `assignment_id` | `SERIAL` | No | Auto | `PRIMARY KEY` | Unique assignment record ID |
| `report_id` | `INT` | No | — | `REFERENCES hazard_report(report_id) ON DELETE CASCADE` | Associated hazard report |
| `maintenance_user_id` | `INT` | No | — | `REFERENCES app_user(user_id)` | Assigned technician |
| `assigned_by_user_id` | `INT` | No | — | `REFERENCES app_user(user_id)` | Administrator making assignment |
| `assigned_at` | `TIMESTAMP` | No | `CURRENT_TIMESTAMP` | — | Dispatch timestamp |
| `assignment_status` | `VARCHAR(20)` | No | `'Assigned'` | `CHECK (assignment_status IN ('Assigned','In Progress','Completed','Cancelled'))` | Work status |

#### Table Constraints:
- `UNIQUE (report_id, maintenance_user_id)`: Prevents assigning the same maintenance technician to the same report multiple times.

---

### 2.7 `report_status_history`
Append-only audit trail tracking every transition of a hazard report.

| Column | Data Type | Nullable | Default | Constraints | Description |
|---|---|---|---|---|---|
| `history_id` | `SERIAL` | No | Auto | `PRIMARY KEY` | Unique history record ID |
| `report_id` | `INT` | No | — | `REFERENCES hazard_report(report_id) ON DELETE CASCADE` | Associated hazard report |
| `changed_by_user_id` | `INT` | No | — | `REFERENCES app_user(user_id)` | User triggering status change |
| `status` | `VARCHAR(30)` | No | — | `CHECK (status IN ('Submitted','Verified','Assigned','In Progress','Resolved','Closed'))` | Target status |
| `changed_at` | `TIMESTAMP` | No | `CURRENT_TIMESTAMP` | — | Transition timestamp |
| `notes` | `TEXT` | Yes | `NULL` | — | Transition commentary or reason |

---

### 2.8 `maintenance_action`
Detailed log of physical repair actions taken by technicians.

| Column | Data Type | Nullable | Default | Constraints | Description |
|---|---|---|---|---|---|
| `action_id` | `SERIAL` | No | Auto | `PRIMARY KEY` | Unique action record ID |
| `report_id` | `INT` | No | — | `REFERENCES hazard_report(report_id) ON DELETE CASCADE` | Associated hazard report |
| `maintenance_user_id` | `INT` | No | — | `REFERENCES app_user(user_id)` | Technician performing work |
| `action_details` | `TEXT` | No | — | — | Description of repair or mitigation |
| `action_date` | `TIMESTAMP` | No | `CURRENT_TIMESTAMP` | — | Action timestamp |
| `is_resolution` | `BOOLEAN` | No | `FALSE` | — | `TRUE` if action permanently resolves hazard |
| `notes` | `TEXT` | Yes | `NULL` | — | Parts, tools, or follow-up notes |

---

### 2.9 `attachment`
Photo or document evidence files.

| Column | Data Type | Nullable | Default | Constraints | Description |
|---|---|---|---|---|---|
| `attachment_id` | `SERIAL` | No | Auto | `PRIMARY KEY` | Unique attachment ID |
| `report_id` | `INT` | No | — | `REFERENCES hazard_report(report_id) ON DELETE CASCADE` | Associated hazard report |
| `uploaded_by_user_id` | `INT` | No | — | `REFERENCES app_user(user_id)` | Uploader ID |
| `file_name` | `VARCHAR(255)` | No | — | — | Original client filename |
| `file_path_or_url` | `TEXT` | No | — | — | Server file path under `uploads/` |
| `mime_type` | `VARCHAR(100)` | Yes | `NULL` | — | Verified MIME content type |
| `uploaded_at` | `TIMESTAMP` | No | `CURRENT_TIMESTAMP` | — | Upload timestamp |

---

## 3. Performance Indexes

PostgreSQL does **not** automatically index foreign key columns. The following indexes were created to support foreign key lookups and frequent filter queries:

| Index Name | Table | Columns | Query Optimization Benefit |
|---|---|---|---|
| `idx_report_reporter` | `hazard_report` | `reporter_user_id` | Accelerates user self-service "My Reports" view |
| `idx_report_location` | `hazard_report` | `location_id` | Accelerates location filtering and spatial joins |
| `idx_report_category` | `hazard_report` | `category_id` | Accelerates hazard category filtering |
| `idx_report_status` | `hazard_report` | `status` | Speeds up admin queue filters (`Submitted`, `Verified`) |
| `idx_report_submitted` | `hazard_report` | `submitted_at DESC` | Optimizes chronological timeline ordering |
| `idx_assign_report` | `assignment` | `report_id` | Speeds up lookup of assignments for reports |
| `idx_assign_maint` | `assignment` | `maintenance_user_id` | Accelerates maintenance technician work queues |
| `idx_history_report` | `report_status_history` | `report_id` | Speeds up audit timeline rendering on view page |
| `idx_action_report` | `maintenance_action` | `report_id` | Optimizes action history lookup |
| `idx_attach_report` | `attachment` | `report_id` | Optimizes evidence attachment retrieval |
