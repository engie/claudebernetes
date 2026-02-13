#!/bin/bash
set -uo pipefail

IRC_SERVER="${IRC_SERVER:?IRC_SERVER not set}"
IRC_PORT="${IRC_PORT:-6667}"
IRC_PASSWORD="${IRC_PASSWORD:-}"
IRC_CHANNEL="#fleet"
NICK=$(hostname)
NODE_DIR="/mnt/fleet/nodes/$NICK"
LOG_FILE="$NODE_DIR/irc.log"
PIPE_FILE="$NODE_DIR/irc.pipe"

log() {
  echo "[$(date -Iseconds)] $*" >> "$LOG_FILE"
}

connect() {
  # Open TCP connection to IRC server
  exec 3<>/dev/tcp/"$IRC_SERVER"/"$IRC_PORT"

  # Authenticate if password set
  if [[ -n "$IRC_PASSWORD" ]]; then
    echo "PASS $IRC_PASSWORD" >&3
  fi

  # Register
  echo "NICK $NICK" >&3
  echo "USER $NICK 0 * :Claudebernetes node $NICK" >&3

  # Wait for welcome (001) before joining
  while IFS= read -r -t 300 line <&3; do
    line="${line%%$'\r'}"
    log "<<< $line"

    # Handle PING during registration
    if [[ "$line" == PING* ]]; then
      local token="${line#PING }"
      echo "PONG $token" >&3
    fi

    # 001 = RPL_WELCOME
    if [[ "$line" == *" 001 "* ]]; then
      break
    fi

    # Handle errors
    if [[ "$line" == *" 433 "* ]]; then
      # Nick already in use — append PID
      NICK="${NICK}-$$"
      echo "NICK $NICK" >&3
      log "Nick collision, retrying as $NICK"
    fi
  done

  echo "JOIN $IRC_CHANNEL" >&3
  log "Joined $IRC_CHANNEL as $NICK"
}

send_message() {
  local msg="$1"
  echo "PRIVMSG $IRC_CHANNEL :$msg" >&3
  log ">>> $msg"
}

# Main loop with reconnection
while true; do
  log "Connecting to $IRC_SERVER:$IRC_PORT..."
  connect

  # Start background reader for the named pipe
  (
    while true; do
      if IFS= read -r msg < "$PIPE_FILE"; then
        if [[ -n "$msg" ]]; then
          echo "PRIVMSG $IRC_CHANNEL :$msg" >&3
          log ">>> $msg"
        fi
      fi
    done
  ) &
  PIPE_PID=$!

  # Read from IRC
  while IFS= read -r -t 300 line <&3; do
    line="${line%%$'\r'}"

    # Handle PING/PONG keepalive
    if [[ "$line" == PING* ]]; then
      token="${line#PING }"
      echo "PONG $token" >&3
      continue
    fi

    # Log channel messages
    if [[ "$line" == *"PRIVMSG $IRC_CHANNEL"* ]]; then
      # Extract sender and message
      sender="${line%%!*}"
      sender="${sender#:}"
      msg="${line#*PRIVMSG $IRC_CHANNEL :}"
      log "<$sender> $msg"
    else
      log "<<< $line"
    fi
  done

  # Connection lost — clean up and reconnect
  log "Disconnected. Reconnecting in 10s..."
  kill "$PIPE_PID" 2>/dev/null || true
  exec 3>&- 2>/dev/null || true
  sleep 10
done
