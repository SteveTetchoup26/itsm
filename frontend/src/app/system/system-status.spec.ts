import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { SystemInfo } from './system-info';
import { SystemStatus } from './system-status';

describe('SystemStatus', () => {
  let fixture: ComponentFixture<SystemStatus>;
  let httpTesting: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [SystemStatus],
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    httpTesting = TestBed.inject(HttpTestingController);
    fixture = TestBed.createComponent(SystemStatus);
  });

  afterEach(() => {
    // Fails the test if the component sent a request that no test answered.
    httpTesting.verify();
  });

  async function respondWith(body: SystemInfo) {
    TestBed.tick();
    httpTesting.expectOne('/api/v1/system/info').flush(body);
    await fixture.whenStable();
  }

  function text(): string {
    return (fixture.nativeElement as HTMLElement).textContent ?? '';
  }

  it('displays the versions and an available database', async () => {
    await respondWith({
      application: 'ITSM',
      version: '1.2.0',
      schemaVersion: '3',
      database: 'UP',
    });

    expect(text()).toContain('1.2.0');
    expect(text()).toContain('3');
    expect(text()).toContain('disponible');
    expect(text()).not.toContain('indisponible');
  });

  it('reports an unavailable database while the backend still answers', async () => {
    await respondWith({
      application: null,
      version: '1.2.0',
      schemaVersion: null,
      database: 'DOWN',
    });

    expect(text()).toContain('indisponible');
    expect(text()).not.toContain('Le serveur ne répond pas');
  });

  it('shows an error message when the backend does not answer', async () => {
    TestBed.tick();
    httpTesting
      .expectOne('/api/v1/system/info')
      .flush('Bad Gateway', { status: 502, statusText: 'Bad Gateway' });
    await fixture.whenStable();

    const alert = (fixture.nativeElement as HTMLElement).querySelector('[role="alert"]');
    expect(alert?.textContent).toContain('Le serveur ne répond pas');
  });
});
