# Mise en place : comptes, dépôt et poste de travail

Ce guide prépare tout ce dont l'incrément I0 a besoin. Il n'y a pas de code à écrire, mais
chaque étape a une raison d'être, et elle est expliquée. Compte environ une demi-journée,
plus l'éventuel délai de validation du compte Oracle Cloud.

## Ordre conseillé

| # | Étape | Dépend de | Durée indicative |
|---|---|---|---|
| 0 | Gestionnaire de mots de passe | Rien | 15 min |
| 1 | Compte Oracle Cloud | Rien (à lancer tôt : la validation peut prendre du temps) | 30 min |
| 2 | Poste de travail | Rien | 1 à 2 h |
| 3 | Dépôt GitHub | Étape 2 (git, gh) | 20 min |
| 4 | SonarQube Cloud | Étape 3 | 10 min |
| 5 | DuckDNS | Rien | 5 min |

---

## 0. Gestionnaire de mots de passe

Tu vas créer plusieurs comptes et plusieurs secrets (jetons, mots de passe de base de données).
Aucun ne doit finir dans un fichier texte, un message ou le dépôt Git.

1. Installe un gestionnaire de mots de passe (Bitwarden est gratuit et multiplateforme).
2. Crée un dossier « ITSM » pour y ranger tous les secrets du projet.
3. Active l'authentification à deux facteurs partout où c'est proposé.

**Pourquoi** : le dépôt sera public. Une fuite de secret est l'incident de sécurité le plus
courant sur les projets personnels, et un recruteur le remarque immédiatement.

---

## 1. Compte Oracle Cloud

### 1.1 Inscription

1. Va sur la page de l'offre gratuite d'Oracle Cloud et clique sur « Start for free ».
2. Type de compte : **Individual**.
3. **Cloud Account Name** : c'est le nom de ta *tenancy*. Il est définitif et apparaît dans
   les URL de connexion. Choisis quelque chose de sobre, par exemple `itsmnordal`.
4. **Home Region** : **France Central (Paris)** ou **France South (Marseille)**.
   > Ce choix est **définitif**. Les ressources Always Free (VM et base) ne peuvent être
   > créées que dans cette région.
5. Vérification de carte bancaire : Oracle fait une autorisation temporaire, sans débit.
   Les cartes prépayées ou virtuelles sont souvent refusées.
6. Tu obtiens un compte *Free Tier* : ressources Always Free à vie, plus un crédit d'essai
   de 30 jours.

### 1.2 Sécuriser le compte

1. Active l'**authentification multifacteur (MFA)** sur ton utilisateur (Profil, puis
   Security). Ton compte cloud est la clé de toute ton infrastructure.
2. Range le mot de passe et les codes de secours dans le gestionnaire de mots de passe.

### 1.3 Créer un compartiment `itsm`

Identity & Security, puis Compartments, puis Create Compartment : nom `itsm`, description
« Ressources du projet ITSM ».

**Pourquoi** : un compartiment isole les ressources d'un projet. Il sert à appliquer des
droits limités (moindre privilège) et, en I6, Terraform ciblera ce compartiment. En entreprise,
on ne crée jamais rien à la racine d'une tenancy.

### 1.4 Créer une alerte de budget

Billing & Cost Management, puis Budgets, puis Create Budget :
- cible : la tenancy entière ;
- montant mensuel : **1** (dans ta devise) ;
- alerte : coût **réel** supérieur à 100 % du budget, envoyée à ton e-mail.

**Pourquoi** : si une ressource payante est créée par erreur pendant l'essai, tu es prévenu
immédiatement au lieu de le découvrir sur un relevé.

### 1.5 Ce qu'il ne faut PAS faire maintenant

- **Ne passe pas le compte en « Pay As You Go »**. Cela supprime certaines restrictions,
  mais une erreur de configuration devient alors facturable.
- **Ne crée pas encore la VM ni la base de données.** Oracle arrête les VM Always Free jugées
  inactives : sur 7 jours, une VM Ampere A1 est considérée inactive si l'utilisation du
  processeur (95e percentile), du réseau **et** de la mémoire restent toutes sous 20 %.
  Une VM vide serait donc arrêtée. Notre application, avec Keycloak et le backend,
  dépassera largement 20 % de mémoire : la VM sera créée en I0, au moment de déployer.
- Pendant l'essai de 30 jours, vérifie toujours la mention **« Always Free-eligible »**
  avant de créer une ressource.

> Si, en I0, la création de la VM échoue avec « Out of host capacity », ce n'est pas une
> erreur de ta part : il n'y a temporairement plus de machines ARM gratuites dans la région.
> On réessaie à un autre moment de la journée.

