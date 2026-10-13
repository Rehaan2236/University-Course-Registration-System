-- =====================================================================
-- setup_all_in_one.sql : COMPLETE self-contained setup in ONE file.
-- No @@ includes. Run:  @C:\path\to\setup_all_in_one.sql
-- Starts with a NUCLEAR cleanup that drops EVERY object in this schema,
-- so stray/leftover objects from earlier runs cannot interfere.
-- =====================================================================
SET DEFINE OFF
SET SERVEROUTPUT ON SIZE UNLIMITED
SET ECHO OFF

PROMPT ====== 00 NUCLEAR cleanup (drop everything in schema) ======
BEGIN
  FOR r IN (SELECT trigger_name FROM user_triggers) LOOP
    EXECUTE IMMEDIATE 'DROP TRIGGER '||r.trigger_name;
  END LOOP;
  FOR r IN (SELECT table_name FROM user_tables) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE '||r.table_name||' CASCADE CONSTRAINTS PURGE';
  END LOOP;
  FOR r IN (SELECT sequence_name FROM user_sequences) LOOP
    EXECUTE IMMEDIATE 'DROP SEQUENCE '||r.sequence_name;
  END LOOP;
  FOR r IN (SELECT object_name, object_type FROM user_objects
            WHERE object_type IN ('VIEW','PROCEDURE','FUNCTION','PACKAGE')) LOOP
    BEGIN EXECUTE IMMEDIATE 'DROP '||r.object_type||' '||r.object_name;
    EXCEPTION WHEN OTHERS THEN NULL; END;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('Nuclear cleanup complete.');
END;
/

PROMPT ====== 01_create_tables ======
-- =====================================================================
-- 01_create_tables.sql : Base tables (PK / NOT NULL / UNIQUE / CHECK).
-- Foreign keys are added separately in 02_constraints.sql to avoid the
-- circular dependency between DEPARTMENT.hod_faculty_id and FACULTY.
-- Target: Oracle Database XE 18c/21c.
-- =====================================================================

CREATE TABLE department (
  dept_id        NUMBER(5)     PRIMARY KEY,
  dept_name      VARCHAR2(100) NOT NULL UNIQUE,
  hod_faculty_id NUMBER(5)                       -- FK -> faculty (added in 02), nullable
);

CREATE TABLE program (
  program_id             NUMBER(5)     PRIMARY KEY,
  program_name           VARCHAR2(100) NOT NULL,
  dept_id                NUMBER(5)     NOT NULL,
  total_credits_required NUMBER(4)     NOT NULL,
  CONSTRAINT chk_prog_credits CHECK (total_credits_required > 0)
);

CREATE TABLE faculty (
  faculty_id  NUMBER(5)     PRIMARY KEY,
  name        VARCHAR2(100) NOT NULL,
  dept_id     NUMBER(5)     NOT NULL,
  designation VARCHAR2(50),
  email       VARCHAR2(120) NOT NULL UNIQUE
);

CREATE TABLE student (
  student_id     NUMBER(7)     PRIMARY KEY,
  reg_no         VARCHAR2(20)  NOT NULL UNIQUE,
  name           VARCHAR2(100) NOT NULL,
  dob            DATE,
  email          VARCHAR2(120) NOT NULL UNIQUE,
  program_id     NUMBER(5)     NOT NULL,
  admission_year NUMBER(4)     NOT NULL,
  cgpa           NUMBER(4,2)   DEFAULT 0 NOT NULL,
  CONSTRAINT chk_cgpa_range CHECK (cgpa BETWEEN 0 AND 10)
);

CREATE TABLE course (
  course_id   NUMBER(5)     PRIMARY KEY,
  course_code VARCHAR2(10)  NOT NULL UNIQUE,
  title       VARCHAR2(120) NOT NULL,
  credits     NUMBER(2)     NOT NULL,
  dept_id     NUMBER(5)     NOT NULL,
  course_type VARCHAR2(10)  NOT NULL,
  CONSTRAINT chk_course_credits CHECK (credits BETWEEN 1 AND 6),
  CONSTRAINT chk_course_type    CHECK (course_type IN ('CORE','ELECTIVE'))
);

