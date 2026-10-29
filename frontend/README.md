# Frontend (Angular)

Application web de la plateforme ITSM : Angular 22 (composants autonomes, signals, sans
`zone.js`), TypeScript 6, SCSS. Angular Material arrive en I1.

Pour l'instant, une seule page : l'état du système (versions de l'application et du schéma,
état de la base), lu sur `GET /api/v1/system/info`.

## Prérequis

- Node.js 24 (LTS) et npm.
- Pour voir des données : le backend démarré sur le port 8080 (voir [backend](../backend/README.md)).

## Commandes

Depuis `frontend/` :

| Commande               | Rôle                                                                                                                   |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `npm ci`               | installe exactement les versions de `package-lock.json` (à préférer à `npm install`, sauf pour ajouter une dépendance) |
| `npm start`            | serveur de développement sur http://localhost:4200, rechargement automatique                                           |
| `npm test`             | tests Vitest en mode surveillance (`npm test -- --watch=false` pour une seule exécution)                               |
| `npm run lint`         | ESLint, dont les règles d'accessibilité des gabarits                                                                   |
| `npm run format`       | formate le code avec Prettier (avant chaque commit)                                                                    |
| `npm run format:check` | vérifie le formatage sans rien modifier (ce que fera la CI)                                                            |
| `npm run build`        | build de production dans `dist/itsm-frontend/`                                                                         |

## Appels à l'API

Le code appelle toujours des URL **relatives** (`/api/...`), jamais `http://localhost:8080`.

- **En développement**, `ng serve` redirige `/api/**` vers `http://localhost:8080`
  (`proxy.conf.json`). Le navigateur ne voit qu'une origine (`localhost:4200`) : aucune
  configuration CORS n'est nécessaire. Backend arrêté : le proxy répond `502 Bad Gateway`.
- **En production**, Caddy joue le même rôle (I0-10) : le frontend et l'API sont servis sous la
  même adresse.

Toute modification de `proxy.conf.json` demande de redémarrer `npm start`.

## Image Docker

`Dockerfile` multi-étapes : build Angular avec Node sur l'architecture de la machine, puis
image d'exécution `nginxinc/nginx-unprivileged` (Nginx non root, utilisateur 101, port 8080, sans
Node), avec les correctifs de sécurité d'Alpine (`apk upgrade`). `nginx.conf` renvoie
`index.html` pour toute route inconnue (application monopage), met en cache un an les fichiers
JS et CSS (leur nom contient une empreinte) et jamais `index.html`. HTTPS, compression et
routage de `/api` sont faits par Caddy devant (I0-10).

```bash
docker buildx build --load -t itsm-frontend:local .
docker run --rm -p 127.0.0.1:8082:8080 itsm-frontend:local   # http://localhost:8082
```

## Organisation

Le code est rangé par fonctionnalité : `src/app/system/` contient le composant `SystemStatus`,
son gabarit, ses styles, son test et le type `SystemInfo` (contrat de l'API).

## VS Code

Ouvrir la **racine** du dépôt. Les extensions recommandées (Angular Language Service, ESLint,
Prettier) sont proposées à l'ouverture. `.vscode/settings.json` (versionné) fait tourner
l'extension ESLint depuis `frontend/` et lui fait analyser les gabarits HTML. Le formatage à
l'enregistrement relève des réglages personnels.
