#!/bin/bash
set -uo pipefail

# Centralized IRC channel logger
# Connects to InspIRCd and appends all channel activity to a shared log file.
# Runs on the IRC server host (tailstuff), not on fleet nodes.

IRC_SERVER="${IRC_SERVER:-127.0.0.1}"
IRC_PORT="${IRC_PORT:-6667}"
IRC_PASSWORD="${IRC_PASSWORD:-}"
IRC_CHANNEL="#fleet"
NICK="logger"
LOG_DIR="${LOG_DIR:?LOG_DIR not set}"
LOG_FILE="$LOG_DIR/channel.log"

mkdir -p "$LOG_DIR"

log_event() {
  echo "[$(date -Iseconds)] $*" >> "$LOG_FILE"
}

connect() {
  exec 3<>/dev/tcp/"$IRC_SERVER"/"$IRC_PORT"

  if [[ -n "$IRC_PASSWORD" ]]; then
    echo "PASS $IRC_PASSWORD" >&3
  fi

  echo "NICK $NICK" >&3
  echo "USER $NICK 0 * :Claudebernetes channel logger" >&3

  while IFS= read -r -t 300 line <&3; do
    line="${line%%$'\r'}"
    echo "<<< $line" >&2

    if [[ "$line" == PING* ]]; then
      local token="${line#PING }"
      echo "PONG $token" >&3
    fi

    if [[ "$line" == *" 001 "* ]]; then
      break
    fi

    if [[ "$line" == *" 433 "* ]]; then
      NICK="${NICK}-$$"
      echo "NICK $NICK" >&3
      echo "Nick collision, retrying as $NICK" >&2
    fi
  done

  echo "JOIN $IRC_CHANNEL" >&3
  echo "Joined $IRC_CHANNEL as $NICK" >&2
}

while true; do
  echo "Connecting to $IRC_SERVER:$IRC_PORT..." >&2
  connect

  while IFS= read -r -t 300 line <&3; do
    line="${line%%$'\r'}"

    if [[ "$line" == PING* ]]; then
      token="${line#PING }"
      echo "PONG $token" >&3
      continue
    fi

    # Channel messages: :sender!user@host PRIVMSG #channel :message
    if [[ "$line" == *"PRIVMSG $IRC_CHANNEL"* ]]; then
      sender="${line%%!*}"
      sender="${sender#:}"
      msg="${line#*PRIVMSG $IRC_CHANNEL :}"
      log_event "<$sender> $msg"

    # JOIN: :sender!user@host JOIN #channel
    elif [[ "$line" == *"JOIN"*"$IRC_CHANNEL"* ]]; then
      sender="${line%%!*}"
      sender="${sender#:}"
      log_event "*** $sender joined $IRC_CHANNEL"

    # PART: :sender!user@host PART #channel :reason
    elif [[ "$line" == *"PART"*"$IRC_CHANNEL"* ]]; then
      sender="${line%%!*}"
      sender="${sender#:}"
      log_event "*** $sender left $IRC_CHANNEL"

    # QUIT: :sender!user@host QUIT :reason
    elif [[ "$line" == *" QUIT "* ]]; then
      sender="${line%%!*}"
      sender="${sender#:}"
      reason="${line#*QUIT :}"
      log_event "*** $sender quit ($reason)"
    fi
  done

  echo "Disconnected. Reconnecting in 10s..." >&2
  exec 3>&- 2>/dev/null || true
  sleep 10
done
