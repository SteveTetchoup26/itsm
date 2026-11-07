# Réseau privé Tailscale (ADR-012)

Le pipeline et le poste d'administration joignent la VM par un réseau privé chiffré
(*tailnet*, WireGuard) : la VM n'expose aucun port d'administration sur Internet.

| Membre | Identité | Accès |
|---|---|---|
| VM de production | étiquette `tag:itsm-vm` | ne joint personne |
| Job de déploiement | étiquette `tag:ci`, nœud **éphémère** (supprimé à la fin du job) | port 22 de la VM uniquement |
| Poste du propriétaire | compte GitHub (`autogroup:member`) | la VM |

## Politique d'accès

[`policy.hujson`](policy.hujson) est la source de vérité. Pour l'appliquer : console Tailscale,
*Access controls > JSON editor*, remplacer tout le contenu, *Save*. Tout ce qui n'est pas
autorisé est refusé ; le bloc `tests` est vérifié à chaque enregistrement (la console refuse
une politique qui ouvrirait par exemple le port 443 au pipeline).

## Authentification du pipeline sans secret (OIDC)

*Settings > Trust credentials*, identité fédérée **OpenID Connect** :

| Champ | Valeur |
|---|---|
| Issuer | GitHub (`https://token.actions.githubusercontent.com`) |
| Subject | `repo:SteveTetchoup26/itsm:environment:production` |
| Scope | Auth Keys : Write |
| Tags | `tag:ci` |

GitHub signe un jeton décrivant le job ; Tailscale n'admet que les jobs de ce dépôt qui
déclarent l'environnement **`production`**, lui-même réservé à la branche `main` (*Settings >
Environments*). Un job lancé par une Pull Request ne peut donc pas joindre la VM.

Le *Client ID* et l'*Audience* ne sont pas des secrets : ils sont rangés comme **variables** de
l'environnement `production` (`TS_OAUTH_CLIENT_ID`, `TS_AUDIENCE`). Utilisation dans un job :

```yaml
environment: production
permissions:
  id-token: write   # demande du jeton OIDC à GitHub
steps:
  - uses: tailscale/github-action@v4   # à épingler par SHA
    with:
      oauth-client-id: ${{ vars.TS_OAUTH_CLIENT_ID }}
      audience: ${{ vars.TS_AUDIENCE }}
      tags: tag:ci
```

## Poste d'administration

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
tailscale status
```

## À faire quand la VM existera (I0-07)

1. Installer Tailscale sur la VM et la faire rejoindre le réseau avec `tag:itsm-vm`.
2. Vérifier `ssh ubuntu@itsm-vm` depuis le poste par le réseau privé.
3. Job de test : connexion SSH de `tag:ci` à la VM (critère 4 de l'issue #20).
4. Supprimer la règle du port 22 dans la liste de sécurité Oracle Cloud (critère 5).
