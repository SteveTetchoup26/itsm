package fr.nordal.itsm.security;

import static org.assertj.core.api.Assertions.assertThat;

import fr.nordal.itsm.shared.Role;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;

class KeycloakRealmRoleConverterTest {

    private final KeycloakRealmRoleConverter converter = new KeycloakRealmRoleConverter();

    private static Jwt jwt(Map<String, Object> claims) {
        var builder = Jwt.withTokenValue("token")
                .header("alg", "RS256")
                .subject("user-id")
                .issuedAt(Instant.now())
                .expiresAt(Instant.now().plusSeconds(300));
        claims.forEach(builder::claim);
        return builder.build();
    }

    @Test
    void realm_roles_become_spring_authorities() {
        var token = jwt(Map.of("realm_access", Map.of("roles", List.of("USER", "TECHNICIAN"))));

        assertThat(converter.convert(token))
                .extracting(GrantedAuthority::getAuthority)
                .containsExactlyInAnyOrder("ROLE_USER", "ROLE_TECHNICIAN");
    }

    @Test
    void roles_unknown_to_the_application_are_ignored() {
        var token = jwt(Map.of(
                "realm_access", Map.of("roles", List.of("USER", "offline_access", "default-roles-nordal", "admin"))));

        assertThat(KeycloakRealmRoleConverter.roles(token)).containsExactly(Role.USER);
    }

    @Test
    void a_token_without_realm_roles_gives_no_authority() {
        assertThat(converter.convert(jwt(Map.of("scope", "openid")))).isEmpty();
        assertThat(converter.convert(jwt(Map.of("realm_access", Map.of())))).isEmpty();
    }
}
