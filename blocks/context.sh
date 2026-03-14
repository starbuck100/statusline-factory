#!/bin/bash
# Block: Context — Only shows when window is getting full (>50%)
# Shows: ctx:72% (yellow) or ctx:85% (red)
CONTEXT_PCT="$1"
[ "$CONTEXT_PCT" = "?" ] && exit 0
[ "$CONTEXT_PCT" -le 50 ] 2>/dev/null && exit 0

if [ "$CONTEXT_PCT" -gt 80 ]; then
  echo -e "\033[31mctx:${CONTEXT_PCT}%\033[0m"
else
  echo -e "\033[33mctx:${CONTEXT_PCT}%\033[0m"
fi
