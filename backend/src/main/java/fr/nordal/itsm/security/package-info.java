/**
 * Authentication of requests: JWT resource server, current user. Lightweight technical module
 * (ADR-006, ADR-007). The other modules never depend on it: they use the types of {@code shared}.
 */
@org.springframework.modulith.ApplicationModule(allowedDependencies = {"shared"})
package fr.nordal.itsm.security;
