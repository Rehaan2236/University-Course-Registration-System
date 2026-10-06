-- =====================================================================
-- 10_tests.sql : Functional test script. Run as a whole with
-- SET SERVEROUTPUT ON. Failure cases are wrapped so the script continues
-- and prints the expected error. Re-run 00..08 first for a clean state.
-- =====================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT ############ TEST 1: valid registration (student 6 -> CS101 sec 14) ############
-- Expected: REGISTERED (CS101 has no prerequisites, seats free).
BEGIN sp_register_student(6, 14); END;
/
SELECT status FROM enrollment WHERE student_id = 6 AND section_id = 14;  -- expect REGISTERED

PROMPT ############ TEST 2: prerequisite rejection (student 5 -> CS301 sec 10) ############
-- Student 5 completed only CS101, not CS201. Expected: ORA-20001 rejection.
BEGIN
  sp_register_student(5, 10);
  DBMS_OUTPUT.PUT_LINE('!! UNEXPECTED: registration succeeded');
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('OK expected rejection -> '||SQLERRM);
END;
/

PROMPT ############ TEST 3: timetable clash (student 3 already in sec 10, try sec 11) ############
-- Sec 10 slot MON 09:00-10:40 overlaps sec 11 slot MON 09:30-10:30. Expected: ORA-20002.
BEGIN
  sp_register_student(3, 11);
  DBMS_OUTPUT.PUT_LINE('!! UNEXPECTED: registration succeeded');
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('OK expected rejection -> '||SQLERRM);
END;
/

PROMPT ############ TEST 4: full section -> waitlist (student 2 -> CS202 sec 13) ############
-- Sec 13 capacity 2, already full (students 3,4). Expected: WAITLISTED.
BEGIN sp_register_student(2, 13); END;
/
SELECT position FROM waitlist WHERE student_id = 2 AND section_id = 13;  -- expect 1

PROMPT ############ TEST 5: drop -> automatic waitlist promotion ############
-- Drop student 4 from sec 13; student 2 (waitlist pos 1) should be promoted.
BEGIN sp_drop_registration(4, 13); END;
/
SELECT status FROM enrollment WHERE student_id = 2 AND section_id = 13;        -- expect REGISTERED
SELECT COUNT(*) AS wl_remaining FROM waitlist WHERE section_id = 13;           -- expect 0

PROMPT ############ TEST 6: post grade -> CGPA updates ############
-- CGPA of student 3 before vs after grading CS301 (sec 10) with 'A'.
SELECT cgpa AS cgpa_before FROM student WHERE student_id = 3;
BEGIN sp_post_grade(3, 10, 'A'); END;
/
SELECT cgpa AS cgpa_after FROM student WHERE student_id = 3;   -- expect higher / recomputed

PROMPT ############ TEST 7: audit trail recorded ############
-- Expected: rows for the drop (REGISTERED->DROPPED), promotion (->REGISTERED),
-- and completion (REGISTERED->COMPLETED) created above.
SELECT reg_no, course_code, old_status, new_status, changed_by
  FROM v_enrollment_audit ORDER BY audit_id;

PROMPT ############ TEST 8: capacity invariant never violated ############
-- Expected: NO rows returned (enrolled_count never exceeds capacity).
SELECT section_id, enrolled_count, capacity
  FROM section WHERE enrolled_count > capacity;

PROMPT ############ TEST 9: duplicate registration blocked ############
BEGIN
  sp_register_student(6, 14);   -- already registered in TEST 1
  DBMS_OUTPUT.PUT_LINE('!! UNEXPECTED: duplicate allowed');
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('OK expected rejection -> '||SQLERRM);
END;
/

PROMPT ############ TESTS COMPLETE ############
