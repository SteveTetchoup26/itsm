# ADR-004 : Hébergement en ligne sur Oracle Cloud (offre Always Free)

- **Statut** : Accepté
- **Date** : 2026-09-26
- **Incrément** : I0

## Contexte

L'application doit être déployée en ligne dès I0, automatiquement, à chaque fusion dans `main`
(ADR-002). Il faut choisir où l'héberger, et avec quelle base de données.

Contraintes :

- **Budget nul** : le projet est personnel et doit rester gratuit.
- **Oracle Database** est imposée par le cahier des charges.
- La pile complète demande de la mémoire : backend Spring Boot, Keycloak, puis Kafka et un
  collecteur OpenTelemetry. Le budget mémoire estimé est d'environ 5,5 Go
  (cahier des charges technique, §5.4).
- Le déploiement doit rester **reproductible et portable** : on doit pouvoir changer
  d'hébergeur sans réécrire l'application.

## Options étudiées

### Option 1 : Oracle Cloud Infrastructure, offre Always Free

Une VM Ampere A1 (ARM) de 2 OCPU et 12 Go de mémoire, plus une base Oracle Autonomous
Database gérée par Oracle.

- Avantages :
  - gratuit sans limite de durée ;
  - une **vraie base Oracle gérée** (sauvegardes, mises à jour), qui ne consomme pas la
    mémoire de la VM ;
  - 12 Go de mémoire : suffisant pour toute la pile applicative ;
  - expérience d'un vrai fournisseur cloud (réseau virtuel, pare-feu, compartiments, IAM).
- Inconvénients :
  - conditions changeantes : l'allocation gratuite a été divisée par deux en juin 2026, sans
    annonce ;
  - capacité ARM parfois indisponible dans la région ;
  - processeur ARM : les images Docker doivent être construites pour `arm64` ;
  - une VM ou une base jugée inactive peut être arrêtée par Oracle ;
  - Autonomous Database diffère d'Oracle Database Free utilisée en local (connexion par
    *wallet*, certaines opérations d'administration interdites).

### Option 2 : plateforme d'hébergement avec offre gratuite (Render, Railway, Fly.io...)

- Avantages : déploiement très simple, HTTPS fourni.
- Inconvénients : aucune base Oracle proposée ; mémoire gratuite de quelques centaines de Mo,
  insuffisante pour Spring Boot et Keycloak ; mise en veille des applications inactives ;
  on apprend la plateforme plutôt que l'infrastructure.

### Option 3 : VPS payant (Hetzner, OVH...)

- Avantages : conditions stables, 4 à 8 Go de mémoire pour quelques euros par mois.
- Inconvénients : payant ; la base Oracle devrait tourner en conteneur sur la même machine
  et consommerait plusieurs gigaoctets de mémoire.

## Décision

**Option 1 : Oracle Cloud Infrastructure, offre Always Free**, avec la VM Ampere A1 pour les
conteneurs de l'application et Autonomous Database pour les données. C'est la seule option
gratuite qui offre à la fois assez de mémoire et une vraie base Oracle.

Règles associées :

- toutes les ressources sont créées dans le compartiment `itsm`, dans la région d'origine ;
- le compte reste en offre gratuite (pas de passage en *Pay As You Go*) ; une alerte de
  budget à 1 prévient de toute dépense ;
- seuls les ports 80 et 443 sont ouverts au public (l'accès SSH est traité dans l'ADR-012).

## Conséquences

- **Ce qui devient plus simple** : la base de données (sauvegardes et mises à jour gérées par
  Oracle), le coût (nul).
- **Ce qui devient plus difficile** :
  - le pipeline doit construire des images **multi-architecture** (`amd64` pour le poste et la
    CI, `arm64` pour la VM) ;
  - l'écart entre Oracle Database Free (local, CI) et Autonomous Database (en ligne) doit être
    maîtrisé : les tests de fumée après chaque déploiement vérifient que les migrations
    passent aussi en ligne ;
  - l'observabilité complète ne tient pas sur la VM : la télémétrie en ligne sera envoyée
    vers Grafana Cloud (ADR-015).
- **Ce qu'il faudra surveiller** : les e-mails d'Oracle sur l'inactivité des ressources et
  sur les conditions de l'offre gratuite ; la mémoire réellement consommée sur la VM.
- **Ce qui pourrait nous faire revenir sur cette décision** : une nouvelle réduction ou la
  suppression de l'offre gratuite. Le plan de repli est un VPS (option 3) avec Oracle Database
  Free en conteneur. Il reste réaliste parce que l'application est configurée par variables
  d'environnement, que les images existent en `amd64` et `arm64`, et que l'infrastructure sera
  décrite en code en I6.
