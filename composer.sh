#!/bin/bash
# Claude Code Status Line — Modular Block Composer
# Blocks live in ~/.claude/statusline-blocks/*.sh
# Each block outputs one line (or nothing if irrelevant)
# Active blocks are listed in ~/.claude/statusline-active.conf (one per line)
# If no conf exists, auto-detect which blocks are relevant

BLOCKS_DIR="$HOME/.claude/statusline-blocks"
ACTIVE_CONF="$HOME/.claude/statusline-active.conf"

# Parse session data
SESSION_DATA=$(cat)
CONTEXT_PCT=$(echo "$SESSION_DATA" | python3 -c "import json,sys; d=json.load(sys.stdin); print(int(d.get('context_window',{}).get('used_percentage',0)))" 2>/dev/null || echo "?")

# Determine which blocks to run
if [ -f "$ACTIVE_CONF" ]; then
  BLOCKS=$(grep -v '^#' "$ACTIVE_CONF" | grep -v '^$')
else
  # Auto-detect: run all blocks, they self-suppress if irrelevant
  BLOCKS=$(ls "$BLOCKS_DIR"/*.sh 2>/dev/null | xargs -I{} basename {} .sh)
fi

# Run blocks, collect output
PARTS=""
for BLOCK in $BLOCKS; do
  SCRIPT="$BLOCKS_DIR/${BLOCK}.sh"
  [ ! -x "$SCRIPT" ] && chmod +x "$SCRIPT" 2>/dev/null
  [ ! -f "$SCRIPT" ] && continue

  if [ "$BLOCK" = "context" ]; then
    OUT=$(bash "$SCRIPT" "$CONTEXT_PCT" 2>/dev/null)
  else
    OUT=$(bash "$SCRIPT" 2>/dev/null)
  fi

  [ -n "$OUT" ] && PARTS="${PARTS:+$PARTS  }$OUT"
done

echo -e "$PARTS"
