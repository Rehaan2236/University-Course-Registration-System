-- =====================================================================
-- 00_cleanup.sql : Drop all project objects so setup can be re-run.
-- Safe on an empty schema (missing objects are ignored).
-- =====================================================================
SET SERVEROUTPUT ON
BEGIN
  FOR r IN (SELECT table_name FROM user_tables
            WHERE table_name IN
             ('ENROLLMENT_AUDIT','WAITLIST','ENROLLMENT','SECTION','PREREQUISITE',
              'COURSE','STUDENT','FACULTY','PROGRAM','ROOM','TIME_SLOT','TERM',
              'GRADE_SCALE','DEPARTMENT')) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE '||r.table_name||' CASCADE CONSTRAINTS PURGE';
  END LOOP;

  FOR r IN (SELECT sequence_name FROM user_sequences
            WHERE sequence_name IN ('ENROLLMENT_SEQ','WAITLIST_SEQ','AUDIT_SEQ')) LOOP
    EXECUTE IMMEDIATE 'DROP SEQUENCE '||r.sequence_name;
  END LOOP;

  FOR r IN (SELECT object_name, object_type FROM user_objects
            WHERE object_type IN ('VIEW','PROCEDURE','FUNCTION','PACKAGE','TRIGGER')
              AND object_name IN
               ('V_STUDENT_TRANSCRIPT','V_STUDENT_CGPA','V_SECTION_SEATS',
                'V_SECTION_ROSTER','V_FACULTY_TEACHING_LOAD','V_ENROLLMENT_AUDIT',
                'V_WAITLIST_STATUS','SP_REGISTER_STUDENT','SP_DROP_REGISTRATION',
                'SP_PROMOTE_WAITLIST','SP_POST_GRADE','SP_TRANSCRIPT',
                'FN_PREREQS_MET','FN_CALCULATE_CGPA','FN_STUDENT_CGPA',
                'FN_SEATS_AVAILABLE','REG_CTX','TRG_ENROLLMENT_AUDIT',
                'TRG_SECTION_ENROLLED_COUNT','TRG_ENROLLMENT_CGPA')) LOOP
    EXECUTE IMMEDIATE 'DROP '||r.object_type||' '||r.object_name;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('Cleanup complete.');
END;
/
