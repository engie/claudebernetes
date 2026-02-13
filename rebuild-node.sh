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

if [[ ! -f claudebernetes.ign ]]; then
  echo "Error: claudebernetes.ign not found. Run ./build.sh first." >&2
  exit 1
fi

# Find the FCOS snapshot
IMAGE_ID="$(hcloud image list \
    --type=snapshot \
    --selector=os=fedora-coreos \
    --output json \
    | jq -r '.[0].id')"

if [[ -z "$IMAGE_ID" || "$IMAGE_ID" == "null" ]]; then
  echo "Error: No Fedora CoreOS snapshot found with label os=fedora-coreos" >&2
  exit 1
fi

hcloud server rebuild \
    --image "$IMAGE_ID" \
    --user-data-from-file claudebernetes.ign \
    "$NAME"

echo "Rebuilt server $NAME with fresh ignition config"
