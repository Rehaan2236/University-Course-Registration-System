-- =====================================================================
-- 06_procedures.sql : PL/SQL API. All business rules live here + triggers.
-- The thin client only CALLs these; it never embeds rules.
-- Order matters: sp_promote_waitlist is created before sp_drop_registration
-- (which calls it).
-- =====================================================================

-- ---------------------------------------------------------------------
-- sp_register_student : the core transaction.
--   1 lock section row (FOR UPDATE) -> serialises concurrent attempts
--   2 prerequisite check    3 timetable-clash check
--   4 seat check -> REGISTER   5 else -> WAITLIST
--   commit on success, rollback + raise on any failure (atomic).
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_register_student (
  p_student_id IN NUMBER,
  p_section_id IN NUMBER,
  p_actor      IN VARCHAR2 DEFAULT NULL
) IS
  v_capacity  section.capacity%TYPE;
  v_count     section.enrolled_count%TYPE;
  v_term_id   section.term_id%TYPE;
  v_slot_id   section.slot_id%TYPE;
  v_course_id section.course_id%TYPE;
  v_exists    NUMBER;
  v_clash     NUMBER;
  v_pos       NUMBER;
BEGIN
  reg_ctx.set_actor(NVL(p_actor, USER));

  -- 1. Lock the section row. A second session registering for the same
  --    section waits here until we commit, so two people can never both
  --    consume the final seat.
  SELECT capacity, enrolled_count, term_id, slot_id, course_id
    INTO v_capacity, v_count, v_term_id, v_slot_id, v_course_id
    FROM section
   WHERE section_id = p_section_id
     FOR UPDATE;

  SELECT COUNT(*) INTO v_exists FROM student WHERE student_id = p_student_id;
  IF v_exists = 0 THEN
    RAISE_APPLICATION_ERROR(-20010, 'Student '||p_student_id||' does not exist.');
  END IF;

  -- No duplicate active enrollment / waitlist entry
  SELECT COUNT(*) INTO v_exists FROM enrollment
   WHERE student_id = p_student_id AND section_id = p_section_id
     AND status IN ('REGISTERED','COMPLETED');
  IF v_exists > 0 THEN
    RAISE_APPLICATION_ERROR(-20011, 'Student already registered for / completed this section.');
  END IF;
  SELECT COUNT(*) INTO v_exists FROM waitlist
   WHERE student_id = p_student_id AND section_id = p_section_id;
  IF v_exists > 0 THEN
    RAISE_APPLICATION_ERROR(-20012, 'Student already on the waitlist for this section.');
  END IF;

  -- 2. Prerequisite check
  IF fn_prereqs_met(p_student_id, v_course_id) = 'N' THEN
    RAISE_APPLICATION_ERROR(-20001, 'Prerequisites not completed for this course.');
  END IF;

  -- 3. Timetable-clash check: any REGISTERED section in the same term whose
  --    slot overlaps this one (same day AND time ranges intersect).
  SELECT COUNT(*) INTO v_clash
    FROM enrollment e
    JOIN section   s  ON s.section_id = e.section_id
    JOIN time_slot t  ON t.slot_id    = s.slot_id
    JOIN time_slot nt ON nt.slot_id   = v_slot_id
   WHERE e.student_id = p_student_id
     AND e.status     = 'REGISTERED'
     AND s.term_id    = v_term_id
     AND t.day_of_week = nt.day_of_week
     AND t.start_time  < nt.end_time
     AND nt.start_time < t.end_time;
  IF v_clash > 0 THEN
    RAISE_APPLICATION_ERROR(-20002, 'Timetable clash with an existing registration.');
  END IF;

  -- 4 / 5. Seat available -> register, else -> waitlist
  IF v_count < v_capacity THEN
    INSERT INTO enrollment (enrollment_id, student_id, section_id, status, enrolled_on)
    VALUES (enrollment_seq.NEXTVAL, p_student_id, p_section_id, 'REGISTERED', SYSDATE);
    DBMS_OUTPUT.PUT_LINE('REGISTERED: student '||p_student_id||' into section '||p_section_id);
  ELSE
    SELECT NVL(MAX(position), 0) + 1 INTO v_pos FROM waitlist WHERE section_id = p_section_id;
    INSERT INTO waitlist (waitlist_id, section_id, student_id, position, requested_at)
    VALUES (waitlist_seq.NEXTVAL, p_section_id, p_student_id, v_pos, SYSTIMESTAMP);
    DBMS_OUTPUT.PUT_LINE('WAITLISTED: student '||p_student_id||' at position '||v_pos||' for section '||p_section_id);
  END IF;

  COMMIT;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR(-20013, 'Section '||p_section_id||' does not exist.');
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END sp_register_student;
/

