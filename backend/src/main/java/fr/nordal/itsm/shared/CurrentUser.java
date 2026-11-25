package fr.nordal.itsm.shared;

import java.util.Collections;
import java.util.EnumSet;
import java.util.Objects;
import java.util.Set;

/**
 * The person behind the current request, as the identity provider describes them. The application
 * stores only the identifier, the name and the e-mail address (technical specification §4.3).
 *
 * @param id stable identifier given by the identity provider (never the username, which can change)
 */
public record CurrentUser(String id, String username, String name, String email, Set<Role> roles) {

    public CurrentUser {
        Objects.requireNonNull(id, "id");
        // Immutable, in the declaration order of Role: the API always answers the same way.
        roles = roles.isEmpty() ? Set.of() : Collections.unmodifiableSet(EnumSet.copyOf(roles));
    }

    public boolean hasRole(Role role) {
        return roles.contains(role);
    }
}
