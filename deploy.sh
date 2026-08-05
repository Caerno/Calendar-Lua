#!/usr/bin/env bash
# Push repo files to ru.wikipedia.
#
# Usage:
#   ./deploy.sh [-m] "edit summary" [file ...]
#
#   -m    mark the edits as minor
#
# Without files, every changed push-allowed file is deployed.
# Note: run locally — GitHub-hosted runners are IP-blocked by Wikimedia.
set -euo pipefail
cd "$(dirname "$0")"

minor=""
if [ "${1:-}" = "-m" ]; then
    minor="--minor"
    shift
fi
summary="${1:?usage: ./deploy.sh [-m] \"edit summary\" [file ...]}"
shift || true

if [ $# -eq 0 ]; then
    python3 sync.py push all -m "$summary" $minor
else
    for f in "$@"; do
        python3 sync.py push "$f" -m "$summary" $minor
    done
fi