---

## 2. Poste de travail

Suis l'**annexe A du cahier des charges technique**. Points d'attention :

### Sous Windows

- Tout se passe dans **WSL 2 (Ubuntu)** : le code, Git, Java, Node. Le dépôt doit être dans
  `~/` (système de fichiers Linux), jamais dans `/mnt/c/...` : les performances sont
  divisées par dix sinon.
- Docker Desktop avec le moteur WSL 2.
- Limite la mémoire de WSL dans `C:\Users\<toi>\.wslconfig` :

  ```ini
  [wsl2]
  memory=10GB
  swap=4GB
  ```

  puis `wsl --shutdown` dans PowerShell pour appliquer.

### Sous macOS

- Docker Desktop : Settings, puis Resources, mémoire à **8 à 10 Go**.

### Outils supplémentaires à installer maintenant

| Outil | Pourquoi maintenant | Installation |
|---|---|---|
| GitHub CLI (`gh`) | Le script de création du dépôt l'utilise | https://cli.github.com |
| Gitleaks | Le hook Git bloque les commits contenant un secret | https://github.com/gitleaks/gitleaks (Homebrew, ou binaire des releases) |

#### Installer Gitleaks sous Ubuntu (ou WSL)

N'utilise pas `apt install gitleaks` : la version d'Ubuntu est souvent trop ancienne et ne
connaît pas la commande `gitleaks git` utilisée par le hook (il faut la version 8.19 ou plus).
Installe le binaire officiel :

```bash
VERSION=8.30.1          # dernière version : https://github.com/gitleaks/gitleaks/releases
ARCH=x64                # "arm64" sur une machine ARM (uname -m affiche aarch64)
cd /tmp
curl -sSLO "https://github.com/gitleaks/gitleaks/releases/download/v${VERSION}/gitleaks_${VERSION}_linux_${ARCH}.tar.gz"
curl -sSLO "https://github.com/gitleaks/gitleaks/releases/download/v${VERSION}/gitleaks_${VERSION}_checksums.txt"
sha256sum --check --ignore-missing "gitleaks_${VERSION}_checksums.txt"
tar -xzf "gitleaks_${VERSION}_linux_${ARCH}.tar.gz" gitleaks
sudo install -m 755 gitleaks /usr/local/bin/gitleaks
rm -f gitleaks "gitleaks_${VERSION}"_*
gitleaks version
```

### Anticiper le téléchargement le plus long

L'image Oracle fait plusieurs gigaoctets. Lance son téléchargement dès maintenant :

```bash
docker pull gvenzl/oracle-free:slim-faststart
```

### Vérifier

Depuis la racine du kit :

```bash
./scripts/check-workstation.sh
```

Objectif : zéro ligne `[MANQUE]`. Les lignes `[ATTENTION]` sont à lire, pas forcément à corriger.

---

## 3. Dépôt GitHub

### 3.1 Compte

- Active l'authentification à deux facteurs (obligatoire pour contribuer sur GitHub).
- Choisis un nom d'utilisateur professionnel : il apparaîtra dans l'URL du projet sur ton CV.

### 3.2 Création automatisée

Depuis la racine du kit décompressé :

```bash
gh auth login                  # choisir GitHub.com, SSH, envoyer ta clé publique
gh auth refresh -s project     # droit supplémentaire pour créer le tableau Kanban
./scripts/bootstrap-github.sh itsm
./scripts/install-git-hooks.sh
```

Le script `bootstrap-github.sh` fait, dans l'ordre :

| Action | Pourquoi |
|---|---|
| Crée le dépôt public `itsm` et pousse le premier commit | Vitrine pour les recruteurs ; outils gratuits pour les dépôts publics |
| Fusion par **squash** uniquement, suppression des branches fusionnées | Un commit propre par Pull Request dans l'historique de `main` |
| Active les alertes Dependabot, les correctifs automatiques, la détection de secrets et son blocage au push | Sécurité de la chaîne d'approvisionnement dès le premier jour |
| Crée les labels `type:*` et `area:*` | Filtrer le tableau et les statistiques |
| Crée les jalons I0 à I8 | Chaque issue est rattachée à un incrément |
| Protège `main` par un *ruleset* | Voir ci-dessous |
| Crée le projet « ITSM » et le lie au dépôt | Le tableau Kanban |

La protection de `main` impose :
- aucune modification directe : tout passe par une Pull Request ;
- **zéro approbation requise** : GitHub ne permet pas d'approuver sa propre Pull Request.
  La discipline vient de la checklist du modèle de PR et, en I0, des vérifications
  automatiques du pipeline, qui deviendront obligatoires ;