-- ---------------------------------------------------------------------
-- sp_promote_waitlist : fill free seats from the waitlist (earliest first).
-- Re-validates prerequisites + timetable before promoting; a candidate who
-- no longer qualifies is removed and the next one is tried.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_promote_waitlist (
  p_section_id IN NUMBER,
  p_actor      IN VARCHAR2 DEFAULT NULL
) IS
  v_capacity  section.capacity%TYPE;
  v_count     section.enrolled_count%TYPE;
  v_term_id   section.term_id%TYPE;
  v_slot_id   section.slot_id%TYPE;
  v_course_id section.course_id%TYPE;
  v_wid       waitlist.waitlist_id%TYPE;
  v_student   waitlist.student_id%TYPE;
  v_clash     NUMBER;
  v_promoted  BOOLEAN := FALSE;
BEGIN
  reg_ctx.set_actor(NVL(p_actor, USER));
  LOOP
    SELECT capacity, enrolled_count, term_id, slot_id, course_id
      INTO v_capacity, v_count, v_term_id, v_slot_id, v_course_id
      FROM section WHERE section_id = p_section_id FOR UPDATE;

    EXIT WHEN v_count >= v_capacity;         -- no free seat

    BEGIN
      SELECT waitlist_id, student_id INTO v_wid, v_student
        FROM (SELECT waitlist_id, student_id
                FROM waitlist WHERE section_id = p_section_id
               ORDER BY position)
       WHERE ROWNUM = 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN EXIT;          -- empty waitlist
    END;

    IF fn_prereqs_met(v_student, v_course_id) = 'N' THEN
      DELETE FROM waitlist WHERE waitlist_id = v_wid;
      DBMS_OUTPUT.PUT_LINE('Skipped student '||v_student||' (prerequisites no longer met).');
      CONTINUE;
    END IF;

    SELECT COUNT(*) INTO v_clash
      FROM enrollment e
      JOIN section   s  ON s.section_id = e.section_id
      JOIN time_slot t  ON t.slot_id    = s.slot_id
      JOIN time_slot nt ON nt.slot_id   = v_slot_id
     WHERE e.student_id = v_student
       AND e.status     = 'REGISTERED'
       AND s.term_id    = v_term_id
       AND t.day_of_week = nt.day_of_week
       AND t.start_time  < nt.end_time
       AND nt.start_time < t.end_time;
    IF v_clash > 0 THEN
      DELETE FROM waitlist WHERE waitlist_id = v_wid;
      DBMS_OUTPUT.PUT_LINE('Skipped student '||v_student||' (timetable clash).');
      CONTINUE;
    END IF;

    INSERT INTO enrollment (enrollment_id, student_id, section_id, status, enrolled_on)
    VALUES (enrollment_seq.NEXTVAL, v_student, p_section_id, 'REGISTERED', SYSDATE);
    DELETE FROM waitlist WHERE waitlist_id = v_wid;
    DBMS_OUTPUT.PUT_LINE('PROMOTED student '||v_student||' from waitlist into section '||p_section_id);
    v_promoted := TRUE;
    EXIT;                                    -- one seat filled
  END LOOP;

  IF NOT v_promoted THEN
    DBMS_OUTPUT.PUT_LINE('No waitlisted student promoted for section '||p_section_id);
  END IF;
  COMMIT;
END sp_promote_waitlist;
/

-- ---------------------------------------------------------------------
-- sp_drop_registration : drop a REGISTERED enrollment, then try to fill
-- the freed seat from the waitlist. Both happen in one transaction.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_drop_registration (
  p_student_id IN NUMBER,
  p_section_id IN NUMBER,
  p_actor      IN VARCHAR2 DEFAULT NULL
) IS
  v_enr_id enrollment.enrollment_id%TYPE;
  v_dummy  NUMBER;
