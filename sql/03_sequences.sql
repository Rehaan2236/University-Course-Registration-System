-- =====================================================================
-- 03_sequences.sql : Surrogate-key sequences for rows created at runtime
-- by the PL/SQL API (enrollments, waitlist entries, audit rows).
-- Master/seed data uses small explicit IDs; sequences start high to
-- guarantee there is never a collision with seeded IDs.
-- =====================================================================
CREATE SEQUENCE enrollment_seq START WITH 100001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE waitlist_seq   START WITH 100001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE audit_seq      START WITH 100001 INCREMENT BY 1 NOCACHE;