CREATE TABLE prerequisite (
  course_id        NUMBER(5) NOT NULL,
  prereq_course_id NUMBER(5) NOT NULL,
  CONSTRAINT pk_prerequisite PRIMARY KEY (course_id, prereq_course_id),
  CONSTRAINT chk_prereq_self CHECK (course_id <> prereq_course_id)
);

CREATE TABLE term (
  term_id    NUMBER(5)    PRIMARY KEY,
  term_name  VARCHAR2(50) NOT NULL,
  start_date DATE         NOT NULL,
  end_date   DATE         NOT NULL,
  is_active  CHAR(1)      DEFAULT 'N' NOT NULL,
  CONSTRAINT chk_term_active CHECK (is_active IN ('Y','N')),
  CONSTRAINT chk_term_dates  CHECK (end_date > start_date)
);

CREATE TABLE time_slot (
  slot_id     NUMBER(5)   PRIMARY KEY,
  day_of_week VARCHAR2(3) NOT NULL,
  start_time  VARCHAR2(5) NOT NULL,   -- 'HH24:MI', zero-padded 24h
  end_time    VARCHAR2(5) NOT NULL,
  CONSTRAINT chk_day       CHECK (day_of_week IN ('MON','TUE','WED','THU','FRI','SAT')),
  CONSTRAINT chk_slot_time CHECK (end_time > start_time)
);

CREATE TABLE room (
  room_id       NUMBER(5)    PRIMARY KEY,
  building      VARCHAR2(50) NOT NULL,
  room_capacity NUMBER(4)    NOT NULL,
  CONSTRAINT chk_room_cap CHECK (room_capacity > 0)
);

CREATE TABLE section (
  section_id     NUMBER(7) PRIMARY KEY,
  course_id      NUMBER(5) NOT NULL,
  faculty_id     NUMBER(5) NOT NULL,
  term_id        NUMBER(5) NOT NULL,
  room_id        NUMBER(5) NOT NULL,
  slot_id        NUMBER(5) NOT NULL,
  capacity       NUMBER(4) NOT NULL,
  enrolled_count NUMBER(4) DEFAULT 0 NOT NULL,
  CONSTRAINT chk_sec_capacity CHECK (capacity > 0),
  CONSTRAINT chk_sec_count    CHECK (enrolled_count >= 0 AND enrolled_count <= capacity)
);

CREATE TABLE grade_scale (
  grade     VARCHAR2(2) PRIMARY KEY,
  min_marks NUMBER(3)   NOT NULL,
  points    NUMBER(4,2) NOT NULL,
  CONSTRAINT chk_grade_points CHECK (points BETWEEN 0 AND 10)
);

CREATE TABLE enrollment (
  enrollment_id NUMBER(9)    PRIMARY KEY,
  student_id    NUMBER(7)    NOT NULL,
  section_id    NUMBER(7)    NOT NULL,
  status        VARCHAR2(10) NOT NULL,
  grade         VARCHAR2(2),              -- FK -> grade_scale, nullable until graded
  grade_points  NUMBER(4,2),
  enrolled_on   DATE         DEFAULT SYSDATE NOT NULL,
  CONSTRAINT chk_enr_status CHECK (status IN ('REGISTERED','WAITLISTED','DROPPED','COMPLETED')),
  CONSTRAINT uq_enr_stu_sec UNIQUE (student_id, section_id)
);

CREATE TABLE waitlist (
  waitlist_id  NUMBER(9)  PRIMARY KEY,
  section_id   NUMBER(7)  NOT NULL,
  student_id   NUMBER(7)  NOT NULL,
  position     NUMBER(5)  NOT NULL,
  requested_at TIMESTAMP  DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT uq_wait_sec_stu UNIQUE (section_id, student_id)
);

