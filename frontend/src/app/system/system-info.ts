/** Response of GET /api/v1/system/info (backend record fr.nordal.itsm.system.SystemInfo). */
export interface SystemInfo {
  application: string | null;
  version: string;
  schemaVersion: string | null;
  database: DatabaseStatus;
}

export type DatabaseStatus = 'UP' | 'DOWN';
