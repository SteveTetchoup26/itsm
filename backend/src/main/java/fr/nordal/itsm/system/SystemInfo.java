package fr.nordal.itsm.system;

/** Technical information used by smoke tests after each deployment. */
public record SystemInfo(String application, String version, String schemaVersion, DatabaseStatus database) {

    public enum DatabaseStatus {
        UP,
        DOWN
    }
}
