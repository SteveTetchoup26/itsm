# ADR-006 : Monolithe modulaire et architecture hexagonale

- **Statut** : Accepté
- **Date** : 2026-11-14
- **Incrément** : I1

## Contexte

Le code métier commence en I1 (US-01 à US-03). Jusqu'ici, le backend ne contient qu'un module
technique (`system`, la page d'état de I0), sans règle d'organisation. Il faut fixer la
structure **avant** d'écrire la première règle métier : une structure se corrige très mal
après coup, quand tout dépend déjà de tout.

Contraintes :

- une seule personne développe et exploite l'application, sur une VM de 12 Go (ADR-004) ;
- le domaine est de taille modeste, mais porte de vraies règles : priorité calculée (RG-01),
  références uniques (RG-11), historique immuable (RG-09), puis machine à états et SLA ;
- d'autres modules arrivent (`sla`, `notification`, `reporting`, cahier technique §4.3) : ils
  ne doivent pas pouvoir se mélanger au module `ticket` ;
- les règles d'architecture doivent être **vérifiées par le pipeline**, pas seulement
  écrites : une règle que rien ne vérifie finit par être violée.

Deux questions distinctes se posent : comment découper l'application en morceaux métier, et
comment organiser l'intérieur de chaque morceau.

## Options étudiées

### Option 1 : microservices

Un service déployable par domaine (tickets, référentiels, notifications), chacun avec sa base.

- Avantages : frontières physiques, impossibles à contourner ; déploiement et montée en
  charge indépendants.
- Inconvénients : coût de la distribution (appels réseau, pannes partielles, cohérence entre
  bases, un pipeline et un déploiement par service) sans bénéfice pour une équipe d'une
  personne ; plusieurs JVM ne tiennent pas dans le budget mémoire de la VM.

### Option 2 : monolithe en couches (`controller`, `service`, `repository`)

Une application, des paquetages par couche technique, les entités JPA utilisées partout.

- Avantages : peu de classes, structure connue de tous, démarrage rapide.
- Inconvénients : aucune frontière métier (n'importe quel service appelle n'importe quel
  repository) ; les règles métier se retrouvent liées à JPA et à Spring, donc lentes à
  tester ; extraire un module plus tard demande de tout démêler.

### Option 3 : monolithe modulaire, architecture hexagonale dans tous les modules

Une application découpée en modules métier ; dans chaque module, les couches `domain`,
`application`, `adapter.in`, `adapter.out`.

- Avantages : frontières métier vérifiables ; domaine en Java pur, testé en quelques
  millisecondes ; une seule règle pour tout le code.
- Inconvénients : beaucoup de classes et de conversions (objet du domaine, entité JPA,
  objets de l'API) y compris là où il n'y a aucune règle à protéger, par exemple la simple
  lecture d'un référentiel.

### Option 4 : monolithe modulaire, architecture hexagonale là où il y a des règles métier

Comme l'option 3, mais les modules sans règle métier (lecture de référentiels, page d'état)
gardent une forme allégée, derrière la même frontière de module.

- Avantages : ceux de l'option 3, sans la cérémonie inutile ; le coût de l'hexagonal est payé
  là où il rapporte.
- Inconvénients : deux formes de module à connaître ; il faut décider, pour chaque module,
  laquelle s'applique, et savoir en changer si un module allégé gagne des règles.

## Décision

**Option 4 : monolithe modulaire, avec l'architecture hexagonale dans les modules qui portent
des règles métier.** Elle donne la discipline des microservices (frontières explicites,
vérifiées) sans leur coût, et réserve le coût de l'hexagonal au code qui le justifie.

### Règles des modules

1. Un module est un sous-paquetage direct de `fr.nordal.itsm` : `ticket`, `referential`,
   `shared`, `system` (puis `sla`, `notification`, `reporting`).
2. **L'API publique d'un module est le contenu de son paquetage racine** (par exemple
   `fr.nordal.itsm.referential`). Tout ce qui est dans ses sous-paquetages est interne : un
   autre module n'a pas le droit de s'en servir.
3. Aucune dépendance cyclique entre modules.
4. Un module ne lit ni n'écrit les tables d'un autre. Une clé étrangère entre tables de deux
   modules est permise (une seule base, intégrité garantie par Oracle), mais dans le code un
   module ne détient que l'**identifiant** de l'objet de l'autre, jamais son entité.
5. `shared` ne contient que des types techniques communs (identifiants, erreurs, horloge), en
   Java pur, et ne dépend d'aucun autre module.

### Règles des couches (modules hexagonaux : `ticket`, puis `sla`)

| Couche | Contenu | Peut dépendre de |
|---|---|---|
| `domain` | Entités, objets valeur, règles métier, ports (interfaces) | Rien : Java pur et `shared` |
| `application` | Cas d'usage, transactions, autorisations métier | `domain` |
| `adapter.in` | Contrôleurs REST, écouteurs d'événements | `application`, `domain` |
| `adapter.out` | Persistance JPA, clients externes : implémente les ports | `domain` |

- `domain` n'importe ni Spring, ni JPA, ni Jackson.
- Les adaptateurs ne dépendent pas les uns des autres.
- L'entité JPA (`adapter.out`) et l'objet du domaine sont deux classes distinctes.

### Forme allégée (`referential`, `system`)

Un seul paquetage, celui du module. Les classes n'ont **pas** le modificateur `public`
(contrôleur, service, accès aux données) : c'est le compilateur Java qui les rend invisibles
aux autres modules. Seuls les types qui forment l'API du module sont `public`. Les règles des
modules s'appliquent, pas celles des couches. Un module allégé passe à la forme hexagonale dès
qu'il porte une règle métier qui mérite un test sans base de données.

### Vérification

- **Spring Modulith 2.1.2** (construit pour Spring Boot 4.1) : un test `ApplicationModules.verify()`
  fait échouer le build si un module utilise l'intérieur d'un autre ou crée un cycle.
- **ArchUnit** (fourni par Spring Modulith) : des tests font échouer le build si les règles des
  couches sont violées, ou si `shared` dépend d'un framework.
- Chaque module déclare ses dépendances permises (`@ApplicationModule(allowedDependencies)`
  dans son `package-info.java`) : `ticket` vers `referential` et `shared`, `referential` vers
  `shared`, aucune pour `shared` et `system`.

## Conséquences

- Ce qui devient plus simple : tester les règles métier (sans Spring ni Oracle) ; savoir où
  ranger une classe ; ajouter un module sans toucher aux autres ; extraire un jour un module
  en service, ses dépendances étant déjà explicites.
- Ce qui devient plus difficile : plus de classes et de conversions dans les modules
  hexagonaux (un champ ajouté au ticket se déclare dans le domaine, l'entité JPA et l'API) ;
  une requête qui croise deux modules ne peut plus être une simple jointure dans le code.
- Ce qu'il faudra surveiller : que `shared` ne devienne pas un fourre-tout ; que le paquetage
  racine des modules reste petit ; le temps passé en conversions par rapport au bénéfice.
- Ce qui pourrait nous faire revenir sur cette décision : des conversions devenues plus
  coûteuses que les règles qu'elles protègent (retour à une forme allégée pour le module
  concerné) ; un module dont la charge ou le rythme de livraison diverge fortement des autres
  (extraction en service, nouvel ADR).
