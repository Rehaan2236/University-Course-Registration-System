-- =====================================================================
-- 08_views.sql : Reporting / analytical views used by reports + the UI.
-- =====================================================================

CREATE OR REPLACE VIEW v_student_transcript AS
SELECT st.student_id, st.reg_no, st.name AS student_name,
       c.course_code, c.title, c.credits,
       e.grade, e.grade_points, t.term_name, e.status
  FROM enrollment e
  JOIN section s  ON s.section_id = e.section_id
  JOIN course  c  ON c.course_id  = s.course_id
  JOIN term    t  ON t.term_id     = s.term_id
  JOIN student st ON st.student_id = e.student_id;

CREATE OR REPLACE VIEW v_student_cgpa AS
SELECT st.student_id, st.reg_no, st.name, p.program_name, st.cgpa
  FROM student st
  JOIN program p ON p.program_id = st.program_id;

CREATE OR REPLACE VIEW v_section_seats AS
SELECT s.section_id, c.course_code, c.title, t.term_name, f.name AS faculty,
       s.capacity, s.enrolled_count,
       (s.capacity - s.enrolled_count)           AS seats_available,
       ROUND(s.enrolled_count * 100 / s.capacity, 1) AS utilization_pct
  FROM section s
  JOIN course  c ON c.course_id  = s.course_id
  JOIN term    t ON t.term_id     = s.term_id
  JOIN faculty f ON f.faculty_id  = s.faculty_id;

CREATE OR REPLACE VIEW v_section_roster AS
SELECT s.section_id, c.course_code, t.term_name,
       st.reg_no, st.name AS student_name, e.status, e.grade
  FROM enrollment e
  JOIN section s  ON s.section_id = e.section_id
  JOIN course  c  ON c.course_id  = s.course_id
  JOIN term    t  ON t.term_id     = s.term_id
  JOIN student st ON st.student_id = e.student_id
 WHERE e.status IN ('REGISTERED','COMPLETED');

CREATE OR REPLACE VIEW v_faculty_teaching_load AS
SELECT f.faculty_id, f.name AS faculty, t.term_name,
       COUNT(DISTINCT s.section_id)   AS sections,
       COUNT(DISTINCT s.course_id)    AS courses,
       NVL(SUM(s.enrolled_count), 0)  AS total_registered
  FROM faculty f
  LEFT JOIN section s ON s.faculty_id = f.faculty_id
  LEFT JOIN term    t ON t.term_id     = s.term_id
 GROUP BY f.faculty_id, f.name, t.term_name;

CREATE OR REPLACE VIEW v_enrollment_audit AS
SELECT a.audit_id, a.enrollment_id, st.reg_no, c.course_code,
       a.old_status, a.new_status, a.changed_by, a.changed_at
  FROM enrollment_audit a
  JOIN enrollment e  ON e.enrollment_id = a.enrollment_id
  JOIN section s     ON s.section_id     = e.section_id
  JOIN course  c     ON c.course_id      = s.course_id
  JOIN student st    ON st.student_id    = e.student_id;

CREATE OR REPLACE VIEW v_waitlist_status AS
SELECT w.waitlist_id, s.section_id, c.course_code, t.term_name,
       st.reg_no, st.name AS student_name, w.position, w.requested_at
  FROM waitlist w
  JOIN section s  ON s.section_id = w.section_id
  JOIN course  c  ON c.course_id  = s.course_id
  JOIN term    t  ON t.term_id     = s.term_id
  JOIN student st ON st.student_id = w.student_id;
