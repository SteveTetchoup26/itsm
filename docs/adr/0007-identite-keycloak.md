# ADR-007 : Délégation de l'identité à Keycloak

- **Statut** : Accepté
- **Date** : 2026-11-14
- **Incrément** : I1

## Contexte

À partir de I1, l'application doit savoir **qui** agit et avec **quels rôles** (`USER`,
`TECHNICIAN`, `MANAGER`, `ADMIN`, cahier fonctionnel §5.1) : un collaborateur ne voit que ses
tickets (RG-12), le créateur et le demandeur d'un ticket viennent de l'utilisateur connecté.

Contraintes :

- le cahier fonctionnel place la gestion des comptes et l'attribution des rôles dans le
  fournisseur d'identité de l'entreprise, pas dans l'application (§5.1) ;
- l'authentification est la partie la plus risquée d'une application : stockage des mots de
  passe, verrouillage, réinitialisation, sessions ;
- le frontend est une application Angular exécutée dans le navigateur : elle ne peut garder
  aucun secret ;
- budget : offre gratuite, VM de 12 Go (ADR-004), poste de 16 Go.

## Options étudiées

### Option 1 : authentification écrite dans l'application

Table des utilisateurs, mots de passe hachés, Spring Security avec un formulaire de connexion.

- Avantages : aucun service de plus à exploiter ; tout est dans une seule application.
- Inconvénients : on réécrit ce qui existe déjà, avec un risque de sécurité élevé (hachage,
  verrouillage, réinitialisation, double authentification) ; pas de connexion unique avec les
  autres applications de l'entreprise ; aucune compétence réutilisable.

### Option 2 : service d'identité hébergé (Auth0, Okta, Microsoft Entra ID)

- Avantages : rien à exploiter ; standards OIDC ; haute disponibilité assurée par le
  fournisseur.
- Inconvénients : coût par utilisateur au-delà de l'offre gratuite ; les données d'identité
  sortent de l'entreprise ; le fonctionnement du serveur d'identité reste caché, ce qui est
  moins formateur.

### Option 3 : Keycloak, hébergé par nous

Serveur d'identité open source (projet de la CNCF), qui parle OpenID Connect et OAuth 2.0.

- Avantages : gratuit ; données chez nous ; standards (Spring Security et Angular s'y
  branchent sans code propre à Keycloak) ; connexion unique, annuaire LDAP ou Active
  Directory possibles ; configuration exportable en fichier, donc versionnable.
- Inconvénients : un service Java de plus (environ 600 Mo de mémoire constatés en local) ; à
  sauvegarder, mettre à jour et surveiller ; s'il est arrêté, plus personne ne se connecte ;
  beaucoup de réglages, dont certains touchent à la sécurité.

## Décision

**Option 3 : l'identité est déléguée à Keycloak, par OpenID Connect.** L'application ne voit
jamais un mot de passe : le frontend redirige vers Keycloak, le backend vérifie les jetons
(serveur de ressources). Comme tout passe par un standard, changer de fournisseur ne
toucherait que la configuration.

Règles associées :

- **Realm `nordal`** : le realm représente l'entreprise, pas l'application (le cahier
  technique §9 citait `itsm` en exemple). D'autres applications de Nordal pourraient s'y
  brancher et partager la connexion.
- **Client `itsm-frontend`** : client public (aucun secret), flux **Authorization Code avec
  PKCE** (`S256` exigé). Les flux implicite et par mot de passe sont désactivés.
- **Rôles** : rôles du realm `USER`, `TECHNICIAN`, `MANAGER`, `ADMIN`, cumulables, transmis
  dans le jeton d'accès (`realm_access.roles`).
- **Jeton d'accès** : durée de vie de 5 minutes, audience `itsm-backend` (le backend refusera
  un jeton émis pour une autre application).
- **L'application ne stocke que** l'identifiant de l'utilisateur, son nom et son e-mail tels
  que transmis dans le jeton (cahier technique §4.3).
- **Configuration par fichier** : le realm est décrit dans
  `deploy/compose/keycloak/realm/nordal-realm.json`, versionné. Aucun mot de passe dans ce
  fichier : ceux des utilisateurs de test sont remplacés à l'import par une variable
  d'environnement.
- **En local** : mode développement (HTTP, base embarquée), **sans volume** : le realm est
  réimporté à chaque création du conteneur, le fichier est la seule source de vérité.
- La base de Keycloak et son mode de production en ligne sont décidés dans l'ADR-011 (I1-12).

## Conséquences

- Ce qui devient plus simple : aucune gestion de mots de passe dans l'application ; les
  rôles arrivent dans le jeton ; les tests du backend peuvent fabriquer des jetons sans
  Keycloak ; un environnement local identique pour tous, recréé depuis un fichier.
- Ce qui devient plus difficile : un service de plus à démarrer en local (limite mémoire de
  768 Mo) et à exploiter en ligne ; une modification faite dans la console d'administration
  est perdue à la recréation du conteneur si elle n'est pas reportée dans le fichier.
- Ce qu'il faudra surveiller : les versions de Keycloak (correctifs de sécurité) ; la
  cohérence entre le fichier du realm et ce que le backend et le frontend attendent (nom du
  client, audience, rôles) ; la mémoire réellement consommée.
- Ce qui pourrait nous faire revenir sur cette décision : une mémoire insuffisante sur la VM
  une fois Kafka et l'observabilité ajoutés (repli vers un service hébergé, sans changer le
  code grâce à OIDC) ; l'adoption par l'entreprise d'un fournisseur d'identité unique.