CREATE TABLE enrollment_audit (
  audit_id      NUMBER(9)     PRIMARY KEY,
  enrollment_id NUMBER(9)     NOT NULL,
  old_status    VARCHAR2(10),
  new_status    VARCHAR2(10)  NOT NULL,
  changed_by    VARCHAR2(100) NOT NULL,
  changed_at    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL
);


PROMPT ====== 02_constraints ======
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


PROMPT ====== 03_sequences ======
-- =====================================================================
-- 03_sequences.sql : Surrogate-key sequences for rows created at runtime
-- by the PL/SQL API (enrollments, waitlist entries, audit rows).
-- Master/seed data uses small explicit IDs; sequences start high to
-- guarantee there is never a collision with seeded IDs.
-- =====================================================================
CREATE SEQUENCE enrollment_seq START WITH 100001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE waitlist_seq   START WITH 100001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE audit_seq      START WITH 100001 INCREMENT BY 1 NOCACHE;


PROMPT ====== 04_sample_data ======
-- =====================================================================
-- 04_sample_data.sql : Deterministic demo data.
-- NOTE: this runs BEFORE triggers are created (see run_all.sql), so
-- derived columns (section.enrolled_count, student.cgpa) are seeded with
-- correct values here and then re-synced at the end of 07_triggers.sql.
-- =====================================================================
SET DEFINE OFF

-- ---- Grade scale (points drive CGPA; points = 0 means fail) ----------
INSERT INTO grade_scale (grade, min_marks, points) VALUES ('S', 90, 10);
INSERT INTO grade_scale (grade, min_marks, points) VALUES ('A', 80, 9);
INSERT INTO grade_scale (grade, min_marks, points) VALUES ('B', 70, 8);
INSERT INTO grade_scale (grade, min_marks, points) VALUES ('C', 60, 7);
INSERT INTO grade_scale (grade, min_marks, points) VALUES ('D', 55, 6);
INSERT INTO grade_scale (grade, min_marks, points) VALUES ('E', 50, 5);
INSERT INTO grade_scale (grade, min_marks, points) VALUES ('F', 0,  0);

-- ---- Departments (HOD set after faculty exist) -----------------------
INSERT INTO department (dept_id, dept_name, hod_faculty_id) VALUES (1, 'Computer Science and Engineering', NULL);
INSERT INTO department (dept_id, dept_name, hod_faculty_id) VALUES (2, 'Electronics and Communication', NULL);

-- ---- Faculty ---------------------------------------------------------
INSERT INTO faculty (faculty_id, name, dept_id, designation, email) VALUES (1, 'Dr. Anand Kumar',   1, 'Professor',           'anand@univ.edu');
INSERT INTO faculty (faculty_id, name, dept_id, designation, email) VALUES (2, 'Dr. Beena Rao',     1, 'Associate Professor', 'beena@univ.edu');
INSERT INTO faculty (faculty_id, name, dept_id, designation, email) VALUES (3, 'Dr. Chandra Mohan', 1, 'Assistant Professor', 'chandra@univ.edu');
INSERT INTO faculty (faculty_id, name, dept_id, designation, email) VALUES (4, 'Dr. Deepa Nair',    2, 'Professor',           'deepa@univ.edu');

UPDATE department SET hod_faculty_id = 1 WHERE dept_id = 1;
UPDATE department SET hod_faculty_id = 4 WHERE dept_id = 2;

-- ---- Programs --------------------------------------------------------
INSERT INTO program (program_id, program_name, dept_id, total_credits_required) VALUES (1, 'B.Tech CSE',          1, 160);
INSERT INTO program (program_id, program_name, dept_id, total_credits_required) VALUES (2, 'B.Tech CSE (AI/ML)',  1, 160);
INSERT INTO program (program_id, program_name, dept_id, total_credits_required) VALUES (3, 'B.Tech ECE',          2, 160);

