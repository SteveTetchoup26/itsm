package fr.nordal.itsm;

import org.junit.jupiter.api.Test;
import org.springframework.modulith.core.ApplicationModules;

/** Module rules of ADR-006: no module uses the internals of another one, no cycle between modules. */
class ModularityTest {

    @Test
    void modulesRespectTheirBoundaries() {
        ApplicationModules.of(ItsmApplication.class).verify();
    }
}
