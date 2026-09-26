#!/usr/bin/env bash
# Cree les issues de l'increment I0 (walking skeleton). Rejouable : ignore les titres existants.
# Usage : ./scripts/create-i0-issues.sh
set -euo pipefail

MILESTONE="I0 : walking skeleton"
existing="$(gh issue list --state all --limit 300 --json title -q '.[].title')"

create() {
  local title="$1" labels="$2" body
  body="$(cat)"
  if grep -qxF "$title" <<<"$existing"; then
    echo "  deja existante : $title"; return
  fi
  local url
  url="$(gh issue create --title "$title" --label "$labels" --milestone "$MILESTONE" --body "$body")"
  echo "  $url  $title"
}

echo "Creation des issues de I0"

create "I0-01 : Oracle en local avec Docker Compose" "type:tech,area:database,area:infra" <<'EOF'
## Objectif
Disposer d'une base Oracle AI Database Free 26ai sur le poste, identique a celle de la CI.

## Criteres de fin
1. `deploy/compose/docker-compose.yml` demarre `gvenzl/oracle-free:23.26.2-slim-faststart` avec une limite memoire explicite.
2. Un script d'initialisation cree les comptes `ITSM_OWNER` (proprietaire du schema) et `ITSM_APP` (application), conformement a l'ADR-005.
3. Les mots de passe viennent d'un fichier `.env` non versionne ; un `.env.example` est versionne.
4. Les donnees survivent a un redemarrage (volume nomme).
5. Connexion verifiee avec SQLcl pour les deux comptes.

## References
ADR-003, ADR-005, cahier technique §5.2.
EOF

create "I0-02 : squelette du backend Spring Boot" "type:tech,area:backend" <<'EOF'
## Objectif
Creer l'application backend minimale, connectee a Oracle.

## Criteres de fin
1. Projet Maven dans `backend/` (Java 25, Spring Boot 4.1), paquetage `fr.nordal.itsm`.
2. Flyway cree la table `APP_INFO` via `V1__create_app_info.sql`, execute avec `ITSM_OWNER` ; l'application se connecte avec `ITSM_APP`.
3. `GET /api/v1/system/info` renvoie la version de l'application, la version du schema et l'etat de la base.
4. Actuator expose `/actuator/health/liveness` et `/actuator/health/readiness`.
5. Logs au format JSON sur la sortie standard.
6. Configuration par variables d'environnement, aucun secret dans le code.
7. Spotless configure.

## References
ADR-003, ADR-005, cahier technique §7 et §18.1.
EOF

create "I0-03 : tests du backend" "type:tech,area:backend" <<'EOF'
## Objectif
Poser la base de la strategie de tests des le premier incrément.

## Criteres de fin
1. Un test unitaire du service qui construit la reponse de `/system/info`.
2. Un test d'integration avec Testcontainers sur Oracle Free 26ai : migrations Flyway appliquees et endpoint appele.
3. JaCoCo produit un rapport de couverture.
4. `./mvnw verify` passe en local.

## References
Cahier technique §10 et §16.
EOF

create "I0-04 : squelette du frontend Angular" "type:tech,area:frontend" <<'EOF'
## Objectif
Creer l'application Angular minimale qui affiche l'etat du backend.

## Criteres de fin
1. Projet Angular 22 dans `frontend/`, composants autonomes.
2. Une page affiche la version de l'application, la version du schema et l'etat de la base, avec un message clair si le backend ne repond pas.
3. En local, les appels `/api` passent par le proxy du serveur de developpement.
4. ESLint, Prettier et un test Vitest du composant.

## References
ADR-003, cahier technique §8.
EOF

create "I0-05 : pipeline CI" "type:tech,area:ci-cd,area:security" <<'EOF'
## Objectif
Chaque Pull Request est verifiee automatiquement.

## Criteres de fin
1. Workflow GitHub Actions declenche sur Pull Request et sur `main`.
2. Jobs declenches selon les dossiers modifies (`backend/`, `frontend/`, `docs/`), conformement a l'ADR-001.
3. Backend : formatage, build, tests unitaires et d'integration. Frontend : lint, build, tests.
4. Gitleaks et CodeQL executes ; analyse SonarQube Cloud depuis le pipeline (analyse automatique desactivee).
5. Blocs Maven, npm et Docker actives dans `dependabot.yml`.
6. Les verifications deviennent obligatoires dans la protection de `main`.

## References
ADR-001, ADR-002, cahier technique §15.
EOF

