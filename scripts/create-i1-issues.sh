#!/usr/bin/env bash
# Cree les issues de l'increment I1 (declarer et consulter). Rejouable : ignore les titres existants.
# Usage : ./scripts/create-i1-issues.sh
set -euo pipefail

MILESTONE="I1 : declarer et consulter"
existing="$(gh issue list --state all --limit 300 --json title -q '.[].title')"

create() {
  local title="$1" labels="$2" body
  body="$(cat)"
  if grep -qxF "$title" <<<"$existing"; then
    echo "  deja existante : $title"; return
  fi
  local url
  url="$(gh issue create --title "$title" --label "$labels" --milestone "$MILESTONE" --body "$body")"
  echo "  $url  $title"
}

echo "Creation des issues de I1"

create "I1-01 : architecture des modules (monolithe modulaire, hexagonal)" "type:adr,type:tech,area:backend" <<'EOF'
## Objectif
Poser la structure du backend avant tout code metier : modules aux frontieres verifiees, couches hexagonales.

## Criteres de fin
1. ADR-006 redige et accepte (monolithe modulaire, architecture hexagonale, Spring Modulith, ArchUnit).
2. Modules `ticket`, `referential` et `shared` crees (`fr.nordal.itsm.<module>.<couche>`).
3. Test Spring Modulith : les dependances entre modules respectent les API publiques.
4. Tests ArchUnit : `domain` ne depend d'aucun framework ; `adapter` -> `application` -> `domain`.
5. Le module `system` de I0 est range selon les memes regles.

## References
Cahier technique §4.2 a §4.5 ; ADR-006.
EOF

create "I1-02 : Keycloak en local (realm nordal)" "type:adr,type:tech,area:security,area:infra" <<'EOF'
## Objectif
Disposer du fournisseur d'identite en local, configure par fichier versionne.

## Criteres de fin
1. ADR-007 redige et accepte (delegation de l'identite a Keycloak, OIDC).
2. Keycloak 26 dans `deploy/compose` (limite memoire explicite), realm `nordal` importe au demarrage depuis un fichier versionne.
3. Roles `USER`, `TECHNICIAN`, `MANAGER`, `ADMIN` ; client public du frontend (Authorization Code + PKCE).
4. Utilisateurs de test des personas (Sophie, collaboratrice, etc.), mots de passe hors Git.
5. Documentation : demarrage, comptes de test, export du realm.

## References
Cahier fonctionnel §5 ; cahier technique §9 ; ADR-007.
EOF

create "I1-03 : backend protege par jeton JWT" "type:tech,area:backend,area:security" <<'EOF'
## Objectif
Le backend verifie les jetons emis par Keycloak et connait l'utilisateur et ses roles.

## Criteres de fin
1. Serveur de ressources OAuth2 : signature, emetteur et expiration du JWT verifies.
2. Roles du realm convertis en autorites Spring ; utilisateur courant disponible pour les cas d'usage.
3. `GET /api/v1/me` : identifiant, nom, e-mail, roles ; 401 sans jeton.
4. Actuator `health` et `/api/v1/system/info` restent publics.
5. Tests d'integration avec des jetons de test (sans Keycloak reel).

## References
Cahier technique §17 ; ADR-007.
EOF

create "I1-04 : conventions d'API (Problem Details, validation, OpenAPI)" "type:adr,type:tech,area:backend" <<'EOF'
## Objectif
Fixer une fois pour toutes la forme des erreurs, la validation et le contrat d'API.

## Criteres de fin
1. ADR-008 redige et accepte (actions metier explicites, prefixe `/api/v1`, Problem Details RFC 9457).
2. Toute erreur renvoie un `application/problem+json` (type, titre, statut, detail, champs en erreur) ; jamais de trace technique.
3. Validation des requetes (Bean Validation) : champ en erreur et regle dans la reponse.
4. Contrat OpenAPI genere (springdoc), publie dans `api/` et compare a chaque PR (changements incompatibles detectes).
5. Collection Bruno initiale dans `api/`.

## References
Cahier technique §14 ; ADR-008.
EOF

create "I1-05 : referentiels initiaux (categories, groupes de support)" "type:tech,area:backend,area:database" <<'EOF'
## Objectif
Disposer des categories et groupes necessaires a la creation d'un ticket (l'administration arrive en I3).

## Criteres de fin
1. Tables `CATEGORY` (deux niveaux, groupe par defaut, active) et `SUPPORT_GROUP`, migrations Flyway, droits accordes a `ITSM_APP_ROLE`.
2. Donnees initiales du cahier fonctionnel (§5.2, §8.6) chargees par migration.
3. API de lecture des categories actives (arborescence).
4. Tests d'integration sur Oracle (Testcontainers).

## References
Cahier fonctionnel §5.2, §8.6 ; RG-17.
EOF

create "I1-06 : domaine du ticket (priorite, reference)" "type:tech,area:backend" <<'EOF'
## Objectif
Le coeur metier du ticket en Java pur, teste sans Spring ni base.

## Criteres de fin
1. Agregat `Ticket` : type, titre (5 a 120), description (5 000 max), demandeur, createur, categorie, impact, urgence, statut `NEW`.
2. Priorite calculee par la matrice du §8.3, jamais saisie (RG-01) : 9 cas testes.
3. Reference `INC-AAAA-NNNNNN` / `REQ-AAAA-NNNNNN`, unique, sequentielle par type et par annee, jamais reutilisee (RG-11) ; port de generation.
4. Tests unitaires du domaine en quelques millisecondes.

## References
Cahier fonctionnel §8.2, §8.3 ; RG-01, RG-11.
EOF

