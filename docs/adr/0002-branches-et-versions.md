# ADR-002 : Stratégie de branches et de versions

- **Statut** : Accepté
- **Date** : 2026-09-26
- **Incrément** : I0

## Contexte

Il faut définir comment le code circule jusqu'à `main` et comment les livraisons sont
numérotées.

Éléments qui pèsent sur la décision :

- **Une seule personne** développe le projet (voir ADR-001).
- Le projet vise le **déploiement continu** : chaque fusion dans `main` est déployée en ligne
  automatiquement (cahier des charges technique, §3 et §15). `main` doit donc toujours être
  dans un état déployable.
- La branche `main` est déjà protégée : Pull Request obligatoire, fusion par *squash*
  uniquement, historique linéaire.
- Une seule version de l'application tourne en ligne à un instant donné : il n'y a pas
  d'anciennes versions à maintenir en parallèle.

## Options étudiées

### Branches, option 1 : GitFlow

Branches permanentes `main` et `develop`, plus des branches `feature/`, `release/` et `hotfix/`.

- Avantages : adapté aux logiciels livrés par versions espacées, avec plusieurs versions
  maintenues en parallèle (logiciel installé chez des clients, par exemple).
- Inconvénients : nombreuses branches longues et fusions complexes ; `develop` et `main`
  divergent ; incompatible avec l'idée qu'une fusion dans `main` part en production.

### Branches, option 2 : trunk-based development avec branches courtes

Une seule branche permanente, `main`. Chaque travail se fait dans une branche courte, fusionnée
par Pull Request en quelques jours au plus.

- Avantages : simple ; conflits rares et petits ; chaque fusion est déployée, donc les
  problèmes apparaissent tôt ; c'est la pratique associée au déploiement continu.
- Inconvénients : `main` doit rester en permanence stable, ce qui exige un pipeline fiable
  et des changements découpés finement.

### Versions : numérotation sémantique (SemVer), numérotation par date (CalVer) ou hash de commit seul

- SemVer (`MAJEUR.MINEUR.CORRECTIF`) : le numéro indique la nature du changement ; standard
  le plus répandu.
- CalVer (`2026.09`) : adapté aux livraisons à date fixe, ce qui n'est pas notre cas.
- Hash de commit seul : précis pour la technique, mais illisible pour un humain.

## Décision

**Trunk-based development avec branches courtes, et SemVer pour les livraisons.**

Règles :

1. `main` est la seule branche permanente et reste toujours déployable.
2. Une branche par issue, préfixée selon sa nature : `feat/`, `fix/`, `docs/`, `chore/`,
   `test/`, `refactor/`. Exemple : `feat/ticket-creation`. Durée de vie visée : moins de
   trois jours.
3. Fusion uniquement par Pull Request, en *squash* : un commit par Pull Request dans `main`.
4. Messages de commit et titres de Pull Request au format **Conventional Commits** :
   `type(portée): description`, par exemple `feat(ticket): create incident`.
5. Une correction urgente suit le même chemin qu'une évolution (branche `fix/`, Pull Request) :
   comme `main` est toujours déployable, aucune branche spéciale n'est nécessaire.
6. Numérotation des livraisons en **SemVer 0.x** tant que le produit n'est pas stabilisé :
   - fin de I0 : `v0.0.1` ; fin de chaque incrément suivant : `v0.<n>.0` (I1 donne `v0.1.0`,
     I2 donne `v0.2.0`, etc.) ;
   - correctif entre deux incréments : on incrémente le troisième chiffre (`v0.1.1`) ;
   - `v1.0.0` sera une décision explicite, au plus tôt à la fin du MVP (I3).
7. Chaque image Docker est étiquetée avec le hash du commit (`sha-3f2a1c9`) ; une livraison
   ajoute en plus l'étiquette de version (`v0.1.0`).

## Conséquences

- **Ce qui devient plus simple** : le flux de travail (une seule règle pour tout), la
  lecture de l'historique (un commit lisible par fonctionnalité), et plus tard la génération
  automatique du journal des modifications à partir des Conventional Commits.
- **Ce qui devient plus difficile** : garder `main` stable. Cela impose, dès I0, que les
  vérifications du pipeline soient **obligatoires** avant fusion, et que les fonctionnalités
  longues soient découpées en petites Pull Requests. Une fonctionnalité inachevée mais
  fusionnée reste invisible pour l'utilisateur, par exemple derrière un paramètre
  d'activation.
- **Ce qu'il faudra surveiller** : l'âge des branches. Une branche ouverte depuis plus d'une
  semaine signale un découpage trop gros.
- **Ce qui pourrait nous faire revenir sur cette décision** : devoir maintenir plusieurs
  versions en production en parallèle (on ajouterait alors des branches `release/`), ou une
  équipe plus grande avec un processus de validation avant mise en production.
