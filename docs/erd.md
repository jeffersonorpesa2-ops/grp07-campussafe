# CampusSafe — Entity Relationship Diagram (ERD)

**System:** CampusSafe: Campus Hazard & Safety Reporting System  
**Database:** `grp07_campussafedb`  

---

## 1. Mermaid Entity-Relationship Diagram

```mermaid
erDiagram
    ROLE ||--o{ APP_USER : "authorizes"
    APP_USER ||--o{ HAZARD_REPORT : "files"
    CAMPUS_LOCATION ||--o{ HAZARD_REPORT : "locates"
    HAZARD_CATEGORY ||--o{ HAZARD_REPORT : "classifies"
    APP_USER ||--o{ HAZARD_REPORT : "verifies"
    HAZARD_REPORT ||--o{ ASSIGNMENT : "assigned via"
    APP_USER ||--o{ ASSIGNMENT : "dispatched to"
    APP_USER ||--o{ ASSIGNMENT : "dispatched by"
    HAZARD_REPORT ||--o{ REPORT_STATUS_HISTORY : "tracks"
    APP_USER ||--o{ REPORT_STATUS_HISTORY : "logged by"
    HAZARD_REPORT ||--o{ MAINTENANCE_ACTION : "remediated via"
    APP_USER ||--o{ MAINTENANCE_ACTION : "performed by"
    HAZARD_REPORT ||--o{ ATTACHMENT : "evidenced by"
    APP_USER ||--o{ ATTACHMENT : "uploaded by"

    ROLE {
        int role_id PK
        string role_name UK
        text description
    }

    APP_USER {
        int user_id PK
        int role_id FK
        string full_name
        string email UK
        string username UK
        text password_hash
        string account_status
        timestamp created_at
    }

    HAZARD_CATEGORY {
        int category_id PK
        string category_name UK
        text description
        boolean is_active
    }

    CAMPUS_LOCATION {
        int location_id PK
        string building
        string floor
        string room_area
        text location_description
        boolean is_active
    }

    HAZARD_REPORT {
        int report_id PK
        int reporter_user_id FK
        int location_id FK
        int category_id FK
        text description
        string priority
        string status
        timestamp submitted_at
        int verified_by_user_id FK
        timestamp verified_at
        timestamp resolved_at
    }

    ASSIGNMENT {
        int assignment_id PK
        int report_id FK
        int maintenance_user_id FK
        int assigned_by_user_id FK
        timestamp assigned_at
        string assignment_status
    }

    REPORT_STATUS_HISTORY {
        int history_id PK
        int report_id FK
        int changed_by_user_id FK
        string status
        timestamp changed_at
        text notes
    }

    MAINTENANCE_ACTION {
        int action_id PK
        int report_id FK
        int maintenance_user_id FK
        text action_details
        timestamp action_date
        boolean is_resolution
        text notes
    }

    ATTACHMENT {
        int attachment_id PK
        int report_id FK
        int uploaded_by_user_id FK
        string file_name
        text file_path_or_url
        string mime_type
        timestamp uploaded_at
    }
```

---

## 2. Cardinality and Referential Rules Summary

1. **`app_user` &rarr; `hazard_report` (1:N):**
   - A user may submit 0 or many hazard reports.
   - Every report must have exactly one reporter (`reporter_user_id NOT NULL REFERENCES app_user(user_id)`).
   - Deletion of an `app_user` with existing reports is restricted (preventing orphan records).

2. **`hazard_report` &rarr; `assignment` (1:N):**
   - A report may have multiple assignments over time if escalated or transferred, but only one active assignment per technician (`UNIQUE (report_id, maintenance_user_id)`).
   - `ON DELETE CASCADE`: If a test report is purged, its assignments are automatically removed.

3. **`hazard_report` &rarr; `report_status_history` (1:N):**
   - Every report has at least one status history entry created on initial submission (`Submitted`), plus one entry for each transition.
   - `ON DELETE CASCADE`.

4. **`hazard_report` &rarr; `maintenance_action` (1:N):**
   - A report in progress records technician logs; final action has `is_resolution = TRUE`.
   - `ON DELETE CASCADE`.

5. **`hazard_report` &rarr; `attachment` (1:N):**
   - Reports can contain multiple photo/document attachments.
   - `ON DELETE CASCADE`.
