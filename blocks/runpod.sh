#!/bin/bash
# Block: RunPod — Pod status + training ETA with clickable links and trend arrows
# Shows: 🚀 A100 12m $0.24 (pod-name↗) 🏋️ 35/625 (5%) ETA 1h34m loss↓1.23
CACHE_DIR="/tmp/claude-statusline"
mkdir -p "$CACHE_DIR"
export RUNPOD_API_KEY="$RUNPOD_API_KEY"

# --- Pod info (cached 60s) ---
POD_CACHE="$CACHE_DIR/runpod"
POD_LINK_CACHE="$CACHE_DIR/runpod_link"
POD_AGE=999
[ -f "$POD_CACHE" ] && POD_AGE=$(( $(date +%s) - $(stat -c %Y "$POD_CACHE" 2>/dev/null || echo 0) ))
if [ "$POD_AGE" -gt 60 ]; then
  (python3 -c "
import runpod, re
from datetime import datetime, timezone
pods = runpod.get_pods()
running = [p for p in pods if isinstance(p, dict) and p.get('desiredStatus') == 'RUNNING']
if not running: print('off'); exit()
parts = []
links = []
for pod in running:
    gpu = pod.get('machine',{}).get('gpuDisplayName','GPU').split()[0]
    cost_hr = pod.get('costPerHr', 0)
    name = pod.get('name','')
    pod_id = pod.get('id','')
    lsc = pod.get('lastStatusChange','')
    m = re.search(r'(\w+ \w+ \d+ \d+ [\d:]+)', lsc)
    if m:
        start = datetime.strptime(m.group(1), '%a %b %d %Y %H:%M:%S').replace(tzinfo=timezone.utc)
        uptime_s = max(0, int((datetime.now(timezone.utc) - start).total_seconds()))
    else: uptime_s = 0
    h, mn = uptime_s // 3600, (uptime_s % 3600) // 60
    spent = cost_hr * uptime_s / 3600
    t = f'{h}h{mn:02d}m' if h > 0 else f'{mn}m'
    parts.append(f'{gpu} {t} \${spent:.2f} ({name})')
    links.append(f'https://www.runpod.io/console/pods/{pod_id}')
print(' | '.join(parts))
# Write links to separate cache
with open('$CACHE_DIR/runpod_link', 'w') as f:
    f.write('\n'.join(links))
" 2>/dev/null > "$POD_CACHE") &
fi

POD=$(cat "$POD_CACHE" 2>/dev/null)
[ "$POD" = "off" ] || [ -z "$POD" ] && exit 0
POD_URL=$(head -1 "$POD_LINK_CACHE" 2>/dev/null)

# --- Training progress with loss trend (cached 30s) ---
TRAIN_CACHE="$CACHE_DIR/training"
TRAIN_AGE=999
[ -f "$TRAIN_CACHE" ] && TRAIN_AGE=$(( $(date +%s) - $(stat -c %Y "$TRAIN_CACHE" 2>/dev/null || echo 0) ))
if [ "$TRAIN_AGE" -gt 30 ]; then
  (python3 -c "
import runpod, subprocess, re, json
pods = runpod.get_pods()
results = []
for p in pods:
    if not isinstance(p, dict) or p.get('desiredStatus') != 'RUNNING': continue
    ssh_ip = ssh_port = None
    rt = p.get('runtime')
    if not rt: continue
    for port in rt.get('ports',[]):
        if port.get('privatePort') == 22: ssh_ip, ssh_port = port['ip'], port['publicPort']; break
    if not ssh_ip: continue
    try:
        out = subprocess.run(
            ['ssh','-i','$HOME/.ssh/id_ed25519_starbuck100','-o','ConnectTimeout=3','-o','StrictHostKeyChecking=no',
             f'root@{ssh_ip}','-p',str(ssh_port),
             'tail -c 2000 /workspace/exp*.log 2>/dev/null || tail -c 2000 /workspace/training.log 2>/dev/null'],
            capture_output=True, text=True, timeout=8
        ).stdout.strip()
        lines = out.split('\r')
        last = lines[-1].strip()

        # Parse tqdm progress
        m = re.search(r'(\d+)/(\d+)\s+\[[\d:]+<([\d:]+)', last)
        if not m: continue
        step,total,eta_raw = m.group(1),m.group(2),m.group(3)
        pct = int(int(step)*100/int(total))
        ep = eta_raw.split(':')
        if len(ep)==3 and int(ep[0])>0: eta=f'{int(ep[0])}h{int(ep[1]):02d}m'
        elif len(ep)==3: eta=f'{int(ep[1])}m'
        elif len(ep)==2 and int(ep[0])>0: eta=f'{int(ep[0])}m'
        else: eta=f'{int(ep[-1])}s'

        # Extract loss values for trend arrow
        losses = re.findall(r\"'loss':\s*([\d.]+)\", out)
        if not losses:
            losses = re.findall(r'loss[=: ]+([\d.]+)', out)
        trend = ''
        if len(losses) >= 2:
            prev, curr = float(losses[-2]), float(losses[-1])
            if curr < prev: trend = f' loss↓{curr:.2f}'
            elif curr > prev: trend = f' loss↑{curr:.2f}'
            else: trend = f' loss→{curr:.2f}'
        elif len(losses) == 1:
            trend = f' loss={losses[-1]}'

        results.append(f'{step}/{total} ({pct}%) ETA {eta}{trend}')
    except: pass
print(' | '.join(results) if results else '')
" 2>/dev/null > "$TRAIN_CACHE") &
fi

TRAIN=$(cat "$TRAIN_CACHE" 2>/dev/null)

# Build output with OSC 8 clickable link on pod name
if [ -n "$POD_URL" ]; then
  # Make pod name clickable: \e]8;;URL\aPOD_TEXT\e]8;;\a
  POD_LINKED=$(echo "$POD" | sed "s|(\([^)]*\))|\(\x1b]8;;${POD_URL}\x07\1\x1b]8;;\x07\)|")
else
  POD_LINKED="$POD"
fi

if [ -n "$TRAIN" ]; then
  printf '\033[32m🚀 %b 🏋️ %s\033[0m\n' "$POD_LINKED" "$TRAIN"
else
  printf '\033[33m🚀 %b\033[0m\n' "$POD_LINKED"
fi
