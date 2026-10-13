"""
University Course Registration System — Web Front End (thin client).

This server contains NO business logic. Every rule (prerequisites, timetable
clash, seat capacity, locking, CGPA, audit) lives in Oracle. The routes below
only:
  * CALL the stored procedures (sp_register_student, sp_drop_registration,
    sp_post_grade), and
  * SELECT from the reporting views (v_section_seats, v_student_cgpa, ...).

Run:
  pip install -r requirements.txt
  set ORA_USER=ucrs_user & set ORA_PASS=ucrs_pass & set ORA_DSN=localhost:1521/XEPDB1   (Windows)
  python app.py
  open http://127.0.0.1:5000
"""
import os
from flask import Flask, render_template, request, jsonify

try:
    import oracledb
except ImportError:
    raise SystemExit("python-oracledb missing. Run: pip install -r requirements.txt")

ORA_USER = os.getenv("ORA_USER", "ucrs_user")
ORA_PASS = os.getenv("ORA_PASS", "ucrs_pass")
ORA_DSN  = os.getenv("ORA_DSN",  "localhost:1521/XEPDB1")
ACTIVE_TERM = os.getenv("ACTIVE_TERM", "Winter 2026")

app = Flask(__name__)


def get_conn():
    # python-oracledb runs in thin mode -> no Oracle client install needed
    return oracledb.connect(user=ORA_USER, password=ORA_PASS, dsn=ORA_DSN)


def q(conn, sql, params=None):
    cur = conn.cursor()
    cur.execute(sql, params or {})
    cols = [c[0].lower() for c in cur.description]
    rows = [dict(zip(cols, r)) for r in cur.fetchall()]
    cur.close()
    return rows


def run_proc(name, args):
    """Call a stored procedure and capture its DBMS_OUTPUT / ORA error."""
    try:
        conn = get_conn()
    except Exception as e:
        return {"ok": False, "message": f"Database connection failed: {e}"}
    cur = conn.cursor()
    try:
        cur.callproc("dbms_output.enable")
        try:
            cur.callproc(name, args)          # procedures commit themselves
            line = cur.var(str); status = cur.var(int); out = []
            while True:
                cur.callproc("dbms_output.get_line", (line, status))
                if status.getvalue() != 0:
                    break
                v = line.getvalue()
                if v:
                    out.append(v)
            return {"ok": True, "message": "\n".join(out) or "Done."}
        except oracledb.DatabaseError as e:
            return {"ok": False, "message": e.args[0].message.strip()}
    finally:
        cur.close(); conn.close()


@app.route("/")
def index():
    return render_template("index.html", active_term=ACTIVE_TERM)


@app.route("/api/state")
def api_state():
    try:
        conn = get_conn()
    except Exception as e:
        return jsonify({"connected": False, "error": str(e),
                        "user": ORA_USER, "dsn": ORA_DSN})
    try:
        sections = q(conn, """
            SELECT section_id, course_code, title, term_name, faculty,
                   capacity, enrolled_count, seats_available, utilization_pct
              FROM v_section_seats WHERE term_name = :t
             ORDER BY section_id""", {"t": ACTIVE_TERM})
        students = q(conn, """
            SELECT student_id, reg_no, name, program_name, cgpa
              FROM v_student_cgpa ORDER BY student_id""")
        waitlist = q(conn, """
            SELECT section_id, course_code, reg_no, student_name, position
              FROM v_waitlist_status ORDER BY section_id, position""")
        audit = q(conn, """
            SELECT audit_id, reg_no, course_code, old_status, new_status,
                   changed_by, TO_CHAR(changed_at,'HH24:MI:SS') AS changed_at
              FROM v_enrollment_audit ORDER BY audit_id DESC""")
        faculty = q(conn, """
            SELECT faculty, sections, courses, total_registered
              FROM v_faculty_teaching_load WHERE term_name = :t
             ORDER BY faculty""", {"t": ACTIVE_TERM})
        kpis = {
            "sections": len(sections),
            "students": len(students),
            "waitlisted": len(waitlist),
            "avg_util": round(sum(s["utilization_pct"] or 0 for s in sections) /
                              max(len(sections), 1), 1),
        }
        return jsonify({"connected": True, "active_term": ACTIVE_TERM, "kpis": kpis,
                        "sections": sections, "students": students,
                        "waitlist": waitlist, "audit": audit, "faculty": faculty})
    finally:
        conn.close()


@app.route("/api/transcript/<int:student_id>")
def api_transcript(student_id):
    try:
        conn = get_conn()
    except Exception as e:
        return jsonify({"ok": False, "message": str(e)})
    try:
        rows = q(conn, """
            SELECT course_code, title, credits, grade, grade_points, term_name, status
              FROM v_student_transcript WHERE student_id = :s
             ORDER BY term_name, course_code""", {"s": student_id})
        info = q(conn, "SELECT reg_no, name, cgpa FROM v_student_cgpa WHERE student_id = :s",
                 {"s": student_id})
        return jsonify({"ok": True, "rows": rows, "info": info[0] if info else None})
    finally:
        conn.close()


@app.route("/api/register", methods=["POST"])
def api_register():
    d = request.get_json(force=True)
    return jsonify(run_proc("sp_register_student",
                            [int(d["student_id"]), int(d["section_id"])]))


@app.route("/api/drop", methods=["POST"])
def api_drop():
    d = request.get_json(force=True)
    return jsonify(run_proc("sp_drop_registration",
                            [int(d["student_id"]), int(d["section_id"])]))


@app.route("/api/grade", methods=["POST"])
def api_grade():
    d = request.get_json(force=True)
    return jsonify(run_proc("sp_post_grade",
                            [int(d["student_id"]), int(d["section_id"]), d["grade"]]))


if __name__ == "__main__":
    print(f"UCRS web client -> {ORA_USER}@{ORA_DSN}  (term: {ACTIVE_TERM})")
    app.run(host="127.0.0.1", port=5000, debug=False)