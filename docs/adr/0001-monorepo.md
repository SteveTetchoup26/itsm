# ADR-001 : Un dépôt unique (monorepo) pour tout le projet

- **Statut** : Accepté
- **Date** : 2026-09-26
- **Incrément** : I0

## Contexte

Le projet comprend plusieurs composants : le backend Spring Boot, le frontend Angular,
les tests de bout en bout Playwright, les fichiers de déploiement (Docker Compose, puis Helm
et Terraform) et la documentation (cahiers des charges, ADR, runbooks).

Il faut décider si ces composants vivent dans un seul dépôt Git ou dans plusieurs.

Éléments qui pèsent sur la décision :

- **Une seule personne** développe le projet.
- Le backend et le frontend partagent un **contrat d'API** (OpenAPI) : une grande partie des
  user stories modifient les deux en même temps (par exemple US-01 : endpoint de création,
  migration Flyway, formulaire Angular, test de bout en bout).
- Les composants sont **déployés ensemble**, par un même pipeline, sur une même VM.
- Le projet est une **vitrine** : un recruteur doit pouvoir le comprendre à partir d'un seul lien.

## Options étudiées

### Option 1 : un dépôt unique (monorepo)

Un dépôt `itsm` avec les dossiers `backend/`, `frontend/`, `e2e/`, `deploy/`, `docs/`.

- Avantages :
  - une fonctionnalité qui touche l'API, la base et l'interface tient dans **une seule Pull
    Request**, relue et fusionnée en une fois : le backend et le frontend ne sont jamais
    désynchronisés ;
  - les tests de bout en bout vérifient toujours des versions du backend et du frontend qui
    vont réellement ensemble ;
  - un seul endroit pour les issues, le tableau Kanban, les ADR, la configuration de sécurité
    (Dependabot, Gitleaks, CodeQL) et les secrets du pipeline ;
  - un seul lien à partager.
- Inconvénients :
  - sans précaution, chaque commit reconstruit et teste tout, même pour une modification
    d'une ligne dans le frontend ;
  - le backend et le frontend partagent le même numéro de version ;
  - les droits d'accès sont les mêmes pour tout le dépôt.

### Option 2 : un dépôt par composant (polyrepo)

Des dépôts séparés : `itsm-backend`, `itsm-frontend`, `itsm-infra`, `itsm-docs`.

- Avantages :
  - chaque dépôt a un pipeline court et ciblé ;
  - chaque composant peut avoir son propre cycle de version et ses propres droits d'accès ;
  - organisation adaptée à des équipes différentes par composant.
- Inconvénients :
  - une fonctionnalité transverse demande **plusieurs Pull Requests** coordonnées, fusionnées
    dans le bon ordre ; entre deux fusions, les composants peuvent être incompatibles ;
  - il faut publier et versionner le contrat d'API pour le partager entre dépôts ;
  - la configuration (sécurité, modèles d'issue, pipeline) est dupliquée quatre fois ;
  - un recruteur doit parcourir quatre dépôts pour comprendre le projet.

## Décision

**Option 1 : un dépôt unique.** Pour un développeur seul, avec des composants fortement liés
par le contrat d'API et déployés ensemble, le coût de coordination du polyrepo dépasse
largement ses bénéfices, qui concernent surtout des équipes multiples.

## Conséquences

- **Ce qui devient plus simple** : les modifications transverses, la cohérence entre backend
  et frontend, la gestion du projet (un seul Kanban, une seule configuration de sécurité),
  la présentation du projet.
- **Ce qui devient plus difficile** : garder un pipeline rapide. Les jobs du pipeline seront
  déclenchés **selon les dossiers modifiés** (une modification dans `frontend/` ne relance
  pas les tests Java), à mettre en place dès I0.
- **Versions** : une seule version pour tout le produit (`v0.1.0`, `v0.2.0`...), cohérente
  avec un déploiement commun. L'image de chaque composant reste identifiée par le hash du
  commit.
- **Ce qu'il faudra surveiller** : la durée du pipeline. Au-delà de 15 minutes sur une Pull
  Request, il faudra optimiser (cache, parallélisation, filtres par dossier).
- **Ce qui pourrait nous faire revenir sur cette décision** : l'arrivée d'équipes distinctes
  par composant, le besoin de livrer le backend et le frontend à des rythmes différents, ou
  l'extraction d'un module (par exemple les notifications) en service autonome avec son
  propre cycle de vie.
