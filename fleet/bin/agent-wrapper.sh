#!/bin/bash
set -uo pipefail

HOSTNAME=$(hostname)
NODE_DIR="/var/mnt/fleet/nodes/$HOSTNAME"

while true; do
  # Update heartbeat
  echo "{\"status\":\"starting\",\"ts\":\"$(date -Iseconds)\"}" > "$NODE_DIR/heartbeat.json"

  # Run one Claude session
  # Permissions are configured via settings.json in $HOME/.claude/
  /var/mnt/fleet/bin/claude \
    -p "You are Claudebernetes node $HOSTNAME. Read CLAUDE.md for your instructions. This is a new session — check IRC and cluster state, then act." \
    2>> "$NODE_DIR/claude-stderr.log"

  echo "{\"status\":\"restarting\",\"ts\":\"$(date -Iseconds)\"}" > "$NODE_DIR/heartbeat.json"
  sleep 30
done
