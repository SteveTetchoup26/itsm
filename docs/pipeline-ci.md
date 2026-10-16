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
| `ci` | toujours (`if: always()`) | échoue si un job a échoué ou a été annulé ; un job sauté compte comme réussi |

Un seul workflow, qui démarre toujours : un filtre `paths` au niveau du workflow laisserait une
vérification obligatoire en attente pour toujours sur les PR qui ne touchent pas le dossier.

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
Actions, Maven, npm et Docker Compose. Spring Boot et Angular : correctifs seulement (ADR-003), les
versions mineures et majeures sont planifiées. Le bloc `docker` (Dockerfiles) arrive avec I0-06.

## En cas d'échec

1. Sur la PR, **Details** à côté du job en rouge : l'étape en échec est dépliée.
2. Reproduire en local avec la même commande (`./mvnw verify`, `npm run lint`, etc.).
3. Pour SonarQube Cloud : lien **Details** de la vérification `[itsm-…] SonarCloud Code Analysis`.
