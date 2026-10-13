#!/usr/bin/env python3
"""
Thin-client CLI for the University Course Registration System.

This client contains NO business logic. It only:
  - CALLs Oracle stored procedures (sp_register_student, sp_drop_registration,
    sp_post_grade, sp_transcript), and
  - SELECTs from the reporting views.
All rules (prerequisites, clashes, capacity, locking, CGPA, audit) live in Oracle.

Setup:
  pip install -r requirements.txt
  export ORA_USER=ucrs_user ORA_PASS=ucrs_pass ORA_DSN=localhost:1521/XEPDB1
  python cli.py
(python-oracledb runs in "thin" mode, so no Oracle client install is needed.)
"""
import os
import sys

try:
    import oracledb
except ImportError:
    sys.exit("python-oracledb not installed. Run: pip install -r requirements.txt")

DSN  = os.getenv("ORA_DSN",  "localhost:1521/XEPDB1")
USER = os.getenv("ORA_USER", "ucrs_user")
PASS = os.getenv("ORA_PASS", "ucrs_pass")


def connect():
    try:
        return oracledb.connect(user=USER, password=PASS, dsn=DSN)
    except Exception as e:
        sys.exit(f"Cannot connect to Oracle ({USER}@{DSN}): {e}")


def drain_output(conn):
    """Print DBMS_OUTPUT produced by the last stored-proc call."""
    cur = conn.cursor()
    line = cur.var(str)
    status = cur.var(int)
    while True:
        cur.callproc("dbms_output.get_line", (line, status))
        if status.getvalue() != 0:
            break
        print("   " + (line.getvalue() or ""))


def call_proc(conn, name, args):
    cur = conn.cursor()
    cur.callproc("dbms_output.enable")
    try:
        cur.callproc(name, args)          # procedures commit themselves
        drain_output(conn)
    except oracledb.DatabaseError as e:
        (err,) = e.args
        print(f"   REJECTED: {err.message.strip()}")


def show(conn, sql, headers):
    cur = conn.cursor()
    cur.execute(sql)
    rows = cur.fetchall()
    if not rows:
        print("   (no rows)")
        return
    widths = [max(len(str(h)), *(len(str(r[i])) for r in rows)) for i, h in enumerate(headers)]
    print("   " + " | ".join(str(h).ljust(widths[i]) for i, h in enumerate(headers)))
    print("   " + "-+-".join("-" * w for w in widths))
    for r in rows:
        print("   " + " | ".join(str(r[i]).ljust(widths[i]) for i in range(len(headers))))


def ask_int(prompt):
    try:
        return int(input(prompt).strip())
    except ValueError:
        print("   Not a number."); return None


MENU = """
============== UNIVERSITY COURSE REGISTRATION (thin client) ==============
 1. List active-term sections (seats)
 2. Register a student into a section
 3. Drop a registration (auto-promotes waitlist)
 4. Post a grade (updates CGPA)
 5. Show student transcript
 6. Section roster
 7. Waitlist status
 8. Faculty teaching load
 9. Students above program-average CGPA
10. Enrollment audit trail
 0. Exit
=========================================================================="""


def main():
    conn = connect()
    print(f"Connected as {USER}@{DSN}")
    while True:
        print(MENU)
        choice = input("Choose: ").strip()
        if choice == "0":
            break
        elif choice == "1":
            show(conn, """SELECT section_id, course_code, capacity, enrolled_count, seats_available
                          FROM v_section_seats WHERE term_name='Winter 2026' ORDER BY section_id""",
                 ["SEC", "COURSE", "CAP", "ENROLLED", "FREE"])
        elif choice == "2":
            s = ask_int("   student_id: "); sec = ask_int("   section_id: ")
            if s and sec: call_proc(conn, "sp_register_student", [s, sec])
        elif choice == "3":
            s = ask_int("   student_id: "); sec = ask_int("   section_id: ")
            if s and sec: call_proc(conn, "sp_drop_registration", [s, sec])
        elif choice == "4":
            s = ask_int("   student_id: "); sec = ask_int("   section_id: ")
            g = input("   grade (S/A/B/C/D/E/F): ").strip().upper()
            if s and sec: call_proc(conn, "sp_post_grade", [s, sec, g])
        elif choice == "5":
            s = ask_int("   student_id: ")
            if s: call_proc(conn, "sp_transcript", [s])
        elif choice == "6":
            sec = ask_int("   section_id: ")
            if sec: show(conn, f"""SELECT reg_no, student_name, status, NVL(grade,'-')
                                   FROM v_section_roster WHERE section_id={sec} ORDER BY reg_no""",
                         ["REG_NO", "NAME", "STATUS", "GRADE"])
        elif choice == "7":
            show(conn, """SELECT section_id, course_code, reg_no, student_name, position
                          FROM v_waitlist_status ORDER BY section_id, position""",
                 ["SEC", "COURSE", "REG_NO", "NAME", "POS"])
        elif choice == "8":
            show(conn, """SELECT faculty, sections, courses, total_registered
                          FROM v_faculty_teaching_load WHERE term_name='Winter 2026' ORDER BY faculty""",
                 ["FACULTY", "SECTIONS", "COURSES", "REGISTERED"])
        elif choice == "9":
            show(conn, """SELECT st.reg_no, st.name, st.cgpa, pa.avg_cgpa
                          FROM student st JOIN program p ON p.program_id=st.program_id
                          JOIN (SELECT program_id, ROUND(AVG(cgpa),2) avg_cgpa FROM student GROUP BY program_id) pa
                            ON pa.program_id=st.program_id
                          WHERE st.cgpa > pa.avg_cgpa ORDER BY st.cgpa DESC""",
                 ["REG_NO", "NAME", "CGPA", "PROG_AVG"])
        elif choice == "10":
            show(conn, """SELECT audit_id, reg_no, course_code, old_status, new_status, changed_by
                          FROM v_enrollment_audit ORDER BY audit_id""",
                 ["ID", "REG_NO", "COURSE", "OLD", "NEW", "BY"])
        else:
            print("   Unknown option.")
    conn.close()
    print("Bye.")


if __name__ == "__main__":
    main()
