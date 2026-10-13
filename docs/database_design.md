# Database Selection, Justification & Data Model

## Database selection
- **Technology:** Oracle Database (Oracle XE for development)
- **Type:** Relational (RDBMS) with PL/SQL

## Justification (specific to this project)
1. **Highly relational data** — student↔program, section↔course, enrollment
   linking student↔section — captured directly by foreign keys; a document/
   key-value store would duplicate data or push joins into the app.
2. **Declarative integrity** — seat limits, grade domains, unique (student,
   section), and links across 14 tables are natural `CHECK`/`UNIQUE`/`PK`/`FK`
   constraints.
3. **Concurrency correctness** — the last-seat problem needs ACID + `SELECT ...
   FOR UPDATE` locking; a non-transactional NoSQL store cannot guarantee it.
4. **Logic beside data** — prerequisite enforcement, waitlist promotion and CGPA
   need triggers/cursors/procedures; PL/SQL keeps them unbypassable.
5. **Relational-analytical workload** — transcripts/reports are multi-table
   joins, correlated subqueries and `GROUP BY` aggregation.

A **graph DB** was considered (prerequisites form a DAG) but the dominant workload
is transactional registration + tabular reporting, so one indexed recursive table
(`PREREQUISITE`, queried with `CONNECT BY`) is simpler and sufficient. A
**document DB** was rejected: embedding enrollments inside student documents
duplicates course/section data and loses transactional seat control.

## Entities (14)
DEPARTMENT, PROGRAM, STUDENT, FACULTY, COURSE, PREREQUISITE, TERM, TIME_SLOT,
ROOM, SECTION, ENROLLMENT, WAITLIST, GRADE_SCALE, ENROLLMENT_AUDIT.
Full attributes, keys and the relational schema are in `sql/01_create_tables.sql`
and `sql/02_constraints.sql`; cardinalities are in `diagrams/er_diagram.mmd`.

## Keys & constraints (highlights)
- PKs on every table; `PREREQUISITE` has composite PK `(course_id, prereq_course_id)`.
- `UNIQUE(student_id, section_id)`, `UNIQUE(reg_no)`, `UNIQUE(course_code)`.
- `CHECK` credits 1–6, capacity>0, enrolled_count≤capacity, status/type enums,
  points 0–10, prerequisite not self-referential.
- FK `ON DELETE CASCADE` on audit→enrollment and prerequisite→course; others restrict.

## Normalization (BCNF)
Starting from a denormalized REG_SHEET and its functional dependencies, each
determinant (`reg_no`, `program_id`, `dept_id`, `course_code`, `faculty_id`,
`section_id`, `term_id`, `slot_id`, `grade`) becomes the key of its own table →
every table is in BCNF; the multivalued "course → many prerequisites" is isolated
in `PREREQUISITE` → 4NF. See the proposal §8.5 for the full FD list and anomalies.

## Assumptions
One slot + one room per section per term; one program per student; prerequisite
= COMPLETED with passing grade; `changed_by` passed by the calling procedure;
a student can be waitlisted for a section only if not already registered in it.
