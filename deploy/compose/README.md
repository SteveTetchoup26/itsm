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