-- ---- Courses ---------------------------------------------------------
INSERT INTO course (course_id, course_code, title, credits, dept_id, course_type) VALUES (1, 'CS101', 'Programming Fundamentals', 4, 1, 'CORE');
INSERT INTO course (course_id, course_code, title, credits, dept_id, course_type) VALUES (2, 'CS201', 'Data Structures',          4, 1, 'CORE');
INSERT INTO course (course_id, course_code, title, credits, dept_id, course_type) VALUES (3, 'CS301', 'Database Systems',         3, 1, 'CORE');
INSERT INTO course (course_id, course_code, title, credits, dept_id, course_type) VALUES (4, 'CS302', 'Operating Systems',        3, 1, 'CORE');
INSERT INTO course (course_id, course_code, title, credits, dept_id, course_type) VALUES (5, 'CS401', 'Machine Learning',         3, 1, 'ELECTIVE');
INSERT INTO course (course_id, course_code, title, credits, dept_id, course_type) VALUES (6, 'MA101', 'Calculus',                 4, 1, 'CORE');
INSERT INTO course (course_id, course_code, title, credits, dept_id, course_type) VALUES (7, 'CS202', 'Algorithms',               4, 1, 'CORE');

-- ---- Prerequisites (chain: CS101 -> CS201 -> CS301 -> CS401; CS401 also needs CS202) ----
-- CS201 needs CS101
INSERT INTO prerequisite (course_id, prereq_course_id) VALUES (2, 1);
-- CS301 needs CS201
INSERT INTO prerequisite (course_id, prereq_course_id) VALUES (3, 2);
-- CS302 needs CS201
INSERT INTO prerequisite (course_id, prereq_course_id) VALUES (4, 2);
-- CS202 needs CS201
INSERT INTO prerequisite (course_id, prereq_course_id) VALUES (7, 2);
-- CS401 needs CS301
INSERT INTO prerequisite (course_id, prereq_course_id) VALUES (5, 3);
-- CS401 needs CS202
INSERT INTO prerequisite (course_id, prereq_course_id) VALUES (5, 7);

-- ---- Terms (term 1 past/completed, term 2 active for registration) ---
INSERT INTO term (term_id, term_name, start_date, end_date, is_active) VALUES (1, 'Fall 2025',   DATE '2025-08-01', DATE '2025-12-15', 'N');
INSERT INTO term (term_id, term_name, start_date, end_date, is_active) VALUES (2, 'Winter 2026', DATE '2026-01-05', DATE '2026-05-10', 'Y');

-- ---- Time slots (slot 1 and slot 2 overlap -> clash demo) ------------
INSERT INTO time_slot (slot_id, day_of_week, start_time, end_time) VALUES (1, 'MON', '09:00', '10:40');
INSERT INTO time_slot (slot_id, day_of_week, start_time, end_time) VALUES (2, 'MON', '09:30', '10:30');
INSERT INTO time_slot (slot_id, day_of_week, start_time, end_time) VALUES (3, 'TUE', '09:00', '10:40');
INSERT INTO time_slot (slot_id, day_of_week, start_time, end_time) VALUES (4, 'WED', '11:00', '12:40');
INSERT INTO time_slot (slot_id, day_of_week, start_time, end_time) VALUES (5, 'MON', '11:00', '12:40');

-- ---- Rooms (room 2 is deliberately small) ----------------------------
INSERT INTO room (room_id, building, room_capacity) VALUES (1, 'AB1-101', 60);
INSERT INTO room (room_id, building, room_capacity) VALUES (2, 'AB1-102', 30);
INSERT INTO room (room_id, building, room_capacity) VALUES (3, 'AB2-201', 60);

