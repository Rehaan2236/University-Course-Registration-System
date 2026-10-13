# Quick Start (5 minutes)

1. **Create the schema user** (as SYSTEM on service `XEPDB1`):
   ```sql
   CREATE USER ucrs_user IDENTIFIED BY ucrs_pass;
   GRANT CONNECT, RESOURCE TO ucrs_user;
   ALTER USER ucrs_user QUOTA UNLIMITED ON USERS;
   ```
2. **Connect** in SQL Developer as `ucrs_user` (host `localhost`, port `1521`, service `XEPDB1`).
3. **Build everything:** open `sql/run_all.sql`, press **F5**. Wait for `SETUP COMPLETE`.
4. **See it work:** `SET SERVEROUTPUT ON`, then open `sql/11_demo.sql`, press **F5**.
5. **Transcript:** `BEGIN sp_transcript(1); END;` then `/`.

That's it. Everything else (tests, reports, CLI) is optional and described in `README.md`.

### Key demo IDs
| What | ID |
|---|---|
| Ritvik / Rehaan / Neil / Sanjay / Priya / Arjun | student 1 / 2 / 3 / 4 / 5 / 6 |
| CS101 no-prereq section (success) | section 14 |
| CS301 section (prereq needed) | section 10 |
| CS302 section (clashes with 10) | section 11 |
| CS202 full section (waitlist) | section 13 |
| CS401 section (needs CS301+CS202) | section 12 |
