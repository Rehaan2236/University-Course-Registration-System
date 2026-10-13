# System Architecture / Workflow

```
Users → Application/Thin Client → Oracle Database → Output
```

- **Users:** Student, Faculty, Registrar/Admin.
- **Thin client:** Python CLI (`application/cli.py`) or SQL Developer. Issues
  `CALL sp_...` and `SELECT ... FROM v_...`. **No business logic.**
- **Oracle database:**
  - Base tables + declarative constraints
  - PL/SQL procedures/functions (the API) and an explicit cursor for transcripts
  - Triggers: audit logging, `enrolled_count` maintenance, CGPA recomputation
  - Transactions + `SELECT ... FOR UPDATE` row locking for safe concurrency
  - Reporting views
- **Output:** register/reject messages, transcript + CGPA, seat/faculty reports,
  audit trail.

See `diagrams/architecture.mmd` and `diagrams/registration_sequence.mmd`.

## Registration control flow
lock section row → check prerequisites → check timetable clash → seat available?
→ INSERT enrollment (REGISTERED) **or** INSERT waitlist → triggers update
`enrolled_count`, CGPA and audit → COMMIT (ROLLBACK + clear error on any failure).
