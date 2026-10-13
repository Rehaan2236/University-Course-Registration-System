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
