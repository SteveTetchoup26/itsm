package fr.nordal.itsm.system;

import fr.nordal.itsm.system.SystemInfo.DatabaseStatus;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.boot.info.BuildProperties;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/system")
class SystemInfoController {

    private static final Logger log = LoggerFactory.getLogger(SystemInfoController.class);

    private final JdbcClient jdbcClient;
    private final String version;

    SystemInfoController(JdbcClient jdbcClient, ObjectProvider<BuildProperties> buildProperties) {
        this.jdbcClient = jdbcClient;
        // BuildProperties only exists when Maven ran the build-info goal (not after an IDE-only build).
        BuildProperties build = buildProperties.getIfAvailable();
        this.version = build != null ? build.getVersion() : "unknown";
    }

    @GetMapping("/info")
    SystemInfo info() {
        try {
            String application = jdbcClient
                    .sql("SELECT INFO_VALUE FROM APP_INFO WHERE INFO_KEY = :key")
                    .param("key", "application.name")
                    .query(String.class)
                    .single();
            String schemaVersion = jdbcClient
                    .sql("SELECT VERSION FROM SCHEMA_VERSION")
                    .query(String.class)
                    .optional()
                    .orElse(null);
            return new SystemInfo(application, version, schemaVersion, DatabaseStatus.UP);
        } catch (DataAccessException e) {
            log.warn("Database unavailable for system info: {}", e.getMessage());
            return new SystemInfo(null, version, null, DatabaseStatus.DOWN);
        }
    }
}
