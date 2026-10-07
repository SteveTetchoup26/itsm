package fr.nordal.itsm.system;

import fr.nordal.itsm.system.SystemInfo.DatabaseStatus;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.info.BuildProperties;
import org.springframework.dao.DataAccessException;
import org.springframework.stereotype.Service;

@Service
class SystemInfoService {

    private static final Logger log = LoggerFactory.getLogger(SystemInfoService.class);

    private final SystemInfoRepository repository;
    private final String version;

    // BuildProperties only exists when Maven ran the build-info goal (not after an IDE-only build).
    SystemInfoService(SystemInfoRepository repository, Optional<BuildProperties> buildProperties) {
        this.repository = repository;
        this.version = buildProperties.map(BuildProperties::getVersion).orElse("unknown");
    }

    SystemInfo info() {
        try {
            String application = repository.applicationName();
            String schemaVersion = repository.schemaVersion().orElse(null);
            return new SystemInfo(application, version, schemaVersion, DatabaseStatus.UP);
        } catch (DataAccessException e) {
            log.warn("Database unavailable for system info: {}", e.getMessage());
            return new SystemInfo(null, version, null, DatabaseStatus.DOWN);
        }
    }
}
