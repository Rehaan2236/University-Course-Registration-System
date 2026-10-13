-- =====================================================================
-- 07_triggers.sql : Triggers for derived data + audit, then a one-time
-- re-sync of the seeded derived columns.
-- =====================================================================

-- 1. Audit every enrollment status change (INSERT = creation, UPDATE OF status
--    = transition). changed_by comes from the context package set by procedures.
CREATE OR REPLACE TRIGGER trg_enrollment_audit
AFTER INSERT OR UPDATE OF status ON enrollment
FOR EACH ROW
BEGIN
  IF INSERTING OR (:OLD.status <> :NEW.status) THEN
    INSERT INTO enrollment_audit
      (audit_id, enrollment_id, old_status, new_status, changed_by, changed_at)
    VALUES
      (audit_seq.NEXTVAL, :NEW.enrollment_id,
       CASE WHEN INSERTING THEN NULL ELSE :OLD.status END,
       :NEW.status, NVL(reg_ctx.g_actor, USER), SYSTIMESTAMP);
  END IF;
END;
/

-- 2. Keep section.enrolled_count = number of REGISTERED enrollments.
--    Incremental (+1/-1); avoids querying ENROLLMENT from its own trigger.
CREATE OR REPLACE TRIGGER trg_section_enrolled_count
AFTER INSERT OR UPDATE OF status OR DELETE ON enrollment
FOR EACH ROW
BEGIN
  IF INSERTING THEN
    IF :NEW.status = 'REGISTERED' THEN
      UPDATE section SET enrolled_count = enrolled_count + 1 WHERE section_id = :NEW.section_id;
    END IF;
  ELSIF UPDATING THEN
    IF :OLD.status = 'REGISTERED' AND :NEW.status <> 'REGISTERED' THEN
      UPDATE section SET enrolled_count = enrolled_count - 1 WHERE section_id = :NEW.section_id;
    ELSIF :OLD.status <> 'REGISTERED' AND :NEW.status = 'REGISTERED' THEN
      UPDATE section SET enrolled_count = enrolled_count + 1 WHERE section_id = :NEW.section_id;
    END IF;
  ELSIF DELETING THEN
    IF :OLD.status = 'REGISTERED' THEN
      UPDATE section SET enrolled_count = enrolled_count - 1 WHERE section_id = :OLD.section_id;
    END IF;
  END IF;
END;
/

-- 3. Recompute student.cgpa whenever a grade/status changes.
--    COMPOUND trigger: collect affected students per row, recompute once at
--    statement level (so ENROLLMENT is no longer mutating when we read it).
CREATE OR REPLACE TRIGGER trg_enrollment_cgpa
FOR INSERT OR UPDATE OF grade, status ON enrollment
COMPOUND TRIGGER
  TYPE t_ids IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
  g_students t_ids;

  AFTER EACH ROW IS
  BEGIN
    g_students(:NEW.student_id) := 1;   -- index = student_id => auto de-dup
  END AFTER EACH ROW;

  AFTER STATEMENT IS
    i PLS_INTEGER;
  BEGIN
    i := g_students.FIRST;
    WHILE i IS NOT NULL LOOP
      UPDATE student SET cgpa = fn_calculate_cgpa(i) WHERE student_id = i;
      i := g_students.NEXT(i);
    END LOOP;
    g_students.DELETE;
  END AFTER STATEMENT;
END trg_enrollment_cgpa;
/

-- ---- One-time re-sync of seeded derived columns ----------------------
-- (Sample data in 04 was loaded before these triggers existed.)
UPDATE section s
   SET enrolled_count = (SELECT COUNT(*) FROM enrollment e
                          WHERE e.section_id = s.section_id AND e.status = 'REGISTERED');
UPDATE student st
   SET cgpa = fn_calculate_cgpa(st.student_id);
COMMIT;
