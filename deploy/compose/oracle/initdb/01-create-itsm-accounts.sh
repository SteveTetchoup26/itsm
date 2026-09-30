#!/usr/bin/env bash
# Creates the ITSM accounts in FREEPDB1 (ADR-005).
# Run once by the image entrypoint, as the oracle OS user, on the first database startup only.
set -euo pipefail

: "${ITSM_OWNER_PASSWORD:?ITSM_OWNER_PASSWORD is not set}"
: "${ITSM_APP_PASSWORD:?ITSM_APP_PASSWORD is not set}"

# Passwords go through stdin (heredoc), never on the command line: they do not appear in `ps`.
sqlplus -s / as sysdba <<SQL
WHENEVER SQLERROR EXIT SQL.SQLCODE
ALTER SESSION SET CONTAINER = FREEPDB1;

-- Schema owner, used by Flyway only: can create objects in its own schema, nothing else.
CREATE USER ITSM_OWNER IDENTIFIED BY "${ITSM_OWNER_PASSWORD}"
  DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE,
      CREATE PROCEDURE, CREATE TRIGGER, CREATE TYPE TO ITSM_OWNER;

-- Data access for the application; each Flyway migration grants table privileges to this role.
-- The owner needs nothing on the role: granting privileges on its own objects is always allowed.
CREATE ROLE ITSM_APP_ROLE;

-- Application account: connect and use the role, no quota, cannot create any object.
CREATE USER ITSM_APP IDENTIFIED BY "${ITSM_APP_PASSWORD}";
GRANT CREATE SESSION TO ITSM_APP;
GRANT ITSM_APP_ROLE TO ITSM_APP;

EXIT
SQL

echo "ITSM accounts created in FREEPDB1."
