#!/usr/bin/env bash
# Active les hooks Git versionnes dans .githooks/ (a lancer une fois apres le clone).
set -euo pipefail
git config core.hooksPath .githooks
chmod +x .githooks/*
echo "Hooks actives : un commit contenant un secret sera refuse."
