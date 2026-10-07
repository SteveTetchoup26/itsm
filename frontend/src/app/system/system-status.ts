import { httpResource } from '@angular/common/http';
import { Component } from '@angular/core';
import { SystemInfo } from './system-info';

@Component({
  selector: 'app-system-status',
  templateUrl: './system-status.html',
  styleUrl: './system-status.scss',
})
export class SystemStatus {
  // Relative URL: same origin as the page (dev proxy locally, Caddy in production).
  protected readonly info = httpResource<SystemInfo>(() => '/api/v1/system/info');
}
