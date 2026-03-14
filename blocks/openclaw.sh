#!/bin/bash
# Block: OpenClaw — Gateway + ecap session status
# Shows: 🦞 up 2h | ecap: active 3m ago
CACHE_DIR="/tmp/claude-statusline"
mkdir -p "$CACHE_DIR"
OC_CACHE="$CACHE_DIR/openclaw"
OC_AGE=999
[ -f "$OC_CACHE" ] && OC_AGE=$(( $(date +%s) - $(stat -c %Y "$OC_CACHE" 2>/dev/null || echo 0) ))

if [ "$OC_AGE" -gt 45 ]; then
  (
    GW_PID=$(pgrep -f "openclaw.*gateway" 2>/dev/null | head -1)
    if [ -z "$GW_PID" ]; then
      echo "DOWN" > "$OC_CACHE"
    else
      # Gateway uptime
      UP_S=$(ps -o etimes= -p "$GW_PID" 2>/dev/null | tr -d ' ')
      if [ -n "$UP_S" ] && [ "$UP_S" -gt 0 ] 2>/dev/null; then
        H=$((UP_S / 3600)); M=$(( (UP_S % 3600) / 60))
        [ "$H" -gt 0 ] && T="${H}h${M}m" || T="${M}m"
      else
        T="?"
      fi
      # Last ecap activity
      SESSIONS="$HOME/.openclaw/agents/main/sessions/sessions.json"
      if [ -f "$SESSIONS" ]; then
        LAST=$(python3 -c "
import json
with open('$SESSIONS') as f: d=json.load(f)
tg = [v.get('updatedAt',0) for k,v in d.items() if 'telegram' in k and isinstance(v,dict)]
if tg:
    import time; ago=int(time.time()*1000)-max(tg); mins=ago//60000
    if mins<1: print('jetzt')
    elif mins<60: print(f'{mins}m')
    else: print(f'{mins//60}h')
else: print('idle')
" 2>/dev/null)
        echo "up ${T} | ecap: ${LAST} ago" > "$OC_CACHE"
      else
        echo "up ${T}" > "$OC_CACHE"
      fi
    fi
  ) &
fi

OC=$(cat "$OC_CACHE" 2>/dev/null)
[ -z "$OC" ] && exit 0
if [ "$OC" = "DOWN" ]; then
  echo -e "\033[31m🦞 DOWN\033[0m"
else
  echo -e "\033[33m🦞 $OC\033[0m"
fi
