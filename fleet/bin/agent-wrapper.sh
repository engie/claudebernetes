#!/bin/bash
set -uo pipefail

HOSTNAME=$(hostname)
NODE_DIR="/var/mnt/fleet/nodes/$HOSTNAME"

while true; do
  echo "{\"status\":\"starting\",\"ts\":\"$(date -Iseconds)\"}" > "$NODE_DIR/heartbeat.json"

  # Run a long-lived Claude session.
  # Claude is responsible for its own event loop — polling IRC,
  # updating heartbeats, sleeping between checks. Sessions should
  # run indefinitely until context pressure forces an exit.
  /var/mnt/fleet/bin/claude \
    -p "You are Claudebernetes node $HOSTNAME. Read CLAUDE.md for your full instructions, then enter your event loop." \
    --max-turns 200 \
    2>> "$NODE_DIR/claude-stderr.log"

  echo "{\"status\":\"restarting\",\"ts\":\"$(date -Iseconds)\"}" > "$NODE_DIR/heartbeat.json"

  # Brief pause before restarting — session exited due to context
  # limits or an error, not because the loop design wants it to.
  sleep 5
done
