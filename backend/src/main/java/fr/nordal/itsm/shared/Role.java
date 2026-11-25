package fr.nordal.itsm.shared;

/** Roles of the functional specification (§5.1). They add up: a technician is also a user. */
public enum Role {
    USER,
    TECHNICIAN,
    MANAGER,
    ADMIN
}
