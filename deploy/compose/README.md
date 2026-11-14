# Environnement local (Docker Compose)

Services nécessaires au développement sur le poste : Oracle AI Database Free 26ai et Keycloak
(fournisseur d'identité, [ADR-007](../../docs/adr/0007-identite-keycloak.md)).

## Premier démarrage

```bash
cd deploy/compose
cp .env.example .env    # puis remplacer chaque change-me par un mot de passe
docker compose up -d
docker compose ps       # attendre l'état "healthy"
```

Mots de passe : lettres et chiffres uniquement, en commençant par une lettre. Ils ne sont lus
qu'à la **création** de la base : les modifier ensuite dans `.env` n'a aucun effet (voir
« Repartir de zéro »).

Au premier démarrage, `oracle/initdb/01-create-itsm-accounts.sh` crée dans la PDB `FREEPDB1` :

| Compte ou rôle | Usage | Droits |
|---|---|---|
| `ITSM_OWNER` | Propriétaire du schéma, utilisé par Flyway | Création de tables, vues, séquences, PL/SQL ; quota sur `USERS` |
| `ITSM_APP_ROLE` | Accès aux données | Aucun au départ : chaque migration Flyway lui accorde les droits table par table |
| `ITSM_APP` | Compte de l'application | Connexion et `ITSM_APP_ROLE` uniquement ; ne peut créer aucun objet |

L'image ignore le code de retour des scripts d'initialisation : vérifier les journaux après
une initialisation.

```bash
docker compose logs oracle | grep -E "ITSM accounts|ORA-"
```

## Connexion

| Paramètre | Valeur |
|---|---|
| Hôte | `localhost` (port publié sur `127.0.0.1` uniquement) |
| Port | `1521` (`ORACLE_PORT` dans `.env`) |
| Nom de service | `FREEPDB1` (et non le SID `FREE`, qui désigne le conteneur racine) |

```bash
sql ITSM_OWNER@//localhost:1521/FREEPDB1
sql ITSM_APP@//localhost:1521/FREEPDB1
```

## Keycloak

Keycloak démarre en mode développement et importe le realm `nordal` depuis
`keycloak/realm/nordal-realm.json`. Il n'a **pas de volume** : le realm est réimporté à chaque
création du conteneur, le fichier versionné est la seule source de vérité.

| Élément | Valeur |
|---|---|
| Console d'administration | <http://localhost:8081> (compte `admin`, `KEYCLOAK_ADMIN_PASSWORD` dans `.env`) |
| Émetteur des jetons (*issuer*) | `http://localhost:8081/realms/nordal` |
| Configuration OIDC | <http://localhost:8081/realms/nordal/.well-known/openid-configuration> |
| Client du frontend | `itsm-frontend` : public, Authorization Code avec PKCE (`S256`), redirection vers `http://localhost:4200/*` |
| Jeton d'accès | 5 minutes, audience `itsm-backend`, rôles dans `realm_access.roles` |

Utilisateurs de test (les personas du cahier fonctionnel, §5.4). Ils partagent le mot de passe
`ITSM_TEST_USER_PASSWORD` de `.env` : Keycloak remplace `${ITSM_TEST_USER_PASSWORD}` dans le
fichier du realm au moment de l'import, aucun mot de passe n'est versionné.

| Identifiant | Persona | Rôles |
|---|---|---|
| `sophie` | Sophie, comptable | `USER` |
| `karim` | Karim, technicien N1 | `USER`, `TECHNICIAN` |
| `julie` | Julie, manager du support | `USER`, `MANAGER` |
| `marc` | Marc, administrateur fonctionnel | `USER`, `ADMIN` |

Essayer une connexion sans le frontend : la console de compte de Keycloak,
<http://localhost:8081/realms/nordal/account>.

### Modifier le realm

1. Faire la modification dans la console d'administration (realm `nordal`) et la tester.
2. La reporter **à la main** dans `keycloak/realm/nordal-realm.json`. Pour retrouver le nom des
   champs : *Realm settings*, *Action*, *Partial export*. Ne pas remplacer le fichier par
   l'export complet : il contient des identifiants générés et des centaines de valeurs par
   défaut, qui rendraient les revues illisibles.
3. Recréer le conteneur pour vérifier que le fichier seul suffit :

```bash
docker compose up -d --force-recreate keycloak
docker compose logs keycloak | grep -E "Realm 'nordal' imported|ERROR"
```

Une modification faite seulement dans la console est perdue à la recréation du conteneur. Il
en va de même pour un changement de `ITSM_TEST_USER_PASSWORD` : il n'est pris en compte qu'à
la recréation.

## Commandes courantes

| Commande | Effet |
|---|---|
| `docker compose up -d` | Démarre la base, ou la recrée si la configuration a changé |
| `docker compose down` | Arrête et supprime le conteneur ; **les données sont conservées** |
| `docker compose logs -f oracle` | Suit les journaux |
| `docker stats --no-stream` | Mémoire consommée (limite : 2,5 Go) |

## Repartir de zéro

```bash
docker compose down -v   # supprime aussi le volume : toutes les données sont perdues
docker compose up -d     # nouvelle base, scripts d'initialisation rejoués
```

## Production : Caddy, frontend et backend

[`compose.prod.yml`](compose.prod.yml) décrit la pile de la VM ; la base est l'Autonomous
Database ([deploy/adb](../adb/README.md)), pas un conteneur.

```
Internet ──HTTPS──> caddy (80, 443) ──┬── /api/*  ──> backend:8080  (image itsm-backend)
                                      └── le reste ──> frontend:8080 (image itsm-frontend)
```

- **Caddy** ([`Caddyfile`](Caddyfile)) est le seul conteneur exposé : il obtient et renouvelle
  le certificat Let's Encrypt du domaine `ITSM_DOMAIN`, redirige HTTP vers HTTPS, ajoute les
  en-têtes de sécurité et ne transmet au backend que `/api/*` (Actuator n'est pas joignable
  depuis Internet). Les certificats sont conservés dans le volume `caddy-data` : le perdre
  oblige à les redemander, et Let's Encrypt limite le nombre de demandes.
- **Images** : celles publiées par le pipeline sur GHCR. Sur `main`, les deux images sont
  reconstruites dès que l'une change : une fusion = une version `sha-<commit>` pour toute
  l'application (`ITSM_TAG`), déployée et restaurée d'un bloc.
- **Contrôles de santé** : le backend n'est `healthy` que lorsque
  `/actuator/health/readiness` est `UP` (base comprise). L'image n'a ni `curl` ni `wget` : la
  requête HTTP est faite par Bash (`/dev/tcp`). Le frontend est testé avec le `wget` de BusyBox.
  Caddy ne démarre qu'une fois les deux `healthy` (plus de 502 au démarrage).
- **Mémoire** (budget du cahier technique) : Caddy 64 Mo, frontend 64 Mo, backend 1 Go (tas à
  70 %). Mesuré : backend environ 290 Mo au repos, Caddy 16 Mo, frontend 27 Mo.
- **Configuration** : `.env.prod` (jamais versionné), à partir de
  [`.env.prod.example`](.env.prod.example) ; mots de passe de la base de production.

Déploiement : [`deploy.sh`](deploy.sh), lancé sur la VM (dans `/opt/itsm`) par le job `deploy`
du pipeline (voir [le pipeline](../../docs/pipeline-ci.md)) :

```bash
./deploy.sh sha-1a2b3c4   # télécharge, démarre, attend "healthy" ; sinon revient seul à la version précédente
./deploy.sh --rollback    # revient à la version précédente (tests de fumée en échec)
```

- `.env.tag` contient la version en service, `.env.tag.previous` la précédente.
- Images téléchargées **avant** tout changement : une image introuvable ne touche à rien.
- Si même la version précédente ne démarre pas (le plus souvent : réglage de base erroné), le
  backend est **arrêté** au lieu de redémarrer en boucle (chaque redémarrage serait un échec de
  connexion, et le compte de la base finit verrouillé : voir [deploy/adb](../adb/README.md)).
- Le retour arrière restaure les images, pas le schéma : une migration Flyway doit rester
  compatible avec la version précédente de l'application.
- Coupure d'une dizaine de secondes pendant la recréation du backend : un déploiement sans
  coupure demande deux instances (Kubernetes, I6).

Test sur le poste, avec `ITSM_DOMAIN=localhost` (`deploy.sh` vérifié le 2026-11-07 : premier
déploiement, mise à jour, retour arrière, étiquette invalide refusée, image introuvable sans
effet) : Caddy utilise alors sa propre autorité de
certification locale (`curl -k`). Vérifié le 2026-11-07 contre l'Autonomous Database : HTTP
redirigé (308), `/api/v1/system/info` répond (`database UP`), `/` sert Angular,
`/actuator/health` n'atteint pas le backend, en-têtes HSTS, `nosniff` et `Referrer-Policy`
présents, en-tête `Server` supprimé.

À faire quand la VM existera : faire pointer le sous-domaine DuckDNS vers son IP publique,
puis démarrer la pile avec le vrai domaine (critères 1 et 2 de l'issue #21).
