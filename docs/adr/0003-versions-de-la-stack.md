# ADR-003 : Versions de la pile technique

- **Statut** : Accepté
- **Date** : 2026-09-26
- **Incrément** : I0

## Contexte

Avant d'écrire la première ligne de code, il faut fixer les versions des outils. Un choix
de version engage le projet pour longtemps : durée de support, compatibilité entre les
composants, disponibilité pour l'architecture ARM de la VM (ADR-004).

Cet ADR fixe les versions des composants utilisés en I0 et I1. Les composants introduits
plus tard (Kafka, OpenTelemetry, k3s, Helm, Terraform) seront fixés dans l'ADR qui les
introduit.

Versions relevées le 26 septembre 2026 à la source (dépôts officiels et registres de
paquets).

## Principes

1. **Versions à support long (LTS) pour les socles** : Java, Node.js, Oracle. Le projet doit
   durer plusieurs mois sans migration forcée.
2. **Dernière version stable pour les frameworks** : Spring Boot, Angular, Keycloak. Leurs
   cycles sont courts, et partir d'une version ancienne obligerait à migrer rapidement.
3. **Jamais de version préliminaire** (*alpha*, *beta*, *RC*) : on n'est pas là pour
   déboguer les outils.
4. **Laisser Spring Boot gérer les versions de son écosystème** : Hibernate, Flyway,
   Testcontainers, JUnit et le pilote Oracle sont fournis par la nomenclature de Spring Boot,
   testée par l'équipe Spring. On ne les force pas à la main.
5. **Même version d'Oracle partout** : local, CI et en ligne.
6. **Images Docker multi-architecture** (`amd64` et `arm64`) uniquement.
7. On fixe ici la version **majeure et mineure**. Les versions correctives sont mises à jour
   au fil de l'eau par Dependabot, chaque mise à jour passant par le pipeline.

## Décision

| Composant | Version retenue | Raison |
|---|---|---|
| Java (Eclipse Temurin) | **25** (LTS), dernière 25.0.x | LTS la plus récente ; threads virtuels, *records*, *pattern matching* |
| Maven | **3.9.x** (via le *wrapper*) | Maven 4 est encore en version préliminaire |
| Spring Boot | **4.1.x** | Dernière version stable ; gère les versions de Hibernate, Flyway, Testcontainers, JUnit |
| Spring Modulith | **2.1.x** | Branche alignée sur Spring Boot 4.1 |
| Flyway | Version fournie par Spring Boot 4.1 | Principe 4 ; ajouter le module `flyway-database-oracle` (ADR-005) |
| Testcontainers | Version fournie par Spring Boot 4.1 (branche 2.x) | Principe 4 |
| Node.js | **24** (LTS) | Exigé par Angular 22 (24.15 minimum) ; Node 26 ne deviendra LTS qu'en octobre 2026 |
| Angular | **22.x** | Dernière version stable |
| angular-auth-oidc-client | **22.x** | Version alignée sur Angular 22 |
| Oracle, local et CI | **Oracle AI Database Free 26ai**, image `gvenzl/oracle-free:23.26.2-slim-faststart` | Même version que la base en ligne ; image multi-architecture, démarrage rapide pour les tests |
| Oracle, en ligne | **Autonomous AI Database 26ai** (Always Free) | À **sélectionner explicitement** à la création : l'offre gratuite propose aussi la 19c |
| Keycloak | **26.x**, image `quay.io/keycloak/keycloak:26.7` | Dernière version stable, image multi-architecture |
| Caddy | **2.11.x** | Dernière version stable |
| Image d'exécution Java | `eclipse-temurin:25-jre` | Officielle, multi-architecture, JRE seul pour réduire la taille |

**À noter sur Oracle** : la numérotation d'Oracle est trompeuse. L'image locale porte le numéro
`23.26.2`, mais il s'agit bien d'**Oracle AI Database 26ai**, comme la base en ligne. Oracle a
renommé la version 23ai en 26ai en octobre 2025, sans changer la numérotation interne.

## Conséquences

- **Ce qui devient plus simple** : un point de départ récent et cohérent, sans migration
  majeure prévue pendant le projet ; des tests d'intégration qui utilisent la même version
  d'Oracle que la production.
- **Ce qui devient plus difficile** : les versions les plus récentes ont moins de réponses
  en ligne en cas de problème (Spring Boot 4 et Angular 22 notamment). La documentation
  officielle devient la référence.
- **Ce qu'il faudra surveiller** :
  - le passage de Node.js 26 en LTS en octobre 2026 : migration à planifier ;
  - la sortie d'Angular 23 et de Spring Boot 4.2 : mise à jour à planifier, pas à subir ;
  - les Pull Requests de Dependabot, à traiter au moins une fois par semaine.
- **Ce qui pourrait nous faire revenir sur cette décision** : une incompatibilité avérée entre
  deux composants (par exemple une bibliothèque qui ne supporte pas encore Spring Boot 4.1 ou
  Java 25). On reviendrait alors à la version mineure précédente, en le documentant dans un
  nouvel ADR.
