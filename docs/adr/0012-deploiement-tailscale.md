# ADR-012 : Déploiement sur la VM via un réseau privé Tailscale

- **Statut** : Accepté
- **Date** : 2026-09-26
- **Incrément** : I0

## Contexte

À chaque fusion dans `main`, le pipeline GitHub Actions doit mettre à jour l'application sur la
VM Oracle Cloud (ADR-004) : récupérer les nouvelles images et redémarrer les conteneurs.

Le pipeline doit donc pouvoir agir sur la VM. Or :

- les machines de GitHub Actions utilisent des **milliers d'adresses IP** qui changent en
  permanence : filtrer le port SSH par adresse IP est impraticable ;
- un port SSH ouvert sur Internet est scanné et attaqué en permanence ;
- le dépôt est **public** : n'importe qui peut proposer une Pull Request.

Objectif : déployer automatiquement **sans exposer le port SSH sur Internet**.

## Options étudiées

### Option A : SSH direct depuis GitHub Actions

- Avantages : le plus simple ; aucun outil supplémentaire.
- Inconvénients : le port 22 doit être ouvert à toutes les adresses de GitHub, donc presque au
  monde entier. La sécurité repose entièrement sur la clé SSH.

### Option B : réseau privé Tailscale

La VM et, pendant le déploiement seulement, la machine du pipeline rejoignent un réseau privé
chiffré (*tailnet*). Le pipeline se connecte en SSH à la VM par ce réseau.

- Avantages : **port 22 fermé sur Internet** ; seules les machines autorisées du réseau privé
  peuvent joindre la VM ; la machine du pipeline n'existe dans le réseau que le temps du job ;
  le déploiement reste déclenché par le pipeline, avec un résultat visible dans GitHub.
- Inconvénients : dépendance à un service tiers (gratuit pour un usage personnel) ; un
  élément de plus à configurer et à comprendre.

### Option C : mode « pull » depuis la VM

Un service sur la VM vérifie régulièrement le registre d'images et se met à jour seul.

- Avantages : aucune connexion entrante.
- Inconvénients : le pipeline ne sait pas si le déploiement a réussi ; pas de tests de fumée
  ni de retour arrière pilotés par le pipeline ; délai entre la fusion et la mise à jour.

### Option D : runner GitHub Actions installé sur la VM

- Avantages : aucune connexion à ouvrir.
- Inconvénients : **dangereux sur un dépôt public**. Une Pull Request venant d'un inconnu peut
  modifier un workflow pour exécuter n'importe quelle commande sur le runner, donc sur la VM
  de production. GitHub déconseille explicitement cette configuration.

## Décision

**Option B : Tailscale.**

Fonctionnement :

1. La VM rejoint le réseau privé avec l'étiquette `tag:itsm-vm`.
2. Le job de déploiement rejoint le réseau avec l'étiquette `tag:ci`, grâce à l'action
   officielle `tailscale/github-action`. Le nœud créé est **éphémère** : il disparaît à la fin
   du job.
3. L'authentification du pipeline auprès de Tailscale se fait par **fédération d'identité
   OIDC** (*workload identity federation*) : GitHub prouve à Tailscale l'identité du workflow,
   sans secret longue durée stocké dans GitHub. À défaut, un client OAuth Tailscale, dont le
   secret est stocké dans les secrets GitHub.
4. La politique d'accès Tailscale n'autorise que : `tag:ci` vers `tag:itsm-vm` sur le port 22,
   et les appareils du propriétaire vers `tag:itsm-vm`. Tout le reste est refusé.
5. Le pipeline se connecte en SSH avec un utilisateur dédié `deploy` et une **clé SSH dédiée
   au pipeline**. L'empreinte de la VM est vérifiée (fichier `known_hosts` fourni au pipeline)
   pour éviter l'usurpation.
6. Le job de déploiement ne s'exécute que sur `main`, jamais pour une Pull Request.
7. Côté Oracle Cloud, la liste de sécurité n'ouvre que les ports 80 et 443. **Le port 22 est
   fermé** : Tailscale n'a besoin d'aucun port entrant.
8. Accès de secours si Tailscale est indisponible : la console série d'Oracle Cloud, depuis
   l'interface web, protégée par l'authentification multifacteur du compte.

## Conséquences

- **Ce qui devient plus simple** : la surface d'attaque (aucun port d'administration exposé) ;
  l'administration de la VM depuis le poste, qui rejoint lui aussi le réseau privé.
- **Ce qui devient plus difficile** : la mise en place initiale (compte Tailscale, étiquettes,
  politique d'accès, fédération d'identité) ; le diagnostic d'un échec de déploiement, qui
  peut venir du réseau privé, de SSH ou de Docker.
- **Point de vigilance** : l'utilisateur `deploy` appartient au groupe `docker`, ce qui revient
  en pratique à des droits administrateur sur la VM. C'est accepté, car la clé n'est utilisable
  qu'à travers le réseau privé et que le job ne tourne que sur `main`.
- **Ce qu'il faudra surveiller** : la liste des appareils du réseau privé (aucun appareil
  inconnu) ; les connexions SSH dans les journaux de la VM.
- **Ce qui pourrait nous faire revenir sur cette décision** : la fin de l'offre gratuite de
  Tailscale ; le passage à Kubernetes en I6, où le déploiement pourra passer par l'API du
  cluster, elle aussi joignable uniquement par le réseau privé.
