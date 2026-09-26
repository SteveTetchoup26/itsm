# ADR-005 : Migrations du schéma Oracle avec Flyway

- **Statut** : Accepté
- **Date** : 2026-09-26
- **Incrément** : I0

## Contexte

Le schéma de la base Oracle va évoluer à chaque incrément : tables, contraintes, index, vues,
packages PL/SQL. Ces évolutions doivent être appliquées de façon **identique et automatique**
sur trois environnements : le poste local, les bases éphémères de la CI (Testcontainers) et
Autonomous Database en ligne.

Exigences :

- chaque évolution est versionnée dans Git et relue en Pull Request comme du code ;
- une base, quelle que soit sa version de départ, peut être amenée à la dernière version sans
  intervention manuelle ;
- le projet utilise volontairement du **SQL Oracle natif** : vues, séquences, PL/SQL
  (cahier des charges technique, §19) ;
- l'application ne doit pas disposer des droits de modifier le schéma (§17 : deux comptes,
  `ITSM_OWNER` et `ITSM_APP`).

## Options étudiées

### Option 1 : génération automatique par Hibernate (`ddl-auto=update`)

- Avantages : aucun script à écrire.
- Inconvénients : aucun contrôle sur le SQL produit ; pas de suppression ni de renommage
  fiables ; aucun historique ; pas de vues ni de PL/SQL. Inacceptable hors prototype.

### Option 2 : Liquibase

- Avantages : très complet (retour arrière, conditions d'exécution, formats multiples).
- Inconvénients : les changements s'écrivent le plus souvent en XML ou en YAML, ce qui
  éloigne du SQL Oracle qu'on souhaite pratiquer ; plus de concepts à maîtriser.

### Option 3 : Flyway

- Avantages : les migrations sont de **simples fichiers SQL numérotés** ; intégration native
  avec Spring Boot et Testcontainers ; vérification par somme de contrôle qu'une migration
  déjà appliquée n'a pas été modifiée ; très répandu.
- Inconvénients : pas de retour arrière automatique dans l'édition gratuite ; il faut écrire
  soi-même les migrations correctives.

### Option 4 : scripts SQL appliqués à la main

- Avantages : aucune dépendance.
- Inconvénients : erreurs humaines, aucun suivi de ce qui est appliqué où ; incompatible avec
  le déploiement continu.

## Décision

**Option 3 : Flyway**, exécuté au démarrage de l'application.

Conventions :

1. Fichiers dans `backend/src/main/resources/db/migration/`.
2. Migrations versionnées : `V<numéro>__<description>.sql`, par exemple
   `V3__create_ticket.sql`. Une fois fusionnée dans `main`, **une migration n'est plus jamais
   modifiée** : toute correction passe par une nouvelle migration.
3. Migrations répétables pour les objets recréables (vues, packages PL/SQL) :
   `R__<description>.sql`, réappliquées automatiquement quand leur contenu change.
4. Flyway se connecte avec le compte propriétaire du schéma `ITSM_OWNER` ; l'application
   utilise `ITSM_APP`, qui n'a que les droits de lecture et d'écriture sur les données.
5. Hibernate est configuré en `ddl-auto=validate` : au démarrage, il vérifie que le schéma
   correspond aux entités, mais ne le modifie jamais.
6. Pas de retour arrière automatique : en cas de problème, on écrit une migration corrective
   (*roll forward*).

## Conséquences

- **Ce qui devient plus simple** : les trois environnements sont toujours dans le même état ;
  les tests d'intégration partent d'un schéma créé exactement comme en production ; chaque
  évolution de schéma est relue en Pull Request.
- **Ce qui devient plus difficile** : il faut écrire du SQL pour chaque évolution, et penser
  aux migrations de données, pas seulement de structure. Depuis Flyway 10, le support d'Oracle
  est un module séparé (`flyway-database-oracle`) à ajouter explicitement.
- **Ce qu'il faudra surveiller** : les migrations longues ou bloquantes sur de gros volumes
  (verrous de table) ; la compatibilité de chaque migration avec Autonomous Database, vérifiée
  par les tests de fumée après déploiement.
- **Ce qui pourrait nous faire revenir sur cette décision** : un besoin fort de retours
  arrière automatiques ou de migrations conditionnelles selon l'environnement, qui orienterait
  vers Liquibase.
