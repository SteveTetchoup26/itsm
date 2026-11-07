# ADR-017 : Connexion à l'Autonomous Database en TLS sans wallet, avec liste d'accès

- **Statut** : Accepté
- **Date** : 2026-11-07
- **Incrément** : I0

## Contexte

La base de production est une Autonomous AI Database Always Free (ADR-004). Dans cette offre,
la base ne peut pas avoir de point d'accès privé ni être placée dans un réseau virtuel : elle
est **joignable depuis Internet**. Il faut choisir comment l'application (sur la VM) et
l'administrateur (sur le poste) s'y connectent.

Contraintes :

- la configuration doit rester la même dans tous les environnements : l'application lit
  l'URL de la base dans `ITSM_DB_URL`, en local comme en production ;
- aucun secret dans Git, et le moins possible de secrets à distribuer (projet tenu par une
  seule personne) ;
- les clients sont peu nombreux et ont une adresse IP fixe : la VM, et le poste
  d'administration.

## Options étudiées

### Option 1 : mTLS avec wallet (choix par défaut d'Oracle)

Le client présente un certificat, fourni dans un fichier *wallet* téléchargé depuis la console.

- Avantages : authentification du client par certificat avant même le mot de passe ; aucune
  liste d'adresses à tenir.
- Inconvénients : le wallet contient une clé privée, c'est donc un secret de plus à stocker,
  copier sur la VM, monter dans le conteneur et renouveler ; la configuration de
  l'application diffère entre le local (URL simple) et la production (URL plus fichier).

### Option 2 : TLS sans wallet, avec liste d'accès (ACL)

Connexion chiffrée en TLS (`tcps`) : le client vérifie le certificat du serveur
(`ssl_server_dn_match=yes`), puis s'authentifie par mot de passe. Oracle impose alors une liste
d'accès : seules les adresses IP déclarées peuvent se connecter.

- Avantages : la connexion se résume à une URL ; aucun fichier secret ; les autorités de
  certification du JDK suffisent ; les connexions venant d'autres adresses sont refusées
  avant toute authentification.
- Inconvénients : pas de certificat client ; il faut mettre à jour la liste d'accès quand une
  adresse change (IP du poste, nouvelle VM).

## Décision

**Option 2 : TLS sans wallet, avec une liste d'accès** limitée à l'IP de la VM et à celle du
poste d'administration. Les clients ont des IP fixes, ce qui rend l'ACL possible, et l'URL
seule garde une configuration identique entre environnements sans secret supplémentaire.

Règles associées :

- service `itsm_tp` (transactionnel) pour l'application ;
- mots de passe propres à la production, longs (24 caractères), différents du local ;
- la chaîne de connexion n'est pas versionnée.

## Conséquences

- Ce qui devient plus simple : la configuration de l'application (une variable
  d'environnement) et le déploiement (aucun fichier à monter).
- Ce qui devient plus difficile : la liste d'accès est à tenir à jour ; un changement d'IP du
  poste ou de la VM coupe l'accès jusqu'à sa mise à jour.
- Ce qu'il faudra surveiller : le contenu de la liste d'accès (aucune adresse inutile) ; les
  échecs de connexion dans l'audit de la base.
- Ce qui pourrait nous faire revenir sur cette décision : des clients sans IP fixe (runner de
  CI se connectant à la base, poste nomade), ou une exigence de conformité imposant le mTLS.
  Le passage au mTLS ne toucherait que `ITSM_DB_URL` et l'ajout du wallet sur la VM.
