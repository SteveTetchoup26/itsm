# Backend (Spring Boot)

Application backend de la plateforme ITSM : Java 25, Spring Boot 4.1, Maven 3.9 (wrapper).

## Prérequis

- Java 25 (Temurin).
- La base Oracle locale démarrée : voir [deploy/compose](../deploy/compose/README.md).

## Lancer l'application

En ligne de commande, depuis `backend/` :

```bash
set -a; source ../deploy/compose/.env; set +a   # exporte les mots de passe
./mvnw spring-boot:run
```

Dans IntelliJ IDEA :

1. Ouvrir la racine du dépôt ; SDK du projet : Java 25.
2. `Settings > Build Tools > Maven` : *Maven home path* = **Use Maven wrapper** ;
   *Runner* : cocher **Delegate IDE build/run actions to Maven** (sans cela, la version
   affichée vaut `unknown` ou `@project.version@`).
3. Configuration de lancement Spring Boot `fr.nordal.itsm.ItsmApplication`, avec les variables
   d'environnement de `deploy/compose/.env`. Ne pas cocher « Store as project file » : le
   dossier `.run/` n'est pas ignoré par Git.

## Configuration

Toute la configuration passe par des variables d'environnement ; aucun secret dans le code.

| Variable | Défaut | Rôle |
|---|---|---|
| `ITSM_DB_URL` | `jdbc:oracle:thin:@//localhost:1521/FREEPDB1` | URL JDBC de la base |
| `ITSM_APP_USER` | `ITSM_APP` | Compte de l'application (lecture et écriture des données) |
| `ITSM_APP_PASSWORD` | aucun, obligatoire | Mot de passe de `ITSM_APP` |
| `ITSM_OWNER_USER` | `ITSM_OWNER` | Propriétaire du schéma, utilisé par Flyway au démarrage |
| `ITSM_OWNER_PASSWORD` | aucun, obligatoire | Mot de passe de `ITSM_OWNER` |

Une erreur `ORA-01017` au démarrage signifie le plus souvent que les variables ne sont pas
chargées : Spring envoie alors le texte `${ITSM_OWNER_PASSWORD}` comme mot de passe.

## Points d'accès

| URL | Rôle |
|---|---|
| `GET /api/v1/system/info` | Nom et version de l'application, version du schéma, état de la base |
| `GET /actuator/health/liveness` | L'application est vivante (ne vérifie pas la base) |
| `GET /actuator/health/readiness` | L'application est prête : inclut la base (503 si elle est indisponible) |

Aucun autre point Actuator n'est exposé.

## Migrations Flyway

Fichiers dans `src/main/resources/db/migration/`, appliqués au démarrage avec `ITSM_OWNER`
(ADR-005) :

- `V<n>__<description>.sql` : jamais modifiée après fusion dans `main` ; toute correction
  passe par une nouvelle migration.
- `R__<description>.sql` : vues et PL/SQL, réappliquées quand leur contenu change.
- Chaque migration qui crée une table accorde à `ITSM_APP_ROLE` **uniquement** les droits
  nécessaires (par exemple, jamais `DELETE` sur les tickets).

L'application lit les tables sans préfixe : chaque connexion du pool exécute
`ALTER SESSION SET CURRENT_SCHEMA = ITSM_OWNER`.

## Logs

Format JSON (Elastic Common Schema) sur la sortie standard, une ligne par événement. Pour les
lire en local :

```bash
./mvnw spring-boot:run | jq -R -r 'fromjson? | "\(.log.level)\t\(.message)"'
```

## Formatage

Spotless avec palantir-java-format ; `./mvnw verify` échoue si le code n'est pas formaté.

```bash
./mvnw spotless:apply   # formate (avant chaque commit)
./mvnw verify           # compile, teste et vérifie le formatage (ce que fait la CI)
```
