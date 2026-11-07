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
| `images` | backend ou frontend modifiés, tests au vert (sur `main` : les deux images dès que l'une change) | une image par composant : construction amd64 analysée par Trivy (bloquant sur les failles critiques corrigeables), construction amd64 et arm64, publiée sur GHCR depuis `main` seulement |
| `deploy` | push sur `main`, images publiées, variable `ITSM_DEPLOY_ENABLED` à `true` | déploiement sur la VM par Tailscale et SSH, tests de fumée depuis Internet, retour arrière en cas d'échec (voir plus bas) |
| `ci` | toujours (`if: always()`) | échoue si un job a échoué ou a été annulé ; un job sauté compte comme réussi |

Un seul workflow, qui démarre toujours : un filtre `paths` au niveau du workflow laisserait une
vérification obligatoire en attente pour toujours sur les PR qui ne touchent pas le dossier.

## Images Docker

| Image | Dockerfile | Base d'exécution | Utilisateur | Port |
|---|---|---|---|---|
| `ghcr.io/stevetetchoup26/itsm-backend` | `backend/Dockerfile` | `eclipse-temurin:25.0.5_8-jre-noble` | 10001 | 8080 |
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

## Déploiement continu

Job `deploy`, environnement GitHub **`production`** (réservé à `main`), une exécution à la fois :

1. rejoint le réseau privé Tailscale en nœud éphémère `tag:ci`, par fédération d'identité OIDC
   (aucun secret Tailscale stocké ; voir [deploy/tailscale](../deploy/tailscale/README.md)) ;
2. SSH vers `deploy@<VM>` avec la clé du pipeline ; l'empreinte de la VM est épinglée
   (`known_hosts`, `StrictHostKeyChecking yes`) ;
3. copie `compose.prod.yml`, `Caddyfile` et `deploy.sh` dans `/opt/itsm`, et écrit `.env.prod`
   à partir des secrets, par l'entrée standard de SSH (jamais sur une ligne de commande) ;
4. `deploy.sh sha-<commit>` : téléchargement, démarrage, attente de l'état `healthy`, retour
   seul à la version précédente sinon ([deploy/compose](../deploy/compose/README.md)) ;
5. tests de fumée depuis Internet : `https://<domaine>/api/v1/system/info` avec
   `"database":"UP"`, et la page d'accueil ;
6. en cas d'échec des tests de fumée : `deploy.sh --rollback`, et le job **échoue quand même**.

Réglages de l'environnement `production` :

| Nom | Type | Contenu |
|---|---|---|
| `ITSM_DEPLOY_ENABLED` | variable | `true` pour activer le job (absent tant que la VM n'existe pas) |
| `VM_TAILNET_HOST` | variable | nom de la VM dans le réseau privé |
| `VM_SSH_KNOWN_HOSTS` | variable | clé publique d'hôte de la VM (`ssh-keyscan`) |
| `ITSM_DOMAIN` | variable | domaine DuckDNS |
| `TS_OAUTH_CLIENT_ID`, `TS_AUDIENCE` | variables | identité fédérée Tailscale (pas des secrets) |
| `DEPLOY_SSH_KEY` | secret | clé privée SSH du pipeline (dédiée, utilisateur `deploy`) |
| `ITSM_DB_URL` | secret | URL JDBC de `itsm_tp` (contient l'identifiant de la base) |
| `ITSM_OWNER_PASSWORD`, `ITSM_APP_PASSWORD` | secrets | comptes de la base de production |

## Livraison d'une version (fin d'incrément)

Numérotation SemVer 0.x (ADR-002) : `v0.0.1` en fin de I0, puis `v0.<n>.0` en fin de chaque
incrément. Pendant l'incrément, `backend/pom.xml` et `frontend/package.json` portent la version
visée avec le suffixe `-SNAPSHOT` (par exemple `0.0.1-SNAPSHOT`).

1. PR `chore(release): 0.0.1` : retirer `-SNAPSHOT` des deux fichiers (`package-lock.json`
   compris) ; fusion, déploiement automatique, tests de fumée verts.
2. Étiquette sur ce commit de fusion, poussée par le développeur :

   ```bash
   git switch main && git pull
   git tag -a v0.0.1 -m "v0.0.1: walking skeleton" && git push origin v0.0.1
   ```

3. Le workflow `release.yml` ajoute l'étiquette `v0.0.1` aux images déjà publiées pour ce
   commit (`docker buildx imagetools create`, sans reconstruction : on livre exactement ce qui
   a été testé et déployé) et crée la *release* GitHub avec les notes générées.
4. PR suivante : passer à la version visée par l'incrément suivant (`0.1.0-SNAPSHOT`).

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
