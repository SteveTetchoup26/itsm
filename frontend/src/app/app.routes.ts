import { Routes } from '@angular/router';
import { SystemStatus } from './system/system-status';

export const routes: Routes = [
  { path: '', component: SystemStatus, title: 'ITSM – État du système' },
  { path: '**', redirectTo: '' },
];
