# Demo Folder

- `demo_commands.sql` — copy-paste version of the guided demo.
- Full spoken script: `../docs/demo_script.md`.

## Concurrency demonstration (the "last seat" problem)

This needs **two SQL Developer worksheets** (two sessions), both connected as
`ucrs_user`. We use a section with exactly one free seat.

### Prepare a 1-seat-free section
```sql
-- Session A (setup): free one seat in section 13 (capacity 2) by dropping Sanjay,
-- but DO NOT let the waitlist refill it for this test:
BEGIN sp_drop_registration(4, 13); END;
/
-- If anyone was promoted, drop them too so exactly one seat is free, then confirm:
SELECT seats_available FROM v_section_seats WHERE section_id = 13;  -- want 1
```

### Show the lock
```sql
-- Session A: lock the section row and PAUSE (do not commit yet)
SELECT capacity, enrolled_count FROM section WHERE section_id = 13 FOR UPDATE;
```
```sql
-- Session B: try to register for the same section — this call will BLOCK,
-- because sp_register_student also does SELECT ... FOR UPDATE on that row.
BEGIN sp_register_student(2, 13); END;
/
```
Session B now waits. This is the lock doing its job — the second registrant
cannot read/modify the seat count until Session A finishes.

```sql
-- Session A: release the lock
COMMIT;   -- or ROLLBACK
```
Session B immediately unblocks, re-reads the (now committed) seat count, and
either takes the last seat or is waitlisted. **Capacity is never exceeded.**

> Takeaway: without `FOR UPDATE`, both sessions could read "1 seat free" and both
> insert, over-allocating the section. The row lock serialises them.
