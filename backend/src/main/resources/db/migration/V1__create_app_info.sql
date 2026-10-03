-- Technical key/value table: proves the walking skeleton end to end
-- (created by ITSM_OWNER through Flyway, read by ITSM_APP through ITSM_APP_ROLE).

CREATE TABLE APP_INFO (
    INFO_KEY   VARCHAR2(64 CHAR)  NOT NULL,
    INFO_VALUE VARCHAR2(255 CHAR) NOT NULL,
    CONSTRAINT PK_APP_INFO PRIMARY KEY (INFO_KEY)
);

INSERT INTO APP_INFO (INFO_KEY, INFO_VALUE) VALUES ('application.name', 'ITSM');

-- Read-only for the application: this table is only changed by migrations.
GRANT SELECT ON APP_INFO TO ITSM_APP_ROLE;
