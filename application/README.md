# Optional Thin-Client CLI

A small, **optional** command-line interface. The database is the project; this
is only a convenience front-end for the live demo. It holds **no business logic**
— it calls the Oracle procedures and reads the views.

## Why this is a "thin client"
Every rule (prerequisites, timetable clash, seat capacity, row-level locking,
CGPA, audit) runs inside Oracle. `cli.py` just issues `CALL sp_...` and `SELECT
... FROM v_...`. You can delete this folder and the project still works entirely
through SQL Developer.

## Run
```bash
pip install -r requirements.txt
# point it at your Oracle XE pluggable DB and schema user:
export ORA_USER=ucrs_user
export ORA_PASS=ucrs_pass
export ORA_DSN=localhost:1521/XEPDB1
python cli.py
```
`python-oracledb` runs in **thin mode**, so no Oracle Instant Client is required.

If you prefer not to use Python at all, run `sql/11_demo.sql` in SQL Developer —
it demonstrates every feature with no external dependency.
