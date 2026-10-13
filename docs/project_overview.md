# Project Overview, Problem, Objectives & Requirement Analysis

## Domain & problem
University course registration is data-intensive and rule-heavy. Done manually
it produces over-allocated seats, prerequisite violations, timetable clashes and
hand-computed CGPA errors. This project makes the **database** the authoritative
rule-enforcer so integrity holds even under concurrent registration.

## Objectives
1. Normalized (BCNF) schema for students, programs, courses, prerequisites,
   sections, enrollments, waitlists and grades.
2. Enforce seat capacity, prerequisite completion and timetable non-conflict in
   the database.
3. Correct concurrent registration via transactions + row-level locking.
4. Automate CGPA and transcript generation (functions + cursors).
5. Analytical reporting (seats, utilization, faculty load, performance) via views.
6. Full enrollment audit trail.

## Requirement analysis
**Data stored:** departments, programs, faculty, course catalogue + credits +
type, prerequisite edges, terms, time slots, rooms, section offerings + capacity,
enrollments + status + grade, waitlist entries + position, grade scale, audit log.

**Users:** Student (search/register/drop, view transcript+CGPA); Faculty (rosters,
teaching load, post grades); Registrar/Admin (master data, waitlists, reports).

**Operations:** register (with locking + rule checks), drop + promote waitlist,
post grade + recompute CGPA, audit every status change, run analytics, generate
transcripts.

**Retrieval/analysis:** transcript + CGPA; section roster; seats remaining +
utilization %; faculty load; students who meet all prerequisites for a course but
haven't registered; students above their program's average CGPA; audit history;
waitlist status.
