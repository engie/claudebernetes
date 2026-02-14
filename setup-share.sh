#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

FLEET_DIR="./fleet"

echo "Setting up fleet share at $FLEET_DIR..."

# Create directory structure
mkdir -p "$FLEET_DIR/bin"
mkdir -p "$FLEET_DIR/auth"
mkdir -p "$FLEET_DIR/nodes"
mkdir -p "$FLEET_DIR/workloads"
mkdir -p "$FLEET_DIR/decisions"
mkdir -p "$FLEET_DIR/logs"

# Copy Claude binary
CLAUDE_SRC="$HOME/.local/share/claude/versions/2.1.39"
if [[ -d "$CLAUDE_SRC" ]]; then
  CLAUDE_BIN=$(find "$CLAUDE_SRC" -maxdepth 1 -type f -executable | head -1)
  if [[ -n "$CLAUDE_BIN" ]]; then
    cp "$CLAUDE_BIN" "$FLEET_DIR/bin/claude"
    chmod 755 "$FLEET_DIR/bin/claude"
    echo "Copied Claude binary from $CLAUDE_BIN"
  else
    echo "Warning: No executable found in $CLAUDE_SRC" >&2
    echo "You may need to manually copy the Claude binary to $FLEET_DIR/bin/claude" >&2
  fi
else
  echo "Warning: Claude version directory not found at $CLAUDE_SRC" >&2
  echo "You may need to manually copy the Claude binary to $FLEET_DIR/bin/claude" >&2
fi

# Copy credentials
CREDS_SRC="$HOME/.claude/.credentials.json"
if [[ -f "$CREDS_SRC" ]]; then
  cp "$CREDS_SRC" "$FLEET_DIR/auth/.credentials.json"
  chmod 600 "$FLEET_DIR/auth/.credentials.json"
  echo "Copied credentials"
else
  echo "Warning: $CREDS_SRC not found. Copy credentials manually." >&2
fi

# Write settings (dangerously-skip-permissions equivalent)
cat > "$FLEET_DIR/auth/settings.json" << EOF
{
  "model": "${CLAUDE_MODEL:-sonnet}",
  "permissions": {
    "allow": ["Bash(*)", "Read(*)", "Write(*)", "Edit(*)", "Glob(*)", "Grep(*)", "WebFetch(*)", "WebSearch(*)"],
    "deny": []
  }
}
EOF
chmod 644 "$FLEET_DIR/auth/settings.json"
echo "Wrote settings.json"

# Copy agent-wrapper.sh and irc-bot.sh (already created in fleet/bin/)
chmod 755 "$FLEET_DIR/bin/agent-wrapper.sh"
chmod 755 "$FLEET_DIR/bin/irc-bot.sh"
chmod 755 "$FLEET_DIR/bin/irc-logger.sh"
echo "Set script permissions"

echo ""
echo "Fleet share setup complete at $FLEET_DIR/"
echo "Directory structure:"
find "$FLEET_DIR" -type f | sort | sed 's|^|  |'
