-- Creates the ITSM accounts in the Autonomous Database (production), same model as
-- deploy/compose/oracle/initdb/01-create-itsm-accounts.sh (ADR-005).
-- Run once, connected as ADMIN with SQLcl:  sql ADMIN@"$ITSM_ADB_TP" @deploy/adb/create-itsm-accounts.sql
-- Passwords are typed when prompted (hidden): they are never stored in a file or in the history.

-- Substituted values (the passwords) must not be echoed back by SQLcl.
SET VERIFY OFF
SET FEEDBACK ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

ACCEPT owner_password CHAR PROMPT 'ITSM_OWNER password: ' HIDE
ACCEPT app_password   CHAR PROMPT 'ITSM_APP password: '   HIDE

-- Service accounts: the password never expires (an expired application password is an outage).
-- The other limits, including the CLOUD_VERIFY_FUNCTION complexity rules, come from DEFAULT.
CREATE PROFILE ITSM_SERVICE_PROFILE LIMIT
  PASSWORD_LIFE_TIME UNLIMITED;

-- Schema owner, used by Flyway only: can create objects in its own schema, nothing else.
-- No USERS tablespace in Autonomous Database: user data goes to DATA.
CREATE USER ITSM_OWNER IDENTIFIED BY "&owner_password"
  DEFAULT TABLESPACE DATA QUOTA UNLIMITED ON DATA
  PROFILE ITSM_SERVICE_PROFILE;
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE,
      CREATE PROCEDURE, CREATE TRIGGER, CREATE TYPE TO ITSM_OWNER;

-- Data access for the application; each Flyway migration grants table privileges to this role.
CREATE ROLE ITSM_APP_ROLE;

-- Application account: connect and use the role, no quota, cannot create any object.
CREATE USER ITSM_APP IDENTIFIED BY "&app_password"
  PROFILE ITSM_SERVICE_PROFILE;
GRANT CREATE SESSION TO ITSM_APP;
GRANT ITSM_APP_ROLE TO ITSM_APP;

UNDEFINE owner_password
UNDEFINE app_password

-- Check: both accounts open, on the service profile, with the expected default tablespace.
SELECT username, account_status, profile, default_tablespace, expiry_date
FROM   dba_users
WHERE  username IN ('ITSM_OWNER', 'ITSM_APP')
ORDER  BY username;
