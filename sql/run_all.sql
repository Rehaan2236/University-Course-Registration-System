-- =====================================================================
-- run_all.sql : One-shot setup. In SQL Developer open this file and press
-- F5 (Run Script), OR in SQL*Plus:  @run_all.sql
-- Run from inside the sql/ folder so the @@ relative paths resolve.
-- =====================================================================
SET DEFINE OFF
SET SERVEROUTPUT ON SIZE UNLIMITED
SET ECHO OFF

PROMPT ====== 00 cleanup ======
@@00_cleanup.sql
PROMPT ====== 01 create tables ======
@@01_create_tables.sql
PROMPT ====== 02 constraints (foreign keys) ======
@@02_constraints.sql
PROMPT ====== 03 sequences ======
@@03_sequences.sql
PROMPT ====== 04 sample data ======
@@04_sample_data.sql
PROMPT ====== 05 functions + context package ======
@@05_functions.sql
PROMPT ====== 06 procedures ======
@@06_procedures.sql
PROMPT ====== 07 triggers + derived-column resync ======
@@07_triggers.sql
PROMPT ====== 08 views ======
@@08_views.sql
PROMPT ====== SETUP COMPLETE ======
PROMPT Next: run 10_tests.sql, or 11_demo.sql, or 09_reports.sql.
