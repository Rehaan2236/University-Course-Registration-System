-- Quick copy-paste demo (same as sql/11_demo.sql). Run with SET SERVEROUTPUT ON.
SET SERVEROUTPUT ON SIZE UNLIMITED
BEGIN sp_register_student(6, 14); END;             -- success
/
BEGIN sp_register_student(5, 10); EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE(SQLERRM); END;  -- prereq fail
/
BEGIN sp_register_student(3, 11); EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE(SQLERRM); END;  -- clash
/
BEGIN sp_register_student(2, 13); END;             -- waitlist
/
BEGIN sp_drop_registration(4, 13); END;            -- drop -> promote
/
BEGIN sp_post_grade(3, 10, 'A'); END;              -- grade -> CGPA
/
BEGIN sp_transcript(1); END;                       -- transcript
/
SELECT * FROM v_enrollment_audit ORDER BY audit_id;