-- ---- Sections --------------------------------------------------------
-- Term 1 (completed-history sections)
-- CS101
INSERT INTO section (section_id, course_id, faculty_id, term_id, room_id, slot_id, capacity, enrolled_count) VALUES (1, 1, 1, 1, 1, 1, 60, 0);
-- CS201
INSERT INTO section (section_id, course_id, faculty_id, term_id, room_id, slot_id, capacity, enrolled_count) VALUES (2, 2, 1, 1, 1, 3, 60, 0);
-- CS301
INSERT INTO section (section_id, course_id, faculty_id, term_id, room_id, slot_id, capacity, enrolled_count) VALUES (3, 3, 2, 1, 1, 4, 60, 0);
-- CS202
INSERT INTO section (section_id, course_id, faculty_id, term_id, room_id, slot_id, capacity, enrolled_count) VALUES (4, 7, 1, 1, 1, 5, 60, 0);
-- Term 2 (active registration sections)
-- CS301 (needs CS201)
INSERT INTO section (section_id, course_id, faculty_id, term_id, room_id, slot_id, capacity, enrolled_count) VALUES (10, 3, 2, 2, 1, 1, 60, 2);
-- CS302 (slot clashes with sec 10)
INSERT INTO section (section_id, course_id, faculty_id, term_id, room_id, slot_id, capacity, enrolled_count) VALUES (11, 4, 3, 2, 3, 2, 60, 0);
-- CS401 (needs CS301 + CS202)
INSERT INTO section (section_id, course_id, faculty_id, term_id, room_id, slot_id, capacity, enrolled_count) VALUES (12, 5, 2, 2, 1, 4, 60, 0);
-- CS202 capacity 2 (full -> waitlist demo)
INSERT INTO section (section_id, course_id, faculty_id, term_id, room_id, slot_id, capacity, enrolled_count) VALUES (13, 7, 1, 2, 2, 5, 2,  2);
-- CS101 (no prereq -> easy success)
INSERT INTO section (section_id, course_id, faculty_id, term_id, room_id, slot_id, capacity, enrolled_count) VALUES (14, 1, 1, 2, 1, 3, 60, 0);

-- ---- Students --------------------------------------------------------
INSERT INTO student (student_id, reg_no, name, dob, email, program_id, admission_year, cgpa) VALUES (1, '24BAI0156', 'Ritvik Battula', DATE '2006-03-14', 'ritvik@univ.edu', 2, 2024, 0);
INSERT INTO student (student_id, reg_no, name, dob, email, program_id, admission_year, cgpa) VALUES (2, '24BCE2295', 'Rehaan Bahadur', DATE '2006-07-02', 'rehaan@univ.edu', 1, 2024, 0);
INSERT INTO student (student_id, reg_no, name, dob, email, program_id, admission_year, cgpa) VALUES (3, '24BCE2301', 'Neil Ajith Nair', DATE '2006-01-20', 'neil@univ.edu', 1, 2024, 0);
INSERT INTO student (student_id, reg_no, name, dob, email, program_id, admission_year, cgpa) VALUES (4, '24BCE1001', 'Sanjay Menon', DATE '2006-05-11', 'sanjay@univ.edu', 1, 2024, 0);
INSERT INTO student (student_id, reg_no, name, dob, email, program_id, admission_year, cgpa) VALUES (5, '24BCE1002', 'Priya Sharma', DATE '2006-09-30', 'priya@univ.edu', 1, 2024, 0);
INSERT INTO student (student_id, reg_no, name, dob, email, program_id, admission_year, cgpa) VALUES (6, '24BCE1003', 'Arjun Das', DATE '2006-11-08', 'arjun@univ.edu', 1, 2024, 0);

