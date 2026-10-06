# Demo Script (5–10 minutes)

Run in SQL Developer with `SET SERVEROUTPUT ON`. Commands are in
`sql/11_demo.sql`; this file adds **what to say**.

### 0. Setup (before the teacher arrives)
Run `sql/run_all.sql` (F5). Confirm `SETUP COMPLETE`.

### 1. Show the schema & data
*"14 tables in BCNF. Here are the active-term sections and their seats."*
```sql
SELECT section_id, course_code, capacity, enrolled_count, seats_available
FROM v_section_seats WHERE term_name='Winter 2026' ORDER BY section_id;
```

### 2. Successful registration
*"Arjun has no history; CS101 has no prerequisite, so this succeeds."*
```sql
BEGIN sp_register_student(6, 14); END;
/
```

### 3. Prerequisite rejection
*"Priya finished only CS101, not CS201, so CS301 is blocked by the database — not the app."*
```sql
BEGIN sp_register_student(5, 10); END;
/   -- ORA-20001
```

### 4. Timetable-clash rejection
*"Neil is already in section 10 (Mon 9:00–10:40). Section 11 overlaps it, so it's rejected."*
```sql
BEGIN sp_register_student(3, 11); END;
/   -- ORA-20002
```

### 5. Full section → waitlist
*"CS202 section 13 has capacity 2 and is full. Rehaan is eligible, so he's waitlisted, not rejected."*
```sql
BEGIN sp_register_student(2, 13); END;
/
SELECT * FROM v_waitlist_status WHERE section_id=13;
```

### 6. Drop → automatic promotion
*"Sanjay drops. The database frees the seat and automatically promotes the first eligible waitlisted student — Rehaan — after re-checking his prerequisites and timetable."*
```sql
BEGIN sp_drop_registration(4, 13); END;
/
SELECT reg_no, student_name, status FROM v_section_roster WHERE section_id=13;
```

### 7. Post grade → CGPA update
*"I grade Neil's CS301. A compound trigger recomputes his credit-weighted CGPA instantly."*
```sql
SELECT reg_no, cgpa FROM v_student_cgpa WHERE student_id=3;
BEGIN sp_post_grade(3, 10, 'A'); END;
/
SELECT reg_no, cgpa FROM v_student_cgpa WHERE student_id=3;
```

### 8. Transcript (cursor)
```sql
BEGIN sp_transcript(1); END;
/
```

### 9. Audit trail
*"Every status change — drop, promotion, completion — was logged automatically by a trigger, with who and when."*
```sql
SELECT reg_no, course_code, old_status, new_status, changed_by, changed_at
FROM v_enrollment_audit ORDER BY audit_id;
```

### 10. Analytics
```sql
SELECT faculty, sections, courses, total_registered
FROM v_faculty_teaching_load WHERE term_name='Winter 2026';
SELECT section_id, course_code, utilization_pct
FROM v_section_seats WHERE term_name='Winter 2026' ORDER BY utilization_pct DESC;
```

### 11. (Optional) Concurrency
Show `demo/README.md` — two SQL Developer sessions racing for the last seat; the
row lock serialises them so capacity is never exceeded.
