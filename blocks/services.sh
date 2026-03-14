#!/bin/bash
# Block: Services — Quick port check for key services
# Shows: sop:18895 ✓ | tooltune:8100 ✓  (or ✗ if down)
CACHE_DIR="/tmp/claude-statusline"
mkdir -p "$CACHE_DIR"
SVC_CACHE="$CACHE_DIR/services"
SVC_AGE=999
[ -f "$SVC_CACHE" ] && SVC_AGE=$(( $(date +%s) - $(stat -c %Y "$SVC_CACHE" 2>/dev/null || echo 0) ))

if [ "$SVC_AGE" -gt 120 ]; then
  (
    DOWN=""
    for pair in "sop:18895" "tooltune:8100" "ollama:11434"; do
      NAME="${pair%%:*}"; PORT="${pair##*:}"
      if ! ss -tlnp 2>/dev/null | grep -q ":${PORT} "; then
        DOWN="${DOWN:+$DOWN }${NAME}"
      fi
    done
    if [ -n "$DOWN" ]; then
      echo "$DOWN" > "$SVC_CACHE"
    else
      echo "" > "$SVC_CACHE"
    fi
  ) &
fi

DOWN=$(cat "$SVC_CACHE" 2>/dev/null)
[ -z "$DOWN" ] && exit 0
echo -e "\033[31m⚠ down: $DOWN\033[0m"
