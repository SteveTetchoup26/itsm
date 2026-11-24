package fr.nordal.itsm.security;

import fr.nordal.itsm.shared.Role;
import java.util.Arrays;
import java.util.Collection;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.core.convert.converter.Converter;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;

/**
 * Reads the realm roles where Keycloak puts them ({@code realm_access.roles}), which Spring
 * Security does not read by default. Only the roles of the application are kept: Keycloak also
 * adds its own ({@code offline_access}, {@code default-roles-nordal}...).
 */
final class KeycloakRealmRoleConverter implements Converter<Jwt, Collection<GrantedAuthority>> {

    static Set<Role> roles(Jwt jwt) {
        Map<String, Object> realmAccess = jwt.getClaimAsMap("realm_access");
        if (realmAccess == null || !(realmAccess.get("roles") instanceof List<?> names)) {
            return EnumSet.noneOf(Role.class);
        }
        Set<String> known = Arrays.stream(Role.values()).map(Role::name).collect(Collectors.toSet());
        return names.stream()
                .map(String::valueOf)
                .filter(known::contains)
                .map(Role::valueOf)
                .collect(Collectors.toCollection(() -> EnumSet.noneOf(Role.class)));
    }

    @Override
    public Collection<GrantedAuthority> convert(Jwt jwt) {
        // ROLE_ prefix: what hasRole("USER") looks for.
        return roles(jwt).stream()
                .map(role -> (GrantedAuthority) new SimpleGrantedAuthority("ROLE_" + role.name()))
                .toList();
    }
}
