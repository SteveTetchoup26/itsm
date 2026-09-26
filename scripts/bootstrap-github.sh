#!/usr/bin/env bash
# Cree et configure le depot GitHub du projet ITSM.
# Prerequis : gh installe, "gh auth login" fait, puis "gh auth refresh -s project".
# Usage (depuis la racine du kit) : ./scripts/bootstrap-github.sh [nom-du-depot]
# Le script est rejouable : il ignore ce qui existe deja.
set -euo pipefail

REPO="${1:-itsm}"
DESCRIPTION="Plateforme ITSM : gestion des incidents et demandes IT (Angular, Spring Boot, Oracle, Kafka, Kubernetes)"

step() { printf '\n==> %s\n' "$*"; }
warn() { printf '    [attention] %s\n' "$*"; }

command -v gh >/dev/null || { echo "gh n'est pas installe : https://cli.github.com"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Lance d'abord : gh auth login"; exit 1; }
OWNER="$(gh api user -q .login)"
FULL="$OWNER/$REPO"

step "Depot local"
if [ ! -d .git ]; then
  git init -b main
fi
if ! git rev-parse HEAD >/dev/null 2>&1; then
  git add .
  git commit -m "chore: initial project structure"
fi

step "Depot GitHub $FULL (public)"
if gh repo view "$FULL" >/dev/null 2>&1; then
  echo "    existe deja"
else
  gh repo create "$REPO" --public --description "$DESCRIPTION" --source=. --remote=origin --push
fi

step "Parametres de fusion : squash uniquement, suppression automatique des branches"
gh repo edit "$FULL" \
  --enable-squash-merge \
  --enable-merge-commit=false \
  --enable-rebase-merge=false \
  --delete-branch-on-merge \
  --enable-wiki=false \
  --enable-issues \
  --enable-projects
gh api -X PATCH "repos/$FULL" \
  -f squash_merge_commit_title=PR_TITLE \
  -f squash_merge_commit_message=PR_BODY >/dev/null

step "Securite : alertes Dependabot, correctifs automatiques, detection de secrets"
gh api -X PUT "repos/$FULL/vulnerability-alerts" >/dev/null
gh api -X PUT "repos/$FULL/automated-security-fixes" >/dev/null
gh api -X PUT "repos/$FULL/private-vulnerability-reporting" >/dev/null || warn "signalement prive non active"
gh api -X PATCH "repos/$FULL" --input - >/dev/null <<'JSON' || warn "detection de secrets : a verifier dans Settings > Code security"
{ "security_and_analysis": {
    "secret_scanning": { "status": "enabled" },
    "secret_scanning_push_protection": { "status": "enabled" } } }
JSON

step "Labels"
for l in bug documentation duplicate enhancement "good first issue" "help wanted" invalid question wontfix; do
  gh label delete "$l" --repo "$FULL" --yes >/dev/null 2>&1 || true
done
while IFS='|' read -r name color desc; do
  gh label create "$name" --repo "$FULL" --color "$color" --description "$desc" --force >/dev/null
done <<'LABELS'
type:story|1D76DB|User story du cahier fonctionnel
type:tech|5319E7|Tache technique
type:bug|D73A4A|Comportement incorrect
type:adr|FBCA04|Decision d'architecture
type:docs|0075CA|Documentation
area:backend|C5DEF5|Spring Boot
area:frontend|C5DEF5|Angular
area:database|C5DEF5|Oracle, Flyway
area:ci-cd|C5DEF5|Pipeline GitHub Actions
area:infra|C5DEF5|Docker, Kubernetes, Oracle Cloud
area:security|C5DEF5|Securite
area:observability|C5DEF5|Logs, metriques, traces
dependencies|0366D6|Mise a jour de dependances (Dependabot)
LABELS

step "Jalons I0 a I8"
existing="$(gh api "repos/$FULL/milestones?state=all&per_page=100" -q '.[].title')"
while IFS='|' read -r title desc; do
  if grep -qxF "$title" <<<"$existing"; then continue; fi
  gh api "repos/$FULL/milestones" -f title="$title" -f description="$desc" >/dev/null
done <<'MILESTONES'
I0 : walking skeleton|Pipeline, deploiement continu en HTTPS, page d'etat lue depuis Oracle
I1 : declarer et consulter|US-01 a US-03, Keycloak, conventions d'API
I2 : traiter|US-04 a US-08, US-10 a US-17, historique, pieces jointes
I3 : piloter et administrer|US-20 a US-23, US-30 a US-33, SLA, tableau de bord (fin du MVP)
I4 : evenements et notifications|US-40 a US-42, Kafka, outbox
I5 : observabilite|OpenTelemetry, SLO, alertes, runbooks
I6 : Kubernetes|k3s, Helm, Terraform
I7 : resilience et securite|Resilience4j, limitation de debit, OWASP ZAP
I8 : exploitation|Simulations d'incidents, post-mortems, documentation finale
MILESTONES

step "Protection de la branche main (ruleset)"
if gh api "repos/$FULL/rulesets" -q '.[].name' | grep -qx protect-main; then
  echo "    existe deja"
else
  gh api -X POST "repos/$FULL/rulesets" --input scripts/github-ruleset-main.json >/dev/null
fi

step "Tableau Kanban (GitHub Projects)"
PROJECT="$(gh project list --owner "$OWNER" --format json -q '.projects[] | select(.title=="ITSM") | .number' 2>/dev/null || true)"
if [ -z "$PROJECT" ]; then
  PROJECT="$(gh project create --owner "$OWNER" --title "ITSM" --format json -q .number)" \
    || { warn "creation impossible : lance 'gh auth refresh -s project' puis relance le script"; PROJECT=""; }
fi
if [ -n "$PROJECT" ]; then
  gh project link "$PROJECT" --owner "$OWNER" --repo "$FULL" >/dev/null 2>&1 || true
  echo "    projet n°$PROJECT : https://github.com/users/$OWNER/projects/$PROJECT"
fi

cat <<DONE

Termine. A faire a la main (non automatisable proprement) :
  1. Projet ITSM > vue Board ; champ Status : ajouter l'option "En revue"
     entre "In Progress" et "Done" (les renommer en francais si tu veux).
  2. Projet ITSM > Workflows : activer "Item added to project -> Todo",
     "Pull request merged -> Done" et "Auto-add to project" (filtre : repo:$FULL).
  3. Verifier Settings > Code security : Dependabot et Secret scanning actives.

Depot : https://github.com/$FULL
DONE
