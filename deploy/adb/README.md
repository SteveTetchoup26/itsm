# Base de production (Oracle Autonomous AI Database)

Base Oracle gérée par Oracle Cloud (ADR-004) : Autonomous AI Database **26ai**, offre
**Always Free**, type *Transaction Processing*, compartiment `itsm`, région Paris.
Mêmes comptes qu'en local (ADR-005) : l'application ne fait aucune différence entre les
environnements, seule l'URL de connexion change.

## Création (console, une fois)

*Oracle AI Database > Autonomous AI Database > Create*, compartiment **`itsm`** :

| Champ | Valeur |
|---|---|
| Display name / Database name | `itsm-db` / `itsm` |
| Workload type | Transaction Processing |
| Always Free | activé |
| Database version | 26ai |
| Mot de passe `ADMIN` | généré (24 caractères, lettres et chiffres), dans le gestionnaire de mots de passe |
| Network access | *Secure access from allowed IPs and VCNs only* : IP du poste, puis IP de la VM |
| Require mutual TLS (mTLS) | **décoché** : connexion TLS sans wallet (voir plus bas) |

## Connexion : TLS sans wallet ([ADR-017](../../docs/adr/0017-connexion-tls-autonomous-database.md))

La base Always Free est forcément joignable depuis Internet (pas de point d'accès privé).
Choix retenu : **TLS** (le client authentifie le serveur, tout est chiffré) **avec une liste
d'accès** (ACL) limitée aux IP du poste et de la VM, plutôt que **mTLS** (certificat client
dans un *wallet*).

- Pour : la connexion se résume à une URL dans une variable d'environnement, comme en local ;
  aucun fichier secret à distribuer, monter dans un conteneur et renouveler.
- Contre : sans certificat client, une machine autorisée par l'ACL qui serait compromise n'a
  plus que le mot de passe devant elle ; d'où des mots de passe longs et propres à la
  production.
- On passerait au mTLS si les clients n'avaient plus d'IP fixe (ACL impossible).

La chaîne de connexion se trouve dans *Database connection*, onglet **TLS**, service
**`itsm_tp`** (transactionnel ; `high`, `medium` et `low` sont destinés aux traitements
analytiques). Elle n'est pas secrète mais n'est pas versionnée (elle contient l'identifiant
de la base).

```bash
export ITSM_ADB_TP='(description= ... chaîne TLS de itsm_tp ... )'
sql ADMIN@"$ITSM_ADB_TP"                         # le mot de passe est demandé, jamais en argument
export ITSM_DB_URL="jdbc:oracle:thin:@$ITSM_ADB_TP"   # URL JDBC de l'application
```

## Comptes

[`create-itsm-accounts.sql`](create-itsm-accounts.sql), exécuté une fois en `ADMIN` ; les mots de
passe de `ITSM_OWNER` et `ITSM_APP` sont saisis au clavier (masqués) :

```bash
sql ADMIN@"$ITSM_ADB_TP" @deploy/adb/create-itsm-accounts.sql
```

Résultat attendu : les deux comptes `OPEN`, profil `ITSM_SERVICE_PROFILE`, tablespace `DATA`,
`EXPIRY_DATE` vide.

## Écarts avec Oracle Database Free (local et CI)

| Sujet | Local et CI (`gvenzl/oracle-free`) | Autonomous Database | Conséquence |
|---|---|---|---|
| Version | 23.26.3 | 23.26.4.1 (correctifs appliqués par Oracle) | suivre l'image locale pour rester proche |
| Administration | `SYSDBA`, conteneur `FREEPDB1` | utilisateur `ADMIN`, déjà dans la PDB ; pas de `SYSDBA` | script de comptes distinct (pas de `ALTER SESSION SET CONTAINER`) |
| Tablespace des données | `USERS` | `DATA` (`USERS` n'existe pas) | seule ligne différente dans la création de `ITSM_OWNER` ; les migrations ne nomment jamais de tablespace |
| Mots de passe | libres | `CLOUD_VERIFY_FUNCTION` : 12 à 30 caractères, majuscule, minuscule, chiffre, sans le nom du compte | mots de passe de production générés à part |
| Expiration des mots de passe | profil `DEFAULT` de l'image | profil `ITSM_SERVICE_PROFILE` : `PASSWORD_LIFE_TIME UNLIMITED` | jamais d'expiration subie ; rotation volontaire |
| Connexion | TCP en clair, port publié sur `127.0.0.1` | TCPS (TLS) port 1521, `ssl_server_dn_match=yes`, ACL par IP | seule `ITSM_DB_URL` change |
| Sessions | sans limite pratique | **30 sessions simultanées** | taille du pool Hikari à fixer en production (I0-11) |
| Inactivité | aucune | arrêt après **7 jours** sans connexion, suppression possible après **90 jours** arrêtée | se connecter chaque semaine tant que l'application n'est pas déployée |
| Stockage | volume Docker | 20 Go | largement suffisant pour le projet |

Vérifié le 2026-11-07 : le backend démarre contre la base en ligne, Flyway applique `V1` et la
vue `R__` avec `ITSM_OWNER`, l'application répond avec `ITSM_APP` (`readiness` `UP`).

## À faire quand la VM existera (I0-07)

- Ajouter l'**IP publique de la VM** à l'ACL (*Network > Access control list*).
- Vérifier la connexion depuis la VM (critère 3 de l'issue #19).
