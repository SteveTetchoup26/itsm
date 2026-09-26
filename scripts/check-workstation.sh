#!/usr/bin/env bash
# Verifie que le poste de travail est pret pour le projet ITSM.
# Usage : ./scripts/check-workstation.sh
set -uo pipefail

ok=0; ko=0; wn=0
pass() { printf '  [OK]        %-18s %s\n' "$1" "$2"; ok=$((ok+1)); }
fail() { printf '  [MANQUE]    %-18s %s\n' "$1" "$2"; ko=$((ko+1)); }
warn() { printf '  [ATTENTION] %-18s %s\n' "$1" "$2"; wn=$((wn+1)); }
have() { command -v "$1" >/dev/null 2>&1; }

echo "Poste de travail"
case "$(uname -s)" in
  Linux)
    if grep -qi microsoft /proc/version 2>/dev/null; then
      if [[ "$PWD" == /mnt/* ]]; then
        warn "WSL" "le projet est sur le disque Windows ($PWD) : deplace-le dans ~ pour de bonnes performances"
      else
        pass "WSL" "WSL 2, projet dans le systeme de fichiers Linux"
      fi
    else
      pass "Systeme" "Linux"
    fi ;;
  Darwin) pass "Systeme" "macOS $(sw_vers -productVersion 2>/dev/null)" ;;
  *) warn "Systeme" "$(uname -s) : travaille dans WSL 2 sous Windows" ;;
esac

echo; echo "Outils de base"
have git && pass "git" "$(git --version | awk '{print $3}')" || fail "git" "https://git-scm.com"
if have git; then
  [ -n "$(git config --global user.email)" ] && pass "git identite" "$(git config --global user.name) <$(git config --global user.email)>" \
    || fail "git identite" "git config --global user.name / user.email"
fi
ls ~/.ssh/id_ed25519.pub >/dev/null 2>&1 && pass "cle SSH" "~/.ssh/id_ed25519.pub" || warn "cle SSH" "ssh-keygen -t ed25519 -C \"ton@email\""
have gh && pass "gh" "$(gh --version | head -1 | awk '{print $3}')" || fail "gh" "https://cli.github.com"
have gitleaks && pass "gitleaks" "$(gitleaks version 2>/dev/null)" || fail "gitleaks" "https://github.com/gitleaks/gitleaks"

echo; echo "Conteneurs"
if have docker; then
  if docker info >/dev/null 2>&1; then
    pass "docker" "$(docker version --format '{{.Server.Version}}')"
    mem=$(( $(docker info --format '{{.MemTotal}}') / 1024 / 1024 / 1024 ))
    if   [ "$mem" -lt 6 ];  then warn "memoire Docker" "${mem} Go : trop peu pour Oracle + Keycloak (vise 8 a 10 Go)"
    elif [ "$mem" -gt 11 ] && [ "$(uname -s)" = Linux ] && ! grep -qi microsoft /proc/version 2>/dev/null; then
      pass "memoire Docker" "${mem} Go (Linux natif : memoire partagee, limites posees par conteneur)"
    elif [ "$mem" -gt 11 ]; then warn "memoire Docker" "${mem} Go : laisse de la place a l'IDE et au navigateur (vise 8 a 10 Go)"
    else pass "memoire Docker" "${mem} Go"; fi
  else
    fail "docker" "installe mais le demon ne repond pas (Docker Desktop lance ?)"
  fi
  docker compose version >/dev/null 2>&1 && pass "docker compose" "$(docker compose version --short)" || fail "docker compose" "plugin compose v2 requis"
  docker buildx version >/dev/null 2>&1 && pass "docker buildx" "multi-architecture disponible" || warn "docker buildx" "necessaire pour construire les images ARM64"
else
  fail "docker" "https://docs.docker.com/get-docker/"
fi

echo; echo "Backend"
if have java; then
  jline=$(java -version 2>&1 | grep -m1 ' version ')
  jv=$(sed -E 's/.*version "([0-9]+).*/\1/' <<<"$jline")
  [ "$jv" -ge 25 ] 2>/dev/null && pass "java" "$jline" || fail "java" "version ${jv:-inconnue} trouvee, 25 requise (sdk list java, puis sdk install java 25.0.x-tem)"
else
  fail "java" "sdk list java, puis sdk install java 25.0.x-tem"
fi
[ -d "$HOME/.sdkman" ] && pass "sdkman" "installe" || warn "sdkman" "recommande : https://sdkman.io"
have sql && pass "sqlcl" "installe" || warn "sqlcl" "client Oracle en ligne de commande (sdk install sqlcl)"

echo; echo "Frontend"
if have node; then
  nv=$(node -v | sed 's/v//; s/\..*//')
  if [ $((nv % 2)) -eq 0 ]; then pass "node" "$(node -v)"; else warn "node" "$(node -v) n'est pas une version LTS (nvm install --lts)"; fi
else
  fail "node" "nvm install --lts"
fi
have ng && pass "angular cli" "installe" || fail "angular cli" "npm install -g @angular/cli"

echo; echo "Bilan : $ok OK, $wn a verifier, $ko manquant(s)"
[ "$ko" -eq 0 ]
