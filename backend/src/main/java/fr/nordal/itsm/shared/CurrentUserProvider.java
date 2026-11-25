package fr.nordal.itsm.shared;

/**
 * Port: gives the use cases the user behind the current request. Implemented by the security
 * module, so that no business module depends on Spring Security (ADR-006, dependency inversion).
 */
public interface CurrentUserProvider {

    /** @throws IllegalStateException when called outside an authenticated request */
    CurrentUser currentUser();
}