-- ---- Enrollments -----------------------------------------------------
-- Term 1 COMPLETED history (gives prerequisites + CGPA)
INSERT INTO enrollment (enrollment_id, student_id, section_id, status, grade, grade_points, enrolled_on) VALUES (1,  1, 1, 'COMPLETED', 'A', 9, DATE '2025-08-05');
INSERT INTO enrollment (enrollment_id, student_id, section_id, status, grade, grade_points, enrolled_on) VALUES (2,  2, 1, 'COMPLETED', 'A', 9, DATE '2025-08-05');
INSERT INTO enrollment (enrollment_id, student_id, section_id, status, grade, grade_points, enrolled_on) VALUES (3,  3, 1, 'COMPLETED', 'B', 8, DATE '2025-08-05');
INSERT INTO enrollment (enrollment_id, student_id, section_id, status, grade, grade_points, enrolled_on) VALUES (4,  4, 1, 'COMPLETED', 'B', 8, DATE '2025-08-05');
INSERT INTO enrollment (enrollment_id, student_id, section_id, status, grade, grade_points, enrolled_on) VALUES (5,  5, 1, 'COMPLETED', 'C', 7, DATE '2025-08-05');
INSERT INTO enrollment (enrollment_id, student_id, section_id, status, grade, grade_points, enrolled_on) VALUES (6,  1, 2, 'COMPLETED', 'A', 9, DATE '2025-08-05');
INSERT INTO enrollment (enrollment_id, student_id, section_id, status, grade, grade_points, enrolled_on) VALUES (7,  2, 2, 'COMPLETED', 'B', 8, DATE '2025-08-05');
INSERT INTO enrollment (enrollment_id, student_id, section_id, status, grade, grade_points, enrolled_on) VALUES (8,  3, 2, 'COMPLETED', 'B', 8, DATE '2025-08-05');
INSERT INTO enrollment (enrollment_id, student_id, section_id, status, grade, grade_points, enrolled_on) VALUES (9,  4, 2, 'COMPLETED', 'C', 7, DATE '2025-08-05');
INSERT INTO enrollment (enrollment_id, student_id, section_id, status, grade, grade_points, enrolled_on) VALUES (10, 1, 4, 'COMPLETED', 'A', 9, DATE '2025-08-05');
INSERT INTO enrollment (enrollment_id, student_id, section_id, status, grade, grade_points, enrolled_on) VALUES (11, 1, 3, 'COMPLETED', 'A', 9, DATE '2025-08-05');
INSERT INTO enrollment (enrollment_id, student_id, section_id, status, grade, grade_points, enrolled_on) VALUES (12, 2, 3, 'COMPLETED', 'B', 8, DATE '2025-08-05');
-- Term 2 current REGISTERED (fills sec 10 and sec 13)
INSERT INTO enrollment (enrollment_id, student_id, section_id, status, grade, grade_points, enrolled_on) VALUES (13, 3, 10, 'REGISTERED', NULL, NULL, DATE '2026-01-06');
INSERT INTO enrollment (enrollment_id, student_id, section_id, status, grade, grade_points, enrolled_on) VALUES (14, 4, 10, 'REGISTERED', NULL, NULL, DATE '2026-01-06');
INSERT INTO enrollment (enrollment_id, student_id, section_id, status, grade, grade_points, enrolled_on) VALUES (15, 3, 13, 'REGISTERED', NULL, NULL, DATE '2026-01-06');
INSERT INTO enrollment (enrollment_id, student_id, section_id, status, grade, grade_points, enrolled_on) VALUES (16, 4, 13, 'REGISTERED', NULL, NULL, DATE '2026-01-06');

COMMIT;


PROMPT ====== 05_functions ======
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


PROMPT ====== 06_procedures ======
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


PROMPT ====== 07_triggers ======
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
       :OLD.status,
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


PROMPT ====== 08_views ======
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

PROMPT ====== DONE. Expected: 9 sections, 16 enrollments, 6 prereqs ======
SELECT COUNT(*) AS sections FROM section;
SELECT COUNT(*) AS enrollments FROM enrollment;
SELECT COUNT(*) AS prereqs FROM prerequisite;
