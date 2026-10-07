package fr.nordal.itsm.system;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import fr.nordal.itsm.system.SystemInfo.DatabaseStatus;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.info.BuildProperties;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.SpringBootTest.WebEnvironment;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.web.client.RestClient;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.oracle.OracleContainer;
import org.testcontainers.utility.MountableFile;

/**
 * Whole application against a disposable Oracle 26ai, with the same two accounts as every
 * other environment: the init script of deploy/compose creates ITSM_OWNER and ITSM_APP.
 */
@Testcontainers
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
class SystemInfoIT {

    // Throwaway credentials, only valid inside the test container.
    private static final String OWNER_PASSWORD = "TestOwner2026";
    private static final String APP_PASSWORD = "TestApp2026";

    @Container
    static final OracleContainer oracle = new OracleContainer("gvenzl/oracle-free:23.26.2-slim-faststart")
            .withEnv("ITSM_OWNER_PASSWORD", OWNER_PASSWORD)
            .withEnv("ITSM_APP_PASSWORD", APP_PASSWORD)
            .withCopyFileToContainer(
                    MountableFile.forHostPath("../deploy/compose/oracle/initdb/01-create-itsm-accounts.sh", 0755),
                    "/container-entrypoint-initdb.d/01-create-itsm-accounts.sh");

    // Fills the variables read by application.yaml: the rest of the configuration is the real one.
    @DynamicPropertySource
    static void databaseProperties(DynamicPropertyRegistry registry) {
        registry.add("ITSM_DB_URL", oracle::getJdbcUrl);
        registry.add("ITSM_OWNER_PASSWORD", () -> OWNER_PASSWORD);
        registry.add("ITSM_APP_PASSWORD", () -> APP_PASSWORD);
    }

    @LocalServerPort
    int port;

    @Autowired
    Flyway flyway;

    @Autowired
    BuildProperties buildProperties;

    @Autowired
    JdbcClient applicationJdbcClient;

    @Test
    void system_info_reports_the_migrated_schema_over_http() {
        var info = RestClient.create("http://localhost:" + port)
                .get()
                .uri("/api/v1/system/info")
                .retrieve()
                .body(SystemInfo.class);

        String latestMigration = flyway.info().current().getVersion().getVersion();
        assertThat(info)
                .isEqualTo(new SystemInfo("ITSM", buildProperties.getVersion(), latestMigration, DatabaseStatus.UP));
    }

    @Test
    void application_account_cannot_modify_reference_data() {
        assertThatThrownBy(() -> applicationJdbcClient
                        .sql("UPDATE APP_INFO SET INFO_VALUE = 'changed'")
                        .update())
                .isInstanceOf(DataAccessException.class)
                .hasMessageContaining("ORA-41900");
    }
}
