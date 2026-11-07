# Environnement local (Docker Compose)

Services nécessaires au développement sur le poste. Pour l'instant : Oracle AI Database Free 26ai.

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
- **Images** : celles publiées par le pipeline sur GHCR. Le pipeline ne reconstruit une image
  que si son dossier a changé : le backend et le frontend ont donc chacun leur étiquette
  (`ITSM_BACKEND_TAG`, `ITSM_FRONTEND_TAG`).
- **Mémoire** (budget du cahier technique) : Caddy 64 Mo, frontend 64 Mo, backend 1 Go (tas à
  70 %). Mesuré : backend environ 290 Mo au repos, Caddy 16 Mo, frontend 27 Mo.
- **Configuration** : `.env.prod` (jamais versionné), à partir de
  [`.env.prod.example`](.env.prod.example) ; mots de passe de la base de production.

Lancement (sur la VM, en I0-11 par le pipeline) :

```bash
docker compose -f compose.prod.yml --env-file .env.prod up -d
```

Test sur le poste, avec `ITSM_DOMAIN=localhost` : Caddy utilise alors sa propre autorité de
certification locale (`curl -k`). Vérifié le 2026-11-07 contre l'Autonomous Database : HTTP
redirigé (308), `/api/v1/system/info` répond (`database UP`), `/` sert Angular,
`/actuator/health` n'atteint pas le backend, en-têtes HSTS, `nosniff` et `Referrer-Policy`
présents, en-tête `Server` supprimé.

À faire quand la VM existera : faire pointer le sous-domaine DuckDNS vers son IP publique,
puis démarrer la pile avec le vrai domaine (critères 1 et 2 de l'issue #21).
