# ER Diagram

The machine-readable diagram is `diagrams/er_diagram.mmd` (Mermaid). Paste it into
<https://mermaid.live> to export an image, or import the entities/relationships
into Draw.io / Lucidchart.

## Relationships & cardinalities
| Relationship | Between | Cardinality |
|---|---|---|
| offers | DEPARTMENT → PROGRAM / COURSE | 1 : N |
| employs | DEPARTMENT → FACULTY | 1 : N |
| headed_by | DEPARTMENT → FACULTY (HOD) | 1 : 1 (optional) |
| enrolls | PROGRAM → STUDENT | 1 : N |
| requires | COURSE → COURSE (via PREREQUISITE) | M : N (recursive) |
| offered_as / teaches / scheduled_in / hosted_in / timed_at | COURSE/FACULTY/TERM/ROOM/TIME_SLOT → SECTION | 1 : N |
| registers | STUDENT → SECTION (via ENROLLMENT) | M : N (associative) |
| waitlisted | SECTION / STUDENT → WAITLIST | 1 : N |
| classified_by | GRADE_SCALE → ENROLLMENT | 1 : N |
| logged_in | ENROLLMENT → ENROLLMENT_AUDIT | 1 : N |

The recursive `COURSE`–`PREREQUISITE`–`COURSE` edge and the attributed M:N
`ENROLLMENT` (carries status + grade) are what make the model non-trivial.