BEGIN
  reg_ctx.set_actor(NVL(p_actor, USER));
  SELECT 1 INTO v_dummy FROM section WHERE section_id = p_section_id FOR UPDATE;

  SELECT enrollment_id INTO v_enr_id
    FROM enrollment
   WHERE student_id = p_student_id AND section_id = p_section_id AND status = 'REGISTERED';

  UPDATE enrollment SET status = 'DROPPED' WHERE enrollment_id = v_enr_id;
  DBMS_OUTPUT.PUT_LINE('DROPPED: student '||p_student_id||' from section '||p_section_id);

  -- fill the freed seat (this procedure commits the whole transaction)
  sp_promote_waitlist(p_section_id, NVL(p_actor, USER));
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR(-20020, 'No active (REGISTERED) enrollment found to drop.');
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END sp_drop_registration;
/

-- ---------------------------------------------------------------------
-- sp_post_grade : record a grade and mark the enrollment COMPLETED.
-- Triggers then recompute the student's CGPA and log the status change.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_post_grade (
  p_student_id IN NUMBER,
  p_section_id IN NUMBER,
  p_grade      IN VARCHAR2,
  p_actor      IN VARCHAR2 DEFAULT NULL
) IS
  v_points grade_scale.points%TYPE;
  v_enr_id enrollment.enrollment_id%TYPE;
BEGIN
  reg_ctx.set_actor(NVL(p_actor, USER));
  SELECT points INTO v_points FROM grade_scale WHERE grade = p_grade;  -- validates grade value

  SELECT enrollment_id INTO v_enr_id
    FROM enrollment
   WHERE student_id = p_student_id AND section_id = p_section_id
     AND status IN ('REGISTERED','COMPLETED');

  UPDATE enrollment
     SET grade = p_grade, grade_points = v_points, status = 'COMPLETED'
   WHERE enrollment_id = v_enr_id;

  COMMIT;   -- CGPA + audit already updated by triggers at statement time
  DBMS_OUTPUT.PUT_LINE('GRADE '||p_grade||' posted. New CGPA for student '
                       ||p_student_id||' = '||fn_student_cgpa(p_student_id));
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR(-20030, 'Invalid grade, or no gradable enrollment for this student/section.');
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END sp_post_grade;
/

-- ---------------------------------------------------------------------
-- sp_transcript : print a formatted transcript using an EXPLICIT CURSOR.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_transcript (
  p_student_id IN NUMBER
) IS
  CURSOR c_tr IS
    SELECT c.course_code, c.title, c.credits, e.grade, e.grade_points,
           t.term_name, e.status
      FROM enrollment e
      JOIN section s ON s.section_id = e.section_id
      JOIN course  c ON c.course_id  = s.course_id
      JOIN term    t ON t.term_id     = s.term_id
     WHERE e.student_id = p_student_id
     ORDER BY t.term_name, c.course_code;
  v_name student.name%TYPE;
  v_reg  student.reg_no%TYPE;
  v_cgpa student.cgpa%TYPE;
BEGIN
  SELECT name, reg_no, cgpa INTO v_name, v_reg, v_cgpa
    FROM student WHERE student_id = p_student_id;

  DBMS_OUTPUT.PUT_LINE('==================================================================');
  DBMS_OUTPUT.PUT_LINE('TRANSCRIPT   '||v_reg||'   '||v_name);
  DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------------');
  DBMS_OUTPUT.PUT_LINE(RPAD('CODE',8)||RPAD('TITLE',26)||RPAD('CR',4)||
                       RPAD('GR',4)||RPAD('PTS',5)||RPAD('TERM',14)||'STATUS');
  FOR r IN c_tr LOOP
    DBMS_OUTPUT.PUT_LINE(RPAD(r.course_code,8)||RPAD(SUBSTR(r.title,1,25),26)||
       RPAD(r.credits,4)||RPAD(NVL(r.grade,'-'),4)||
       RPAD(NVL(TO_CHAR(r.grade_points),'-'),5)||RPAD(r.term_name,14)||r.status);
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------------');
  DBMS_OUTPUT.PUT_LINE('CURRENT CGPA: '||v_cgpa);
  DBMS_OUTPUT.PUT_LINE('==================================================================');
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20040, 'Student '||p_student_id||' not found.');
END sp_transcript;
/
