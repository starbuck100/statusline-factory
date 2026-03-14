#!/bin/bash
# Block: RunPod — Pod status + training ETA
# Shows: 🚀 A100 12m $0.24 (pod-name) 🏋️ 35/625 (5%) ETA 1h34m
CACHE_DIR="/tmp/claude-statusline"
mkdir -p "$CACHE_DIR"
export RUNPOD_API_KEY="$RUNPOD_API_KEY"

# --- Pod info (cached 60s) ---
POD_CACHE="$CACHE_DIR/runpod"
POD_AGE=999
[ -f "$POD_CACHE" ] && POD_AGE=$(( $(date +%s) - $(stat -c %Y "$POD_CACHE" 2>/dev/null || echo 0) ))
if [ "$POD_AGE" -gt 60 ]; then
  (python3 -c "
import runpod, re
from datetime import datetime, timezone
pods = runpod.get_pods()
running = [p for p in pods if p.get('desiredStatus') == 'RUNNING']
if not running: print('off'); exit()
parts = []
for pod in running:
    gpu = pod.get('machine',{}).get('gpuDisplayName','GPU').split()[0]
    cost_hr = pod.get('costPerHr', 0)
    name = pod.get('name','')
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
print(' | '.join(parts))
" 2>/dev/null > "$POD_CACHE") &
fi

POD=$(cat "$POD_CACHE" 2>/dev/null)
[ "$POD" = "off" ] || [ -z "$POD" ] && exit 0

# --- Training progress (cached 30s) ---
TRAIN_CACHE="$CACHE_DIR/training"
TRAIN_AGE=999
[ -f "$TRAIN_CACHE" ] && TRAIN_AGE=$(( $(date +%s) - $(stat -c %Y "$TRAIN_CACHE" 2>/dev/null || echo 0) ))
if [ "$TRAIN_AGE" -gt 30 ]; then
  (python3 -c "
import runpod, subprocess, re
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
             'tail -c 500 /workspace/exp*.log 2>/dev/null || tail -c 500 /workspace/training.log 2>/dev/null'],
            capture_output=True, text=True, timeout=5
        ).stdout.strip().split('\r')[-1].strip()
        m = re.search(r'(\d+)/(\d+)\s+\[[\d:]+<([\d:]+)', out)
        if m:
            step,total,eta_raw = m.group(1),m.group(2),m.group(3)
            pct = int(int(step)*100/int(total))
            ep = eta_raw.split(':')
            if len(ep)==3 and int(ep[0])>0: eta=f'{int(ep[0])}h{int(ep[1]):02d}m'
            elif len(ep)==3: eta=f'{int(ep[1])}m'
            elif len(ep)==2 and int(ep[0])>0: eta=f'{int(ep[0])}m'
            else: eta=f'{int(ep[-1])}s'
            results.append(f'{step}/{total} ({pct}%) ETA {eta}')
    except: pass
print(' | '.join(results) if results else '')
" 2>/dev/null > "$TRAIN_CACHE") &
fi

TRAIN=$(cat "$TRAIN_CACHE" 2>/dev/null)

# Color logic: green = training active, red = pod running but no training, yellow = waiting for data
if [ -n "$TRAIN" ]; then
  # Training is running — all green
  echo -e "\033[32m🚀 $POD 🏋️ $TRAIN\033[0m"
elif [ "$TRAIN_AGE" -lt 60 ]; then
  # Recently checked, no training found — pod running but training stopped/crashed
  echo -e "\033[31m🚀 $POD ⚠ no training\033[0m"
else
  # Waiting for first SSH check
  echo -e "\033[33m🚀 $POD\033[0m"
fi