create "US-01 : declarer un ticket" "type:story,area:backend" <<'EOF'
## User story
En tant que collaborateur, je veux declarer un incident ou une demande afin d'obtenir de l'aide.

## Criteres d'acceptation
Scenario : creation d'un incident valide
  Etant donne un collaborateur authentifie
  Quand il cree un incident avec un titre, une description, la categorie "Poste de travail", un impact "une personne" et une urgence "bloquant"
  Alors le ticket est cree au statut NEW
  Et sa priorite est P3
  Et sa reference a la forme INC-AAAA-NNNNNN
  Et il est assigne au groupe "Poste de travail"

Scenario : titre trop court
  Etant donne un collaborateur authentifie
  Quand il cree un ticket avec un titre de 3 caracteres
  Alors la creation est refusee
  Et le message indique le champ en erreur et la regle

Note : le calcul des echeances SLA, prevu dans le critere du cahier fonctionnel, est reporte en I3 avec le module `sla` (decision du 2026-11-07).

## Criteres techniques
1. Cas d'usage, persistance JPA (`ddl-auto=validate`), table `TICKET` et sequences par migration Flyway, droits sans `DELETE` (RG-10).
2. `POST /api/v1/tickets` ; createur et demandeur issus du jeton.
3. Chaque scenario est un test automatise (REST Assured, Oracle Testcontainers).
4. Requete ajoutee a la collection Bruno.

## References
Cahier fonctionnel §8.2, §9.6 ; RG-01, RG-10, RG-11.
EOF

create "US-02 : consulter la liste de mes tickets" "type:story,area:backend" <<'EOF'
## User story
En tant que collaborateur, je veux voir la liste de mes tickets, paginee, filtrable par statut et triable par date, afin de suivre mes demandes.

## Criteres d'acceptation
Scenario : je ne vois que mes tickets
  Etant donne deux collaborateurs ayant chacun cree un ticket
  Quand le premier consulte sa liste
  Alors il voit son ticket et pas celui de l'autre (RG-12)

Scenario : filtre et tri
  Etant donne trois de mes tickets de statuts et de dates differents
  Quand je filtre sur le statut NEW et trie par date de creation decroissante
  Alors seuls les tickets NEW apparaissent, du plus recent au plus ancien

Scenario : pagination
  Etant donne 25 de mes tickets
  Quand je demande la page 2 de taille 10
  Alors je recois 10 tickets et le nombre total de 25

## Criteres techniques
1. `GET /api/v1/tickets` (demandeur ou createur), parametres de page, taille bornee, statut, tri.
2. Index Oracle adaptes (`IX_`), requete verifiee par un plan d'execution.
3. Tests d'integration des trois scenarios.

## References
Cahier fonctionnel §9.1 ; RG-12.
EOF

create "US-03 : consulter le detail et l'historique d'un ticket" "type:story,area:backend" <<'EOF'
## User story
En tant que collaborateur, je veux consulter le detail et l'historique public d'un ticket afin de savoir ou il en est.

## Criteres d'acceptation
Scenario : detail de mon ticket
  Etant donne un ticket dont je suis le demandeur
  Quand j'en consulte le detail
  Alors je vois ses attributs et son historique, dont l'evenement de creation

Scenario : ticket d'un autre collaborateur
  Etant donne un ticket dont je ne suis ni demandeur ni createur
  Quand j'en demande le detail
  Alors la reponse est 404 (son existence n'est pas revelee)

## Criteres techniques
1. Table d'historique immuable (RG-09) : insertion seule, aucun droit `UPDATE` ni `DELETE`.
2. `GET /api/v1/tickets/{reference}` et son historique public.
3. Tests d'integration des deux scenarios.

## References
Cahier fonctionnel §8.7 ; RG-09, RG-12.
EOF

create "I1-10 : frontend, connexion et ossature" "type:tech,area:frontend,area:security" <<'EOF'
## Objectif
L'application Angular authentifie l'utilisateur par Keycloak et pose son ossature visuelle.

## Criteres de fin
1. Connexion OIDC (Authorization Code + PKCE) avec une bibliotheque certifiee ; jeton ajoute aux appels `/api` ; deconnexion.
2. Routes protegees ; affichage du nom et des roles de l'utilisateur.
3. Angular Material : mise en page, navigation, theme ; regles d'accessibilite respectees.
4. Tests Vitest des garde-fous et de l'intercepteur.

## References
Cahier technique §8 ; ADR-007.
EOF

create "I1-11 : frontend, ecrans de creation, liste et detail" "type:story,area:frontend" <<'EOF'
## Objectif
Les ecrans de US-01, US-02 et US-03.

## Criteres de fin
1. Formulaire de creation : questions en langage courant pour l'impact et l'urgence (§8.3), erreurs de validation affichees par champ (Problem Details).
2. Liste paginee, filtre par statut, tri par date.
3. Detail et historique public.
4. Accessibilite verifiee (navigation clavier, libelles) ; tests Vitest des composants.

## References
Cahier fonctionnel §8.3, §14 ; US-01 a US-03.
EOF

create "I1-12 : bout en bout, Keycloak en ligne et livraison v0.1.0" "type:tech,area:infra,area:ci-cd" <<'EOF'
## Objectif
Demontrer l'increment en ligne : Sophie se connecte et cree un ticket.

## Criteres de fin
1. ADR-011 redige et accepte (base de Keycloak en ligne).
2. Keycloak deploye sur la VM derriere Caddy, realm `nordal` importe.
3. Test Playwright du parcours "Sophie se connecte et cree un ticket", lance par le pipeline.
4. Journal de I1 dans `docs/journal/` ; etiquette `v0.1.0`.

## References
Cahier technique §21 ; ADR-011. Depend de la VM (I0-07).
EOF

echo "Termine."
