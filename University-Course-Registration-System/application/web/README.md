# Web Front End (thin client)

A browser dashboard for the live demo. It contains **no business logic** — it
calls the same Oracle stored procedures and reads the same views as the SQL
demo. Every rule still runs inside the database.

## Run (Windows / macOS / Linux)
```bash
cd application/web
pip install -r requirements.txt

# point it at your Oracle XE schema (defaults shown):
#   Windows (cmd):  set ORA_USER=ucrs_user & set ORA_PASS=ucrs_pass & set ORA_DSN=localhost:1521/XEPDB1
#   PowerShell:     $env:ORA_USER="ucrs_user"; $env:ORA_PASS="ucrs_pass"; $env:ORA_DSN="localhost:1521/XEPDB1"
#   macOS/Linux:    export ORA_USER=ucrs_user ORA_PASS=ucrs_pass ORA_DSN=localhost:1521/XEPDB1

python app.py
```
Open **http://127.0.0.1:5000**. `python-oracledb` runs in thin mode, so no
Oracle client install is needed. Make sure the schema is built first
(`sql/run_all.sql`).

## What it shows
- Live course sections with seat counts and utilization bars
- Action console: Register / Drop / Post grade — Oracle's exact reply (including
  ORA-20001 / ORA-20002 rejections) is printed in the console
- Students with CGPA, transcripts, waitlist, audit trail, faculty load
- One-click **demo shortcuts** that pre-fill each scenario

## Demo flow in the UI
1. Register tab → "Success · Arjun→CS101" → Register student
2. "Prereq fail · Priya→CS301" → see ORA-20001 in the console
3. "Clash · Neil→CS302" → see ORA-20002
4. "Full→waitlist · Rehaan→CS202" → Register → Waitlist tab shows him
5. Drop tab → "Drop Sanjay→CS202" → waitlist promotes automatically
6. Post grade tab → "Grade Neil CS301 = A" → Students tab CGPA updates; Audit tab fills

If the top-right pill shows **not connected**, start Oracle XE / the schema and
click Refresh.