package fr.nordal.itsm;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.core.importer.ImportOption;
import org.junit.jupiter.api.Test;

/**
 * Layer rules of ADR-006 for hexagonal modules: dependencies point inwards (adapter, application,
 * domain) and the domain is plain Java, as well as the shared module it relies on. A module is hexagonal as soon as it has a {@code domain}
 * package; lightweight modules have no layers and are not concerned.
 */
class HexagonalArchitectureTest {

    private static final String DOMAIN = "fr.nordal.itsm.*.domain..";
    private static final String APPLICATION = "fr.nordal.itsm.*.application..";
    private static final String ADAPTER = "fr.nordal.itsm.*.adapter..";
    private static final String ADAPTER_IN = "fr.nordal.itsm.*.adapter.in..";
    private static final String ADAPTER_OUT = "fr.nordal.itsm.*.adapter.out..";
    private static final String SHARED = "fr.nordal.itsm.shared..";

    private final JavaClasses classes = new ClassFileImporter()
            .withImportOption(ImportOption.Predefined.DO_NOT_INCLUDE_TESTS)
            .importPackages("fr.nordal.itsm");

    // allowEmptyShould: the layers are still empty; to remove with the first domain classes (I1-06),
    // so that a rule matching nothing fails instead of passing silently.

    @Test
    void domainIsPlainJava() {
        classes()
                .that()
                .resideInAPackage(DOMAIN)
                .should()
                .onlyDependOnClassesThat()
                .resideInAnyPackage("java..", DOMAIN, SHARED)
                .because("business rules must be testable without Spring, JPA or a database")
                .allowEmptyShould(true)
                .check(classes);
    }

    @Test
    void sharedIsPlainJava() {
        classes()
                .that()
                .resideInAPackage(SHARED)
                // package-info carries @ApplicationModule: a declaration, not code
                .and()
                .doNotHaveSimpleName("package-info")
                .should()
                .onlyDependOnClassesThat()
                .resideInAnyPackage("java..", SHARED)
                .because("the domain depends on shared: a framework in shared would leak into every domain")
                .allowEmptyShould(true)
                .check(classes);
    }

    @Test
    void applicationDoesNotDependOnAdapters() {
        noClasses()
                .that()
                .resideInAPackage(APPLICATION)
                .should()
                .dependOnClassesThat()
                .resideInAPackage(ADAPTER)
                .because("use cases reach the outside world through the ports of the domain")
                .allowEmptyShould(true)
                .check(classes);
    }

    @Test
    void outboundAdaptersDependOnTheDomainOnly() {
        noClasses()
                .that()
                .resideInAPackage(ADAPTER_OUT)
                .should()
                .dependOnClassesThat()
                .resideInAnyPackage(APPLICATION, ADAPTER_IN)
                .because("an outbound adapter implements a port of the domain and knows nothing else")
                .allowEmptyShould(true)
                .check(classes);
    }

    @Test
    void inboundAdaptersDoNotDependOnOutboundAdapters() {
        noClasses()
                .that()
                .resideInAPackage(ADAPTER_IN)
                .should()
                .dependOnClassesThat()
                .resideInAPackage(ADAPTER_OUT)
                .because("a controller calls a use case, never the persistence directly")
                .allowEmptyShould(true)
                .check(classes);
    }
}