create "I0-06 : images Docker multi-architecture" "type:tech,area:ci-cd,area:infra,area:security" <<'EOF'
## Objectif
Produire des images executables sur le poste (amd64) et sur la VM (arm64).

## Criteres de fin
1. Dockerfile multi-etapes pour le backend (image d'execution `eclipse-temurin:25-jre`, utilisateur non root).
2. Dockerfile pour le frontend (fichiers statiques servis par un serveur web non root).
3. Construction `linux/amd64` et `linux/arm64` avec Buildx dans le pipeline.
4. Scan Trivy bloquant sur les vulnerabilites critiques corrigeables.
5. Publication sur GHCR avec l'etiquette `sha-<commit>`, uniquement depuis `main`.

## References
ADR-002, ADR-004, cahier technique §12.
EOF

create "I0-07 : VM Oracle Cloud" "type:tech,area:infra" <<'EOF'
## Objectif
Disposer de la machine qui hebergera l'application.

## Criteres de fin
1. VM Ampere A1 (Always Free) creee dans le compartiment `itsm`, Ubuntu, dans la limite de 2 OCPU et 12 Go.
2. Liste de securite : seuls 80 et 443 ouverts au public ; 22 ferme une fois Tailscale en place.
3. Docker et Docker Compose installes ; utilisateur `deploy` cree.
4. Mises a jour de securite automatiques activees.
5. Procedure de creation documentee dans `docs/`.

## References
ADR-004, ADR-012.
EOF

create "I0-08 : Autonomous Database" "type:tech,area:database,area:infra" <<'EOF'
## Objectif
Disposer de la base Oracle en ligne.

## Criteres de fin
1. Autonomous AI Database Always Free, version **26ai**, dans le compartiment `itsm`.
2. Comptes `ITSM_OWNER` et `ITSM_APP` crees avec les memes droits qu'en local.
3. Connexion depuis la VM verifiee (wallet ou connexion TLS).
4. Ecarts avec Oracle Free documentes (ADR-004).

## References
ADR-003, ADR-004, ADR-005.
EOF

create "I0-09 : reseau prive Tailscale" "type:tech,area:infra,area:security" <<'EOF'
## Objectif
Permettre au pipeline de joindre la VM sans exposer SSH sur Internet.

## Criteres de fin
1. Compte Tailscale cree ; la VM rejoint le reseau avec l'etiquette `tag:itsm-vm`.
2. Politique d'acces : `tag:ci` vers `tag:itsm-vm` sur le port 22 uniquement.
3. Authentification du pipeline par federation d'identite OIDC.
4. Un job de test se connecte en SSH a la VM via le reseau prive.
5. Port 22 ferme dans la liste de securite Oracle Cloud.

## References
ADR-012.
EOF

create "I0-10 : HTTPS avec Caddy et DuckDNS" "type:tech,area:infra,area:security" <<'EOF'
## Objectif
Rendre l'application accessible en HTTPS avec un certificat valide.

## Criteres de fin
1. Le sous-domaine DuckDNS pointe vers l'IP publique de la VM.
2. Caddy obtient automatiquement un certificat Let's Encrypt.
3. HTTP redirige vers HTTPS ; `/api` vers le backend, le reste vers le frontend.
4. Fichier Compose de production dans `deploy/compose/`, avec limites memoire.

## References
Cahier technique §5.4 et §12.
EOF

create "I0-11 : deploiement continu" "type:tech,area:ci-cd,area:infra" <<'EOF'
## Objectif
Chaque fusion dans `main` est deployee automatiquement.

## Criteres de fin
1. Job de deploiement sur `main` uniquement : connexion Tailscale, mise a jour de l'etiquette d'image, `docker compose pull` et `up -d`.
2. Tests de fumee apres deploiement (sondes de sante, appel de `/api/v1/system/info`).
3. Retour automatique a l'image precedente si les tests de fumee echouent.
4. Secrets transmis par les secrets GitHub, jamais versionnes.

## References
ADR-002, ADR-012, cahier technique §15.
EOF

create "I0-12 : cloture de I0" "type:docs" <<'EOF'
## Objectif
Terminer proprement l'incrément.

## Criteres de fin
1. README : section de demarrage rapide et lien vers l'application en ligne.
2. Entree dans `docs/journal/` : ce qui a ete fait, ce qui a coince, ce qui a ete appris.
3. Etiquette `v0.0.1` creee.
4. Demonstration : une modification fusionnee apparait en ligne sans intervention manuelle.
EOF

echo "Termine."
