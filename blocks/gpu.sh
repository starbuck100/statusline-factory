#!/bin/bash
# Block: GPU — Local VRAM usage + loaded model
# Shows: 🎮 3090 8.2/24G qwen3.5:27b
CACHE_DIR="/tmp/claude-statusline"
mkdir -p "$CACHE_DIR"
CACHE="$CACHE_DIR/gpu"
AGE=999
[ -f "$CACHE" ] && AGE=$(( $(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null || echo 0) ))

if [ "$AGE" -gt 30 ]; then
  (
    # Check if nvidia-smi exists
    if ! command -v nvidia-smi &>/dev/null; then echo "" > "$CACHE"; exit 0; fi

    VRAM_USED=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')
    VRAM_TOTAL=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')

    [ -z "$VRAM_USED" ] && { echo "" > "$CACHE"; exit 0; }

    USED_GB=$(echo "scale=1; $VRAM_USED / 1024" | bc 2>/dev/null)
    TOTAL_GB=$(echo "scale=0; $VRAM_TOTAL / 1024" | bc 2>/dev/null)

    # Check ollama for loaded model
    MODEL=$(curl -s --max-time 2 http://127.0.0.1:11434/api/ps 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    models=d.get('models',[])
    if models: print(models[0].get('model','').split(':')[0])
    else: print('')
except: print('')
" 2>/dev/null)

    # Only show if VRAM actually in use (>1GB)
    if [ "$(echo "$VRAM_USED > 1024" | bc 2>/dev/null)" = "1" ]; then
      if [ -n "$MODEL" ]; then
        echo "${USED_GB}/${TOTAL_GB}G $MODEL" > "$CACHE"
      else
        echo "${USED_GB}/${TOTAL_GB}G" > "$CACHE"
      fi
    else
      echo "" > "$CACHE"
    fi
  ) &
fi

VALUE=$(cat "$CACHE" 2>/dev/null)
[ -z "$VALUE" ] && exit 0
echo -e "\033[36m🎮 $VALUE\033[0m"
