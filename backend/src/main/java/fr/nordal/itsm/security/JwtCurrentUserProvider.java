package fr.nordal.itsm.security;

import fr.nordal.itsm.shared.CurrentUser;
import fr.nordal.itsm.shared.CurrentUserProvider;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.stereotype.Component;

/** Adapter of the CurrentUserProvider port: the user is read from the verified access token. */
@Component
class JwtCurrentUserProvider implements CurrentUserProvider {

    @Override
    public CurrentUser currentUser() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (!(authentication instanceof JwtAuthenticationToken token)) {
            throw new IllegalStateException("No authenticated user in this request");
        }
        Jwt jwt = token.getToken();
        return new CurrentUser(
                jwt.getSubject(),
                jwt.getClaimAsString("preferred_username"),
                jwt.getClaimAsString("name"),
                jwt.getClaimAsString("email"),
                KeycloakRealmRoleConverter.roles(jwt));
    }
}
