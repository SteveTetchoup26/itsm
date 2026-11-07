#!/usr/bin/env bash
# Runs on the VM, as the deploy user, from /opt/itsm (called by the CI deployment job over SSH).
#   deploy.sh sha-1a2b3c4   deploys this version; rolls back by itself if it does not become healthy
#   deploy.sh --rollback     goes back to the previous version (used when the smoke tests fail)
# State: .env.tag holds the version running now, .env.tag.previous the one before.
set -euo pipefail
cd "$(dirname "$0")"

compose() { docker compose -f compose.prod.yml --env-file .env.prod --env-file .env.tag "$@"; }
log() { echo "[deploy] $*"; }

start() { # starts the version in .env.tag and waits until every container is healthy
  compose up -d --remove-orphans --wait --wait-timeout 180
}

rollback() {
  if [ ! -f .env.tag.previous ]; then
    log "No previous version to go back to"
    return 1
  fi
  mv .env.tag.previous .env.tag
  log "Rolling back to $(cut -d= -f2 .env.tag)"
  start
}

if [ "${1:-}" = "--rollback" ]; then
  rollback || { log "Rollback failed: stopping the backend"; compose stop backend; exit 1; }
  exit 0
fi

tag="${1:?usage: deploy.sh <image tag> | --rollback}"
[[ "$tag" =~ ^sha-[0-9a-f]{7,40}$ ]] || { log "Invalid tag: $tag"; exit 1; }

# Download first: if the images cannot be pulled, nothing has changed on the VM.
ITSM_TAG="$tag" docker compose -f compose.prod.yml --env-file .env.prod pull --quiet

[ -f .env.tag ] && cp .env.tag .env.tag.previous
echo "ITSM_TAG=$tag" > .env.tag
log "Deploying $tag"
if ! start; then
  log "$tag did not become healthy"
  compose ps
  if ! rollback; then
    # Neither version starts: most often a wrong database setting. Stop the backend rather than
    # let it restart in a loop: every restart is a failed login, and the account gets locked.
    log "Rollback failed too: stopping the backend"
    compose stop backend
  fi
  exit 1
fi
log "$tag is running and healthy"

# Unused images older than a week: keeps recent versions on disk for a fast rollback.
docker image prune --all --force --filter "until=168h" > /dev/null
