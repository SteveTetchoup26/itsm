# Pipeline d'intégration continue

Fichier : [`.github/workflows/ci.yml`](../.github/workflows/ci.yml). Il s'exécute sur chaque
Pull Request et sur chaque push dans `main`.

## Jobs

| Job | Quand | Ce qu'il vérifie |
|---|---|---|
| `changes` | toujours | dossiers modifiés (`backend/`, `frontend/`) |
| `backend` | `backend/`, `deploy/compose/oracle/` ou le workflow modifiés | `./mvnw verify` (Spotless, compilation, tests unitaires, tests d'intégration Testcontainers sur Oracle, JaCoCo), puis analyse SonarQube Cloud |
| `frontend` | `frontend/` ou le workflow modifiés | `npm ci --ignore-scripts`, Prettier, ESLint, Vitest avec couverture, build, puis analyse SonarQube Cloud |
| `secrets` | toujours | Gitleaks sur les commits de la PR (ou du push) |
| `codeql` | toujours | CodeQL pour Java, TypeScript et les workflows GitHub Actions ; alertes dans l'onglet Security |
| `images` | backend ou frontend modifiés, tests au vert | une image par composant : construction amd64 analysée par Trivy (bloquant sur les failles critiques corrigeables), construction amd64 et arm64, publiée sur GHCR depuis `main` seulement |
| `ci` | toujours (`if: always()`) | échoue si un job a échoué ou a été annulé ; un job sauté compte comme réussi |

Un seul workflow, qui démarre toujours : un filtre `paths` au niveau du workflow laisserait une
vérification obligatoire en attente pour toujours sur les PR qui ne touchent pas le dossier.

## Images Docker

| Image | Dockerfile | Base d'exécution | Utilisateur | Port |
|---|---|---|---|---|
| `ghcr.io/stevetetchoup26/itsm-backend` | `backend/Dockerfile` | `eclipse-temurin:25.0.4.1_1-jre-noble` | 10001 | 8080 |
| `ghcr.io/stevetetchoup26/itsm-frontend` | `frontend/Dockerfile` | `nginxinc/nginx-unprivileged:1.30.6-alpine` | 101 | 8080 |

- **Étiquette** : `sha-<commit court>` (ADR-002) ; une étiquette de version (`v0.0.1`) s'ajoutera aux livraisons.
- **Deux architectures** sous un même nom : `linux/amd64` (poste, CI) et `linux/arm64` (VM Ampere,
  ADR-004). L'étape de compilation tourne sur l'architecture de la machine (`$BUILDPLATFORM`) ;
  seule l'étape finale est émulée (QEMU) pour arm64.
- **Trivy** (`aquasec/trivy`, épinglé par empreinte) : rapport des failles critiques et hautes
  corrigeables, puis contrôle bloquant sur les critiques corrigeables. Même commande qu'en local :

  ```bash
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:0.76.1 \
    image --scanners vuln --severity CRITICAL,HIGH --ignore-unfixed itsm-backend:local
  ```

- **Publication** : uniquement sur un push dans `main`, avec le jeton du pipeline
  (`packages: write`). Les PR construisent les deux architectures sans rien publier.
- **Cache** des couches Docker dans le cache de GitHub Actions (`type=gha`), un par composant.

## Protection de `main`

Ruleset `protect-main` : Pull Request obligatoire (fusion par squash), historique linéaire, pas de
push forcé ni de suppression, et **vérification `ci` obligatoire** :

- publiée par GitHub Actions uniquement (`integration_id` 15368), pour qu'aucun autre outil ne
  puisse publier un faux « ci » ;
- en mode strict : la branche doit être à jour avec `main` avant la fusion, pour que chaque état
  de `main` ait été testé (bouton « Update branch » ou `@dependabot rebase`).

Le blocage des alertes CodeQL de sévérité haute est ajouté une fois `main` analysé par CodeQL.

## SonarQube Cloud

Organisation `stevetetchoup26`, un projet par composant (monorepo), analyse lancée par le
pipeline (l'analyse automatique ne s'applique pas aux monorepos) :

| Projet | Configuration | Couverture |
|---|---|---|
| `SteveTetchoup26_itsm-backend` | propriétés `sonar.*` de `backend/pom.xml` | JaCoCo (`target/site/jacoco/jacoco.xml`) |
| `SteveTetchoup26_itsm-frontend` | `frontend/sonar-project.properties` | Vitest (`coverage/itsm-frontend/lcov.info`) |

Le jeton est le secret `SONAR_TOKEN`. GitHub ne le transmet pas aux PR de Dependabot ni des forks :
l'analyse est alors sautée, les autres vérifications s'appliquent.

## Sécurité du pipeline

- Permissions minimales (`contents: read`), élargies job par job (`security-events: write` pour
  CodeQL).
- Actions épinglées par empreinte SHA, version lisible en commentaire ; Dependabot les met à jour.
- Dépendances npm installées sans scripts d'installation (`--ignore-scripts`).

## Dependabot

[`.github/dependabot.yml`](../.github/dependabot.yml) : mises à jour hebdomadaires pour GitHub
Actions (en un seul groupe), Maven, npm, Docker Compose et les images de base des Dockerfiles.

- Spring Boot, Angular, TypeScript et le wrapper Maven : correctifs seulement (ADR-003) ; les
  versions mineures et majeures sont planifiées.
- Images de base : pas de version majeure de Java ni de Node (LTS de l'ADR-003) ; Nginx reste sur
  sa branche stable 1.30.
- L'image Oracle est aussi écrite dans `SystemInfoIT` (Testcontainers), que Dependabot ne lit
  pas : une PR Dependabot sur `deploy/compose` doit être complétée à la main (exemple : PR #49).

## En cas d'échec

1. Sur la PR, **Details** à côté du job en rouge : l'étape en échec est dépliée.
2. Reproduire en local avec la même commande (`./mvnw verify`, `npm run lint`, etc.).
3. Pour SonarQube Cloud : lien **Details** de la vérification `[itsm-…] SonarCloud Code Analysis`.
