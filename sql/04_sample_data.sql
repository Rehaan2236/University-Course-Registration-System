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
INSERT INTO prerequisite (course_id, prereq_course_id) VALUES (2, 1);  -- CS201 needs CS101
INSERT INTO prerequisite (course_id, prereq_course_id) VALUES (3, 2);  -- CS301 needs CS201
INSERT INTO prerequisite (course_id, prereq_course_id) VALUES (4, 2);  -- CS302 needs CS201
INSERT INTO prerequisite (course_id, prereq_course_id) VALUES (7, 2);  -- CS202 needs CS201
INSERT INTO prerequisite (course_id, prereq_course_id) VALUES (5, 3);  -- CS401 needs CS301
INSERT INTO prerequisite (course_id, prereq_course_id) VALUES (5, 7);  -- CS401 needs CS202

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
INSERT INTO section (section_id, course_id, faculty_id, term_id, room_id, slot_id, capacity, enrolled_count) VALUES (1, 1, 1, 1, 1, 1, 60, 0); -- CS101
INSERT INTO section (section_id, course_id, faculty_id, term_id, room_id, slot_id, capacity, enrolled_count) VALUES (2, 2, 1, 1, 1, 3, 60, 0); -- CS201
INSERT INTO section (section_id, course_id, faculty_id, term_id, room_id, slot_id, capacity, enrolled_count) VALUES (3, 3, 2, 1, 1, 4, 60, 0); -- CS301
INSERT INTO section (section_id, course_id, faculty_id, term_id, room_id, slot_id, capacity, enrolled_count) VALUES (4, 7, 1, 1, 1, 5, 60, 0); -- CS202
-- Term 2 (active registration sections)
INSERT INTO section (section_id, course_id, faculty_id, term_id, room_id, slot_id, capacity, enrolled_count) VALUES (10, 3, 2, 2, 1, 1, 60, 2); -- CS301 (needs CS201)
INSERT INTO section (section_id, course_id, faculty_id, term_id, room_id, slot_id, capacity, enrolled_count) VALUES (11, 4, 3, 2, 3, 2, 60, 0); -- CS302 (slot clashes with sec 10)
INSERT INTO section (section_id, course_id, faculty_id, term_id, room_id, slot_id, capacity, enrolled_count) VALUES (12, 5, 2, 2, 1, 4, 60, 0); -- CS401 (needs CS301 + CS202)
INSERT INTO section (section_id, course_id, faculty_id, term_id, room_id, slot_id, capacity, enrolled_count) VALUES (13, 7, 1, 2, 2, 5, 2,  2); -- CS202 capacity 2 (full -> waitlist demo)
INSERT INTO section (section_id, course_id, faculty_id, term_id, room_id, slot_id, capacity, enrolled_count) VALUES (14, 1, 1, 2, 1, 3, 60, 0); -- CS101 (no prereq -> easy success)

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
