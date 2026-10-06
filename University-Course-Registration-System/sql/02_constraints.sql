-- =====================================================================
-- 02_constraints.sql : Foreign keys with chosen ON DELETE behaviour.
--   RESTRICT (default)  : block delete while dependents exist
--   CASCADE             : remove dependents with the parent
-- =====================================================================

ALTER TABLE department ADD CONSTRAINT fk_dept_hod
  FOREIGN KEY (hod_faculty_id) REFERENCES faculty(faculty_id);

ALTER TABLE program ADD CONSTRAINT fk_prog_dept
  FOREIGN KEY (dept_id) REFERENCES department(dept_id);

ALTER TABLE faculty ADD CONSTRAINT fk_fac_dept
  FOREIGN KEY (dept_id) REFERENCES department(dept_id);

ALTER TABLE student ADD CONSTRAINT fk_stu_prog
  FOREIGN KEY (program_id) REFERENCES program(program_id);

ALTER TABLE course ADD CONSTRAINT fk_course_dept
  FOREIGN KEY (dept_id) REFERENCES department(dept_id);

ALTER TABLE prerequisite ADD CONSTRAINT fk_prereq_course
  FOREIGN KEY (course_id) REFERENCES course(course_id) ON DELETE CASCADE;
ALTER TABLE prerequisite ADD CONSTRAINT fk_prereq_pre
  FOREIGN KEY (prereq_course_id) REFERENCES course(course_id);

ALTER TABLE section ADD CONSTRAINT fk_sec_course FOREIGN KEY (course_id)  REFERENCES course(course_id);
ALTER TABLE section ADD CONSTRAINT fk_sec_fac    FOREIGN KEY (faculty_id) REFERENCES faculty(faculty_id);
ALTER TABLE section ADD CONSTRAINT fk_sec_term   FOREIGN KEY (term_id)    REFERENCES term(term_id);
ALTER TABLE section ADD CONSTRAINT fk_sec_room   FOREIGN KEY (room_id)    REFERENCES room(room_id);
ALTER TABLE section ADD CONSTRAINT fk_sec_slot   FOREIGN KEY (slot_id)    REFERENCES time_slot(slot_id);

ALTER TABLE enrollment ADD CONSTRAINT fk_enr_stu   FOREIGN KEY (student_id) REFERENCES student(student_id);
ALTER TABLE enrollment ADD CONSTRAINT fk_enr_sec   FOREIGN KEY (section_id) REFERENCES section(section_id);
ALTER TABLE enrollment ADD CONSTRAINT fk_enr_grade FOREIGN KEY (grade)      REFERENCES grade_scale(grade);

ALTER TABLE waitlist ADD CONSTRAINT fk_wait_sec FOREIGN KEY (section_id) REFERENCES section(section_id);
ALTER TABLE waitlist ADD CONSTRAINT fk_wait_stu FOREIGN KEY (student_id) REFERENCES student(student_id);

ALTER TABLE enrollment_audit ADD CONSTRAINT fk_audit_enr
  FOREIGN KEY (enrollment_id) REFERENCES enrollment(enrollment_id) ON DELETE CASCADE;