- historique linéaire, pas de *force push*, pas de suppression de la branche ;
- toutes les conversations de revue doivent être résolues avant la fusion.

### 3.3 Réglages manuels du tableau Kanban

Deux choses ne s'automatisent pas proprement avec `gh` :

1. **Colonnes** : dans le projet, vue *Board*, champ *Status* : ajoute l'option
   **En revue** entre *In Progress* et *Done*. Renomme les options en français si tu veux :
   À faire, En cours, En revue, Terminé.
2. **Automatisations** (menu *Workflows* du projet) : active
   - *Item added to project* : statut « À faire » ;
   - *Pull request merged* : statut « Terminé » ;
   - *Auto-add to project* avec le filtre `repo:<ton-login>/itsm`.

### 3.4 Vérifier que la protection fonctionne

C'est ton premier test. Essaie de contourner la règle :

```bash
echo "test" >> README.md
git commit -am "test: direct push"
git push origin main
```

Le push **doit être refusé**. Annule ensuite ton commit local :

```bash
git reset --hard origin/main
```

Puis refais la même modification proprement : branche, Pull Request, fusion par squash.
C'est exactement le cycle que tu suivras pour tout le projet.

### 3.5 Vérifier que le hook anti-secret fonctionne

```bash
git switch -c test/gitleaks
echo 'aws_secret_access_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"' > leak.txt
git add leak.txt && git commit -m "test: leak"
```

Le commit **doit être refusé**. Nettoie :

```bash
git reset && rm leak.txt && git switch main && git branch -D test/gitleaks
```

---

## 4. SonarQube Cloud

1. Va sur sonarcloud.io et connecte-toi **avec GitHub**.
2. *Import an organization* : choisis ton compte personnel. Lors de l'installation de
   l'application GitHub, donne-lui accès **uniquement au dépôt `itsm`** (moindre privilège).
3. Plan : **Free** (gratuit pour les projets publics).
4. *Analyze new project* : sélectionne `itsm`.
5. Note la **clé d'organisation** et la **clé de projet** (souvent `<login>_itsm`) : elles
   serviront en I0.

**À savoir** : SonarQube Cloud lance d'abord une « analyse automatique ». En I0, on la
désactivera au profit d'une analyse depuis le pipeline, seule capable d'intégrer la
couverture de tests mesurée par JaCoCo. Le jeton d'accès sera créé à ce moment-là.

---

## 5. DuckDNS

1. Va sur duckdns.org et connecte-toi (avec ton compte GitHub, par exemple).
2. Choisis un sous-domaine, par exemple `itsm-<pseudo>` : l'application sera accessible sur
   `https://itsm-<pseudo>.duckdns.org`.
3. Laisse l'adresse IP proposée pour l'instant. Elle sera remplacée en I0 par l'adresse
   publique de la VM.
4. Le **token** affiché en haut de la page est un secret : il permet de modifier ton domaine.
   Range-le dans le gestionnaire de mots de passe, jamais dans le dépôt.

**Pourquoi DuckDNS** : Let's Encrypt ne délivre pas de certificat HTTPS pour une simple
adresse IP. Il faut un nom de domaine, et DuckDNS en fournit un gratuitement.

---

## Inventaire des secrets

| Secret | Créé à l'étape | Rangé dans | Utilisé plus tard par |
|---|---|---|---|
| Mot de passe et MFA Oracle Cloud | 1 | Gestionnaire de mots de passe | Toi uniquement |
| Mot de passe et 2FA GitHub | 3 | Gestionnaire de mots de passe | Toi uniquement |
| Token DuckDNS | 5 | Gestionnaire de mots de passe | Secret GitHub Actions (I0) |
| Jeton SonarQube Cloud | I0 | Gestionnaire de mots de passe | Secret GitHub Actions `SONAR_TOKEN` (I0) |

---

## Checklist de fin

- [ ] Gestionnaire de mots de passe installé, 2FA activée partout
- [ ] Compte Oracle Cloud créé, région Paris ou Marseille, MFA activée
- [ ] Compartiment `itsm` créé
- [ ] Alerte de budget à 1 créée
- [ ] `check-workstation.sh` sans `[MANQUE]`
- [ ] Image Oracle Free téléchargée
- [ ] Dépôt `itsm` public créé et configuré par le script
- [ ] Colonnes et automatisations du tableau Kanban réglées
- [ ] Push direct sur `main` refusé (test 3.4)
- [ ] Commit contenant un secret refusé (test 3.5)
- [ ] Organisation et projet SonarQube Cloud créés, clés notées
- [ ] Sous-domaine DuckDNS réservé, token rangé
