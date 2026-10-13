# Viva Questions \& Short Answers

**Why Oracle?** It gives ACID transactions, row-level locking and PL/SQL, which we
need for safe concurrent registration and for keeping rules inside the database.

**Why a relational database?** The data is structured and highly inter-related
(students, sections, enrollments); integrity is naturally expressed with keys and
constraints; the workload is joins + aggregation.

**Why BCNF?** It removes update/insert/delete anomalies by ensuring every
determinant is a candidate key, so each fact is stored once.

**Primary key of each table?** dept\_id, program\_id, student\_id, faculty\_id,
course\_id, (course\_id,prereq\_course\_id), term\_id, slot\_id, room\_id, section\_id,
enrollment\_id, waitlist\_id, grade, audit\_id.

**Why is PREREQUISITE a separate table?** A course can have many prerequisites
(a multivalued relationship); a separate table keeps 1NF/4NF and models the
recursive M:N "course requires course".

**How is the recursive relationship represented?** `PREREQUISITE(course\_id, prereq\_course\_id)` — both columns are foreign keys to `COURSE`.

**How is timetable clash detected?** For the same term, we join the student's
REGISTERED sections to their time slots and test overlap:
`same day AND start1 < end2 AND start2 < end1`.

**How are prerequisites checked?** `fn\_prereqs\_met` returns 'N' if any immediate
prerequisite has no COMPLETED, passing enrollment. Chains hold transitively.

**Why triggers?** To maintain derived data (`enrolled\_count`, `cgpa`) and to log
audit rows automatically, so no operation can bypass them.

**Why stored procedures?** To bundle the multi-step registration/drop/grade logic
with transaction control and clear error messages, callable from any client.

**Why functions?** Reusable, read-only computations (CGPA, prereq check, seats)
usable inside SQL and other PL/SQL.

**Why cursors?** `sp\_transcript` iterates a student's enrollments row by row to
format a transcript — a natural per-row task.

**How does row-level locking prevent over-allocation?** `sp\_register\_student`
does `SELECT ... FOR UPDATE` on the section row first; a second session blocks
until the first commits, so only one can take the last seat.

**What if two students try the last seat?** First locks the row, registers, commits
(seat now full). Second then proceeds, sees it full, and is waitlisted.

**How does waitlist promotion work?** On a drop, `sp\_promote\_waitlist` picks the
earliest waitlist position, re-checks prerequisites and clash, then registers that
student and removes them from the waitlist — all in the same transaction.

**How is CGPA calculated?** Credit-weighted: `SUM(credits×grade\_points) / SUM(credits)` over COMPLETED enrollments; recomputed by a compound trigger on
grade/status change.

**Purpose of the audit table?** Accountability — it records every enrollment
status change with old/new status, who, and when.

**Which constraints are declarative?** PK, FK, UNIQUE, NOT NULL and CHECK
(credits, capacity, enrolled\_count≤capacity, status/type enums, points, self-prereq).

**Which rules need triggers/procedures?** Prerequisite + clash checks and atomic
registration (procedures, because they read ENROLLMENT while writing it and must
raise clear errors); derived-data maintenance + audit (triggers).

**How is the database normalized?** From a denormalized sheet, we decomposed along
functional dependencies to BCNF, isolating the multivalued prerequisite relation
to reach 4NF.

**Explain 1NF–BCNF here.** 1NF: atomic columns, prerequisites moved to their own
table. 2NF: grade/status depend on the whole (student,section) key → ENROLLMENT.
3NF: removed transitive deps (reg\_no→program→program\_name). BCNF: every
determinant is a candidate key of its table.

**Important functional dependencies?** reg\_no→student attrs; course\_code→course
attrs; section\_id→course/faculty/term/room/slot; (student,section)→status,grade;
grade→grade\_points.

**What if there were no locking?** Two concurrent registrations could both read
"1 seat free" and both insert, exceeding capacity (lost-update / over-allocation).

**Why is the application only a thin client?** So rules are defined once, in the
database, and cannot be bypassed or duplicated inconsistently by any client.

