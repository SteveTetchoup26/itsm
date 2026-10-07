package fr.nordal.itsm.system;

import java.util.Optional;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/** Reads technical information from the database; any failure surfaces as a DataAccessException. */
@Repository
class SystemInfoRepository {

    private final JdbcClient jdbcClient;

    SystemInfoRepository(JdbcClient jdbcClient) {
        this.jdbcClient = jdbcClient;
    }

    String applicationName() {
        return jdbcClient
                .sql("SELECT INFO_VALUE FROM APP_INFO WHERE INFO_KEY = :key")
                .param("key", "application.name")
                .query(String.class)
                .single();
    }

    Optional<String> schemaVersion() {
        return jdbcClient
                .sql("SELECT VERSION FROM SCHEMA_VERSION")
                .query(String.class)
                .optional();
    }
}
