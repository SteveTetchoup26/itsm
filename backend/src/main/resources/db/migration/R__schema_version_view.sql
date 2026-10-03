-- Current schema version, exposed to the application without granting access to the
-- whole Flyway history (script names, checksums, installers).
-- Depends on spring.flyway.table = FLYWAY_SCHEMA_HISTORY; Flyway's columns are lowercase.

CREATE OR REPLACE VIEW SCHEMA_VERSION AS
SELECT "version"      AS VERSION,
       "installed_on" AS INSTALLED_ON
FROM FLYWAY_SCHEMA_HISTORY
WHERE "success" = 1
  AND "version" IS NOT NULL
ORDER BY "installed_rank" DESC
FETCH FIRST 1 ROW ONLY;

GRANT SELECT ON SCHEMA_VERSION TO ITSM_APP_ROLE;
