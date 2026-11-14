/**
 * Ticket life cycle. Hexagonal module (ADR-006): this package is the public API of the module, the
 * sub-packages {@code domain}, {@code application} and {@code adapter} are internal.
 */
@org.springframework.modulith.ApplicationModule(allowedDependencies = {"referential", "shared"})
package fr.nordal.itsm.ticket;
