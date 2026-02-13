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

hcloud server list --selector role=claudebernetes -o columns=name,ipv4,status
