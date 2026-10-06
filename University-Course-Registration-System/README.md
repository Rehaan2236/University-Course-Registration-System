# University Course Registration and Academic Records Management System

**Course:** BCSE302P – Database Systems Lab · Slot D2 (L11+L12)
**Team:** Ritvik Battula (24BAI0156) · Rehaan Bahadur (24BCE2295) · Neil Ajith Nair (24BCE2301)
**Database:** Oracle Database XE (Relational RDBMS + PL/SQL)

A database-centric course-registration system. **All academic rules live inside
Oracle** — constraints, triggers, stored procedures/functions, cursors,
transactions and row-level locking. Any interface is a thin client that only
calls stored logic and reads views.

---

## 1. Project overview
Students register into course *sections* that have limited seats, prerequisite
chains and fixed time slots. The database enforces seat capacity, prerequisite
completion and timetable-clash rules, maintains a waitlist with automatic
promotion, posts grades, computes credit-weighted CGPA, generates transcripts
and keeps an audit trail — correctly even under concurrent registration.

## 2. Features
- Prerequisite checking (supports multiple prerequisites and chains)
- Timetable-clash prevention (overlapping time slots in the same term)
- Seat-capacity enforcement; full section → waitlist
- Concurrent "last seat" protection via `SELECT ... FOR UPDATE` row locking
- Waitlist with position ordering and automatic promotion on drop
- Enrollment audit trail (trigger-based)
- Credit-weighted CGPA, auto-recomputed when grades change
- Transcript generation (explicit cursor)
- Analytical views/reports (seats, utilization, faculty load, etc.)

## 3. Technology stack
Oracle Database XE 18c/21c · SQL + PL/SQL · (optional) Python 3 + `python-oracledb`.

## 4. Prerequisites
- Oracle Database XE installed and running (or any Oracle 18c/21c instance)
- Oracle SQL Developer (recommended) **or** SQL*Plus
- (optional) Python 3.8+ if you want to use the CLI

## 5. Create / connect to the database
Oracle XE ships with a pluggable database `XEPDB1`. Create a dedicated schema user:

```sql
-- Connect in SQL Developer as SYSTEM to service XEPDB1, then:
CREATE USER ucrs_user IDENTIFIED BY ucrs_pass;
GRANT CONNECT, RESOURCE TO ucrs_user;
ALTER USER ucrs_user QUOTA UNLIMITED ON USERS;
```
Then make a SQL Developer connection:
- Name: `UCRS`  · Username: `ucrs_user`  · Password: `ucrs_pass`
- Hostname: `localhost` · Port: `1521` · Service name: `XEPDB1`

> You *can* instead run everything as an existing user; a clean user is tidier.

## 6/7/8. Execute the scripts (exact order)
**Easiest — one shot:**
1. Open SQL Developer, connect as `ucrs_user`.
2. Open `sql/run_all.sql`.
3. Press **F5** (Run Script). It runs 00→08 in order and prints `SETUP COMPLETE`.
   *(Run it from the `sql/` folder so the `@@` relative paths resolve. In
   SQL Developer, the folder of the opened file is used automatically.)*

**Manual — if you prefer step by step** (open each file, press **F5**):
```
00_cleanup.sql        -- drop old objects (safe on first run)
01_create_tables.sql  -- tables + PK/UNIQUE/CHECK
02_constraints.sql    -- foreign keys
03_sequences.sql      -- surrogate-key sequences
04_sample_data.sql    -- demo data
05_functions.sql      -- context package + functions
06_procedures.sql     -- PL/SQL API
07_triggers.sql       -- triggers + derived-column resync
08_views.sql          -- reporting views
```

## 9. Load sample data
Included — it is step `04_sample_data.sql` above. Six students, four faculty,
seven courses with a prerequisite chain (CS101→CS201→CS301→CS401), two terms,
and pre-built scenarios (a full section, completed history, etc.).

## 10. Test the system
Enable output then run the test script:
```
SET SERVEROUTPUT ON
```
Open `sql/10_tests.sql`, press **F5**. Nine tests (success + failure cases) print
their results and expected outcomes. See docs/demo_script.md for what each proves.

## 11. Run the demo scenarios
Open `sql/11_demo.sql`, press **F5** (with `SET SERVEROUTPUT ON`). It walks the
full 10-step presentation. The spoken script is in `docs/demo_script.md`.

## 12. View reports
Open `sql/09_reports.sql` and run the query you want (A–K), e.g. seat utilization,
faculty load, "students who meet prerequisites but haven't registered", recursive
prerequisite chain.

## 13. Generate a transcript
```sql
SET SERVEROUTPUT ON
BEGIN sp_transcript(1); END;
/
```
(or `SELECT * FROM v_student_transcript WHERE reg_no='24BAI0156';`)

## 14. Demonstrate prerequisite rejection
```sql
-- Student 5 (Priya) has not completed CS201, so CS301 (section 10) is rejected:
BEGIN sp_register_student(5, 10); END;
/
-- Expect: ORA-20001 Prerequisites not completed.
```

## 15. Demonstrate timetable clash
```sql
-- Student 3 is in section 10 (MON 09:00-10:40). Section 11 is MON 09:30-10:30:
BEGIN sp_register_student(3, 11); END;
/
-- Expect: ORA-20002 Timetable clash.
```

## 16. Demonstrate waitlist promotion
```sql
BEGIN sp_register_student(2, 13); END;   -- section 13 is full -> Rehaan waitlisted
/
BEGIN sp_drop_registration(4, 13); END;  -- Sanjay drops -> Rehaan auto-promoted
/
SELECT reg_no, student_name, status FROM v_section_roster WHERE section_id=13;
```

## 17. Demonstrate CGPA calculation
```sql
SELECT reg_no, cgpa FROM v_student_cgpa WHERE student_id=3;  -- before
BEGIN sp_post_grade(3, 10, 'A'); END;                        -- grade CS301
/
SELECT reg_no, cgpa FROM v_student_cgpa WHERE student_id=3;  -- after (recomputed)
```

## 18. Troubleshooting
- **ORA-00942 table/view does not exist** on first cleanup → normal; `00_cleanup`
  ignores missing objects.
- **Nothing prints from procedures** → run `SET SERVEROUTPUT ON` in that worksheet.
- **`@@` file not found when running run_all** → open/run it from inside the
  `sql/` folder, or run the numbered files manually.
- **ORA-01017 invalid username/password** → check the user from step 5 and the
  service name `XEPDB1`.
- **Re-running** → just run `run_all.sql` again; `00_cleanup` resets everything.
- **Concurrency demo appears to "hang"** → that is the lock working; the second
  session is waiting. Commit/rollback the first session to release it.

## 19. Project structure
See `PROJECT_STRUCTURE.md` for the file tree and the design decisions/corrections.

---
### Mark-scheme coverage (Assessment 6 design → implementation)
| Rubric area | Where |
|---|---|
| Problem & objectives | README §1–2, docs/project_overview.md |
| Requirement analysis | docs/project_overview.md |
| DB selection & justification | docs/database_design.md |
| Data-model design | sql/01, sql/02, docs/database_design.md, diagrams/er_diagram.mmd |
