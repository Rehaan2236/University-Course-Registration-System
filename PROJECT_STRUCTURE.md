# Project Structure & Design Notes

```
UCRS/
├── README.md                 Full setup, run, demo and troubleshooting guide
├── QUICK_START.md            5-minute path
├── PROJECT_STRUCTURE.md      This file (tree + design decisions/corrections)
├── sql/
│   ├── 00_cleanup.sql        Drop all objects (idempotent)
│   ├── 01_create_tables.sql  14 tables, PK/UNIQUE/CHECK/NOT NULL
│   ├── 02_constraints.sql    All foreign keys (with ON DELETE behaviour)
│   ├── 03_sequences.sql      enrollment_seq, waitlist_seq, audit_seq
│   ├── 04_sample_data.sql    Deterministic demo data (70 rows)
│   ├── 05_functions.sql      reg_ctx package + fn_prereqs_met / fn_calculate_cgpa /
│   │                         fn_student_cgpa / fn_seats_available
│   ├── 06_procedures.sql     sp_register_student / sp_promote_waitlist /
│   │                         sp_drop_registration / sp_post_grade / sp_transcript
│   ├── 07_triggers.sql       trg_enrollment_audit / trg_section_enrolled_count /
│   │                         trg_enrollment_cgpa (compound) + derived resync
│   ├── 08_views.sql          7 reporting views (v_*)
│   ├── 09_reports.sql        Analytical queries A–K
│   ├── 10_tests.sql          9 functional tests (pass + fail cases)
│   ├── 11_demo.sql           10-step guided demo
│   ├── run_all.sql           Runs 00→08 in order
│   └── setup_all_in_one.sql  Single-file version of the full setup
├── diagrams/                 er_diagram.mmd, architecture.mmd, registration_sequence.mmd
├── docs/                     overview, database_design, architecture, er_diagram,
│                             demo_script, viva_questions
├── demo/                     README (incl. concurrency) + demo_commands.sql
└── application/              Python thin clients (no business logic; call sp_* / read v_*)
    ├── README.md             CLI notes
    ├── cli.py                Optional command-line client
    ├── requirements.txt      CLI dependencies (python-oracledb)
    └── web/                  Web dashboard front end (Flask)
        ├── README.md         Run instructions + UI demo flow
        ├── app.py            Flask server: /api/state, /api/transcript/<id>,
        │                     /api/register, /api/drop, /api/grade
        ├── requirements.txt  Flask + python-oracledb
        ├── templates/
        │   └── index.html    Dashboard page (sections, action console, view tabs)
        └── static/
            ├── app.js        Fetches the API, renders tables, demo chips
            └── style.css     Dashboard styling
```

## Front-end architecture
The web dashboard is a thin client: `app.js` calls the Flask JSON routes, and
`app.py` only invokes `sp_register_student`, `sp_drop_registration` and
`sp_post_grade` and selects from the `v_*` views. Prerequisite, clash, capacity,
locking, CGPA and audit rules all stay in Oracle; Oracle's `ORA-2000x` messages
are passed back to the UI unchanged. Connection settings come from the
`ORA_USER`, `ORA_PASS`, `ORA_DSN` and `ACTIVE_TERM` environment variables.

## Execution order (why it matters)
Tables → constraints → sequences → **sample data** → functions → procedures →
triggers → views. Sample data is loaded *before* triggers exist, so
`section.enrolled_count` and `student.cgpa` are seeded correctly and then
re-synced by the last block of `07_triggers.sql`. From then on the triggers
maintain them automatically.

## Design decisions & corrections (vs. the proposal)
The schema follows the proposal exactly (same 14 entities, keys, relationships,
BCNF). The following are small, compatible implementation choices — documented
here as required, none change the data model:

1. **Surrogate-key sequences** (`enrollment_seq`, `waitlist_seq`, `audit_seq`)
   generate IDs for rows created at runtime. Seed rows use explicit small IDs;
   sequences start at 100001 so they can never collide.
2. **`reg_ctx` package** holds the "actor" so the audit trigger can fill
   `changed_by`. The proposal states `changed_by` is supplied by the calling
   procedure — this is the mechanism for that.
3. **Time stored as `VARCHAR2(5)` `'HH24:MI'`** (zero-padded). Lexical comparison
   is correct for overlap detection and keeps the demo data readable.
4. **`enrolled_count` counts `REGISTERED` only.** Posting a grade moves an
   enrollment to `COMPLETED`, which frees the count (the registration has
   concluded). This is the intended end-of-term behaviour.
5. **CGPA** is credit-weighted over `COMPLETED` enrollments
   (`SUM(credits×points)/SUM(credits)`), recomputed by a compound trigger.
6. **Prerequisite checking uses immediate prerequisites.** Chains
   (CS101→CS201→CS301) are enforced transitively: a student can only have
   completed CS201 if CS101 was completed when CS201 was taken. A recursive
   `CONNECT BY` query (report K) is included to *display* the full chain.
7. **Why some rules are procedures, not triggers:** prerequisite and clash
   checks need to read `ENROLLMENT` while inserting into it, which a row trigger
   cannot do (mutating-table error) and which must also raise clear, atomic
   errors. They therefore live in `sp_register_student`. CGPA uses a *compound*
   trigger precisely to avoid the mutating-table problem.
8. **`grade_points` on `ENROLLMENT`** is a snapshot of `grade_scale.points` at
   grading time (the proposal includes this column); it preserves historical
   transcripts even if the scale is later edited.
