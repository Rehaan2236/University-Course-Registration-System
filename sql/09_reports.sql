-- =====================================================================
-- 09_reports.sql : Ready-to-run analytical queries (A-J) + a recursive
-- prerequisite-chain query. Run individual statements as needed.
-- =====================================================================
SET PAGESIZE 100
SET LINESIZE 160

PROMPT === A. Student transcript (Ritvik, 24BAI0156) ===
SELECT course_code, title, credits, grade, grade_points, term_name, status
  FROM v_student_transcript
 WHERE reg_no = '24BAI0156'
 ORDER BY term_name, course_code;

PROMPT === B. All students CGPA ===
SELECT reg_no, name, program_name, cgpa FROM v_student_cgpa ORDER BY cgpa DESC;

PROMPT === C. Roster of section 10 (CS301) ===
SELECT reg_no, student_name, status, grade FROM v_section_roster
 WHERE section_id = 10 ORDER BY reg_no;

PROMPT === D. Available seats per section (active term) ===
SELECT section_id, course_code, term_name, capacity, enrolled_count, seats_available
  FROM v_section_seats WHERE term_name = 'Winter 2026' ORDER BY section_id;

PROMPT === E. Seat utilization % (active term) ===
SELECT section_id, course_code, enrolled_count, capacity, utilization_pct
  FROM v_section_seats WHERE term_name = 'Winter 2026' ORDER BY utilization_pct DESC;

PROMPT === F. Faculty teaching load (active term) ===
SELECT faculty, sections, courses, total_registered
  FROM v_faculty_teaching_load WHERE term_name = 'Winter 2026' ORDER BY faculty;

PROMPT === G. Students who satisfy ALL prerequisites for CS301 (course_id 3) but have not registered ===
SELECT st.student_id, st.reg_no, st.name
  FROM student st
 WHERE fn_prereqs_met(st.student_id, 3) = 'Y'
   AND NOT EXISTS (SELECT 1 FROM enrollment e
                     JOIN section s ON s.section_id = e.section_id
                    WHERE e.student_id = st.student_id AND s.course_id = 3
                      AND e.status IN ('REGISTERED','COMPLETED','WAITLISTED'))
 ORDER BY st.student_id;

PROMPT === H. Students whose CGPA is above their program average ===
SELECT st.reg_no, st.name, p.program_name, st.cgpa, pa.avg_cgpa
  FROM student st
  JOIN program p ON p.program_id = st.program_id
  JOIN (SELECT program_id, ROUND(AVG(cgpa),2) AS avg_cgpa
          FROM student GROUP BY program_id) pa
    ON pa.program_id = st.program_id
 WHERE st.cgpa > pa.avg_cgpa
 ORDER BY p.program_name, st.cgpa DESC;

PROMPT === I. Enrollment audit history ===
SELECT audit_id, reg_no, course_code, old_status, new_status, changed_by, changed_at
  FROM v_enrollment_audit ORDER BY audit_id;

PROMPT === J. Waitlist status ===
SELECT section_id, course_code, reg_no, student_name, position, requested_at
  FROM v_waitlist_status ORDER BY section_id, position;

PROMPT === K. Recursive prerequisite chain for CS401 (course_id 5) ===
SELECT LPAD(' ', 2*(LEVEL-1)) || c.course_code AS prereq_tree, LEVEL AS depth
  FROM prerequisite pr
  JOIN course c ON c.course_id = pr.prereq_course_id
 START WITH pr.course_id = 5
 CONNECT BY PRIOR pr.prereq_course_id = pr.course_id;
