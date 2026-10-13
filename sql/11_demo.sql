-- =====================================================================
-- 11_demo.sql : Guided live demo (run statement-by-statement in SQL
-- Developer, F5 / "Run Script"). Matches docs/demo_script.md.
-- =====================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT -- 1) Current active-term sections and seats
SELECT section_id, course_code, capacity, enrolled_count, seats_available
  FROM v_section_seats WHERE term_name = 'Winter 2026' ORDER BY section_id;

PROMPT -- 2) SUCCESS: register Arjun (6) into CS101 sec 14
BEGIN sp_register_student(6, 14); END;
/

PROMPT -- 3) PREREQUISITE REJECTION: Priya (5) into CS301 sec 10 (no CS201)
BEGIN sp_register_student(5, 10);
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Rejected -> '||SQLERRM); END;
/

PROMPT -- 4) TIMETABLE CLASH: Neil (3) is in sec 10 (MON 09:00-10:40); try sec 11 (MON 09:30-10:30)
BEGIN sp_register_student(3, 11);
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Rejected -> '||SQLERRM); END;
/

PROMPT -- 5) FULL -> WAITLIST: Rehaan (2) into full CS202 sec 13
BEGIN sp_register_student(2, 13); END;
/
SELECT * FROM v_waitlist_status WHERE section_id = 13;

PROMPT -- 6) DROP -> AUTO PROMOTE: drop Sanjay (4) from sec 13; Rehaan promoted
BEGIN sp_drop_registration(4, 13); END;
/
SELECT reg_no, student_name, status FROM v_section_roster WHERE section_id = 13;

PROMPT -- 7) POST GRADE -> CGPA UPDATE: grade Neil (3) in CS301 sec 10 = 'A'
SELECT reg_no, cgpa FROM v_student_cgpa WHERE student_id = 3;
BEGIN sp_post_grade(3, 10, 'A'); END;
/
SELECT reg_no, cgpa FROM v_student_cgpa WHERE student_id = 3;

PROMPT -- 8) TRANSCRIPT (Ritvik, 1)
BEGIN sp_transcript(1); END;
/

PROMPT -- 9) AUDIT TRAIL
SELECT reg_no, course_code, old_status, new_status, changed_by, changed_at
  FROM v_enrollment_audit ORDER BY audit_id;

PROMPT -- 10) FACULTY LOAD + SEAT UTILIZATION
SELECT faculty, sections, courses, total_registered
  FROM v_faculty_teaching_load WHERE term_name = 'Winter 2026' ORDER BY faculty;
SELECT section_id, course_code, utilization_pct
  FROM v_section_seats WHERE term_name = 'Winter 2026' ORDER BY utilization_pct DESC;