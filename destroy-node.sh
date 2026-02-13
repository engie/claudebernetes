#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [[ -z "${1:-}" ]]; then
  echo "Usage: $0 <node-name>" >&2
  exit 1
fi

NAME="$1"

if [[ ! -f site.env ]]; then
  echo "Error: site.env not found." >&2
  exit 1
fi

set -a
source site.env
set +a

export HCLOUD_TOKEN

echo "This will destroy server '$NAME'."
read -p "Are you sure? [y/N] " confirm
if [[ "$confirm" != [yY] ]]; then
  echo "Aborted."
  exit 0
fi

hcloud server delete "$NAME"
echo "Destroyed server $NAME"

# Optionally clean up the node's directory on the share
if [[ -d "fleet/nodes/$NAME" ]]; then
  read -p "Remove fleet/nodes/$NAME from the share? [y/N] " cleanup
  if [[ "$cleanup" == [yY] ]]; then
    rm -rf "fleet/nodes/$NAME"
    echo "Cleaned up fleet/nodes/$NAME"
  fi
fi
