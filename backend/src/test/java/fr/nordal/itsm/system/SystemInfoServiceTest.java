package fr.nordal.itsm.system;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import fr.nordal.itsm.system.SystemInfo.DatabaseStatus;
import java.util.Optional;
import java.util.Properties;
import org.junit.jupiter.api.Test;
import org.springframework.boot.info.BuildProperties;
import org.springframework.jdbc.CannotGetJdbcConnectionException;

class SystemInfoServiceTest {

    private final SystemInfoRepository repository = mock(SystemInfoRepository.class);

    @Test
    void reports_application_versions_and_database_up() {
        when(repository.applicationName()).thenReturn("ITSM");
        when(repository.schemaVersion()).thenReturn(Optional.of("3"));
        var service = new SystemInfoService(repository, Optional.of(buildPropertiesWithVersion("1.2.0")));

        var info = service.info();

        assertThat(info).isEqualTo(new SystemInfo("ITSM", "1.2.0", "3", DatabaseStatus.UP));
    }

    @Test
    void reports_database_down_when_it_is_unreachable() {
        when(repository.applicationName()).thenThrow(new CannotGetJdbcConnectionException("Connection refused"));
        var service = new SystemInfoService(repository, Optional.of(buildPropertiesWithVersion("1.2.0")));

        var info = service.info();

        assertThat(info).isEqualTo(new SystemInfo(null, "1.2.0", null, DatabaseStatus.DOWN));
    }

    @Test
    void reports_unknown_version_without_build_info() {
        when(repository.applicationName()).thenReturn("ITSM");
        when(repository.schemaVersion()).thenReturn(Optional.of("3"));
        var service = new SystemInfoService(repository, Optional.empty());

        var info = service.info();

        assertThat(info.version()).isEqualTo("unknown");
    }

    private static BuildProperties buildPropertiesWithVersion(String version) {
        var entries = new Properties();
        entries.setProperty("version", version);
        return new BuildProperties(entries);
    }
}
