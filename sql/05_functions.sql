-- =====================================================================
-- 05_functions.sql : Session context package + read-only functions.
-- These are pure (no DML) so they are safe to call from SQL and triggers.
-- =====================================================================

-- Small context package: lets procedures tell the audit trigger WHO acted.
CREATE OR REPLACE PACKAGE reg_ctx IS
  g_actor VARCHAR2(100);
  PROCEDURE set_actor(p_actor IN VARCHAR2);
END reg_ctx;
/
CREATE OR REPLACE PACKAGE BODY reg_ctx IS
  PROCEDURE set_actor(p_actor IN VARCHAR2) IS
  BEGIN
    g_actor := p_actor;
  END set_actor;
END reg_ctx;
/

-- Returns 'Y' if the student has COMPLETED (with a passing grade) every
-- immediate prerequisite of the given course, else 'N'.
-- Prerequisite CHAINS are enforced transitively: a student could only have
-- completed CS201 if CS101 had been completed when CS201 was taken.
CREATE OR REPLACE FUNCTION fn_prereqs_met (
  p_student_id IN NUMBER,
  p_course_id  IN NUMBER
) RETURN VARCHAR2 IS
  v_missing NUMBER;
BEGIN
  SELECT COUNT(*)
    INTO v_missing
    FROM prerequisite pr
   WHERE pr.course_id = p_course_id
     AND NOT EXISTS (
           SELECT 1
             FROM enrollment e
             JOIN section s ON s.section_id = e.section_id
            WHERE e.student_id = p_student_id
              AND s.course_id  = pr.prereq_course_id
              AND e.status     = 'COMPLETED'
              AND NVL(e.grade_points, 0) > 0
         );
  RETURN CASE WHEN v_missing = 0 THEN 'Y' ELSE 'N' END;
END fn_prereqs_met;
/

-- Credit-weighted CGPA over all COMPLETED enrollments.
-- CGPA = SUM(credits * grade_points) / SUM(credits)
CREATE OR REPLACE FUNCTION fn_calculate_cgpa (
  p_student_id IN NUMBER
) RETURN NUMBER IS
  v_cgpa NUMBER;
BEGIN
  SELECT NVL(ROUND(SUM(c.credits * e.grade_points) / NULLIF(SUM(c.credits), 0), 2), 0)
    INTO v_cgpa
    FROM enrollment e
    JOIN section s ON s.section_id = e.section_id
    JOIN course  c ON c.course_id  = s.course_id
   WHERE e.student_id = p_student_id
     AND e.status     = 'COMPLETED';
  RETURN v_cgpa;
END fn_calculate_cgpa;
/

-- Quick read of the stored (maintained) CGPA.
CREATE OR REPLACE FUNCTION fn_student_cgpa (
  p_student_id IN NUMBER
) RETURN NUMBER IS
  v NUMBER;
BEGIN
  SELECT cgpa INTO v FROM student WHERE student_id = p_student_id;
  RETURN v;
EXCEPTION
  WHEN NO_DATA_FOUND THEN RETURN NULL;
END fn_student_cgpa;
/

-- Seats still free in a section.
CREATE OR REPLACE FUNCTION fn_seats_available (
  p_section_id IN NUMBER
) RETURN NUMBER IS
  v NUMBER;
BEGIN
  SELECT capacity - enrolled_count INTO v FROM section WHERE section_id = p_section_id;
  RETURN v;
EXCEPTION
  WHEN NO_DATA_FOUND THEN RETURN NULL;
END fn_seats_available;
/
