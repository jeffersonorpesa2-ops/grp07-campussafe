# CampusSafe — Development Progress Log & Team Deliverables

**Course:** COMP 018 Database Administration  
**Project:** CampusSafe: Campus Hazard & Safety Reporting System  
**Group:** Group 7  

---

## 1. Team Member Roles & Focus Areas

| Member Name | Assigned Focus | Key Deliverables |
|---|---|---|
| **Member 1** | Database Architecture & Administration | Schema DDL (`01_schema.sql`), Seed data (`02_seed.sql`), Constraints, Reset scripts, Activity 4 Roles Script |
| **Member 2** | Backend Security & Transactions | Authentication (`Auth.php`), Session RBAC, CSRF defense, Transactional status transitions (`Report.php`) |
| **Member 3** | Administration & Maintenance Modules | Verification queue (`verify.php`), Dispatch assignments (`assign.php`), Master data CRUD (`users.php`, `categories.php`, `locations.php`) |
| **Member 4** | Technician Portal & Reporting UI | Frontend UI design (`style.css`, `app.js`), Work order resolution (`update.php`), Search & filter (`list.php`), Attachments |
| **Member 5** | Documentation, Quality Assurance & QA Testing | README, System Architecture, Troubleshooting guide, Backup strategy (Activity 6), PDF progress reporting |

---

## 2. Activity 3 Development Milestones & Progress Log

| Date | Phase | Task Description | Responsible | Commit Reference | Status |
|---|---|---|---|---|---|
| Day 1 | Phase 1 | Repository scaffolding, `.gitignore`, `.env.example`, folder structure setup | Member 5 | `feat: initialize project scaffolding and env template` | COMPLETED |
| Day 1 | Phase 2 | Schema design, table creation, foreign keys with cascade rules, check constraints | Member 1 | `feat: implement 01_schema.sql with constraints and indexes` | COMPLETED |
| Day 1 | Phase 2 | Seed data generation covering all 6 lifecycle states and realistic campus incidents | Member 1 | `feat: add 02_seed.sql and dynamic user seeder` | COMPLETED |
| Day 2 | Phase 3 | Database PDO singleton, lightweight environment loader, CSRF validation engine | Member 2 | `feat: implement Database singleton and CSRF security guard` | COMPLETED |
| Day 2 | Phase 3 | Session authentication, password hashing with bcrypt, role-based authorization | Member 2 | `feat: add Auth session manager with RBAC guards` | COMPLETED |
| Day 2 | Phase 3 | Hazard report submission with category/location dropdowns and secure file upload | Member 2 & 4 | `feat: build report submission form with validation` | COMPLETED |
| Day 3 | Phase 3 | Admin verification queue, priority assignment, verifier pair constraints | Member 3 | `feat: implement admin verification and priority workflow` | COMPLETED |
| Day 3 | Phase 3 | Maintenance dispatch queue, technician assignment logic, assignment constraints | Member 3 | `feat: create maintenance assignment dispatch module` | COMPLETED |
| Day 3 | Phase 3 | Maintenance technician work orders, action logging, resolution timestamping | Member 4 | `feat: add maintenance action logging and resolution form` | COMPLETED |
| Day 4 | Phase 3 | Advanced search and filter, date range filter, student self-service isolation | Member 4 | `feat: build search, filtering and report detail timeline` | COMPLETED |
| Day 4 | Phase 3 | Master data CRUD for users, categories, and campus locations with soft deactivation | Member 3 | `feat: implement administrative master data management` | COMPLETED |
| Day 4 | Phase 3 | Safety analytics dashboard with KPI cards and distribution progress bars | Member 4 | `feat: add safety statistics and analytics dashboard` | COMPLETED |
| Day 5 | Phase 4 | Activity 4 roles script, Activity 5 maintenance plan, Activity 6 disaster recovery guide | Member 1 & 5 | `docs: add comprehensive activities 3-6 documentation` | COMPLETED |

---

## 3. Responsible AI Usage Statement (Graded Rubric Requirement)

| Date | AI Tool Utilized | Specific Task Prompted | Modifications & Fixes Made by Team | Verified By |
|---|---|---|---|---|
| Day 1 | Gemini / Antigravity | Schema constraint drafting and table generation | Verified PostgreSQL 14 compatibility; added explicit `chk_verified_pair` and `chk_resolved_has_date` constraints; ensured `ON DELETE CASCADE` rules aligned with business requirements. | Member 1 |
| Day 2 | Gemini / Antigravity | PDO transaction pattern boilerplate for multi-table status transitions | Reviewed exception handling; added explicit row locking (`FOR UPDATE`) to prevent race conditions during concurrent admin reviews. | Member 2 |
| Day 3 | Gemini / Antigravity | CSS styles for modern accessible interface, responsive cards, and timeline | Customized color scheme to match campus brand; refined contrast ratios for accessibility compliance. | Member 4 |
| Day 4 | Gemini / Antigravity | Documentation drafting for troubleshooting and Activity 4-6 plans | Audited PostgreSQL commands for exact syntax; replaced hardcoded ports with `.env` references; ensured no real passwords exist in documentation. | Member 5 |

**AI Ethics Declaration:** All AI-assisted code was manually inspected, line-by-line reviewed for SQL injection, authenticated role checks, cross-site scripting vulnerabilities, and relational schema integrity prior to team sign-off.
