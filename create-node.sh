#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

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

# Generate a whimsical name or use the provided one
if [[ -n "${1:-}" ]]; then
  NAME="$1"
else
  NAME=$(claude -p "Generate a single whimsical forest creature name for a server hostname. Lowercase, hyphenated, two words. Just the name, nothing else.")
  NAME=$(echo "$NAME" | tr -d '[:space:]')
  echo "Generated name: $NAME"
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

DATACENTER="hel1-dc2"
TYPE="cax11"

hcloud server create \
    --name "$NAME" \
    --type "$TYPE" \
    --datacenter "$DATACENTER" \
    --image "$IMAGE_ID" \
    --label role=claudebernetes \
    --user-data-from-file claudebernetes.ign

IP=$(hcloud server ip "$NAME")
echo "Created server $NAME ($IP)"
