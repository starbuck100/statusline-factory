---
name: statusline-factory
description: "Create, manage, and auto-compose status line blocks for Claude Code's bottom bar. Use this skill whenever the user wants to see live info in their terminal — training progress, server status, deployment state, git metrics, API health, or any project-specific monitoring. Also trigger on: 'statusline', 'status bar', 'status line', 'zeig mir live', 'monitoring im terminal', 'show me progress', 'was läuft gerade', 'block erstellen', 'neuen block', 'statusline für X', 'auto statusline', or when starting work on a new project that could benefit from live monitoring. Even simple requests like 'can I see if my server is running' benefit from this skill."
user-invocable: true
---

# Status Line Factory

Create and manage modular status line blocks that show live, project-relevant info in Claude Code's bottom bar. Each block is a self-contained script that outputs one line (or nothing when irrelevant). The composer assembles active blocks into a compact display.

## Architecture

```
~/.claude/statusline.sh              # Composer — runs all active blocks
~/.claude/statusline-blocks/*.sh     # Individual blocks (one per concern)
~/.claude/statusline-active.conf     # Optional: explicit block list (auto-detect if missing)
```

Each block:
- Is a standalone bash script
- Outputs one line with ANSI colors, or nothing if irrelevant
- Caches slow operations (API calls, SSH) in `/tmp/claude-statusline/`
- Must complete in <500ms (use background subshells for slow work)

## Commands

### List blocks
```bash
echo "=== Installed Blocks ===" && for f in ~/.claude/statusline-blocks/*.sh; do
  name=$(basename "$f" .sh)
  desc=$(head -2 "$f" | grep "^# Block:" | sed 's/^# Block: //')
  printf "  %-20s %s\n" "$name" "$desc"
done
```

### Test a block
```bash
bash ~/.claude/statusline-blocks/<name>.sh
```

### Test full status line
```bash
echo '{"context_window":{"used_percentage":30},"cost":{"total_cost_usd":0},"model":{"display_name":"x"}}' | ~/.claude/statusline.sh
```

### Enable/disable blocks
Create `~/.claude/statusline-active.conf` with one block name per line. If the file doesn't exist, all blocks run (self-suppressing when irrelevant).

## Creating a New Block

Every block follows this template:

```bash
#!/bin/bash
# Block: <Name> — <one-line description>
# Shows: <example output>
CACHE_DIR="/tmp/claude-statusline"
mkdir -p "$CACHE_DIR"
CACHE="$CACHE_DIR/<name>"
AGE=999
[ -f "$CACHE" ] && AGE=$(( $(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null || echo 0) ))

if [ "$AGE" -gt <REFRESH_SECONDS> ]; then
  (
    # ... compute value, write to $CACHE ...
    echo "<result>" > "$CACHE"
  ) &  # Background! Don't block the status line
fi

VALUE=$(cat "$CACHE" 2>/dev/null)
[ -z "$VALUE" ] && exit 0  # Nothing to show = silent

# Color: green=good, yellow=warn, red=bad
echo -e "\033[32m<emoji> $VALUE\033[0m"
```

### Block design rules

1. **Self-suppress** — exit 0 with no output when irrelevant (service not running, project not active)
2. **Cache everything slow** — API calls, SSH, network requests go in background subshells
3. **Refresh intervals** — local checks: 30-60s, API calls: 60s, SSH: 30s
4. **Color convention** — green: healthy/active, yellow: warning/degraded, red: down/failed
5. **Compact output** — max ~50 chars per block. Use abbreviations (m/h, $, %).
6. **Emoji prefix** — one emoji to visually separate blocks (🚀🦞⚠🏋️🔧📦🌐💾)
7. **Copy-friendly** — include identifiers (pod names, branch names, URLs) the user can reference

### Common block patterns

**Service health** (port check):
```bash
ss -tlnp | grep -q ":PORT " && echo "up" || echo "DOWN"
```

**API endpoint** (HTTP check):
```bash
STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 URL)
```

**Process check** (running + resource):
```bash
PID=$(pgrep -f "pattern"); [ -n "$PID" ] && ps -o %cpu= -p "$PID"
```

**Remote via SSH** (training, deploys):
```bash
ssh -i KEY -o ConnectTimeout=3 USER@HOST -p PORT "command" 2>/dev/null
```

**Git status** (branch + changes):
```bash
BRANCH=$(git -C /path rev-parse --abbrev-ref HEAD 2>/dev/null)
CHANGES=$(git -C /path status --porcelain 2>/dev/null | wc -l)
```

## Existing Blocks

Read the installed blocks at `~/.claude/statusline-blocks/` to see what's already available before creating duplicates.

## Auto-Creation Mode

When the user starts working on a new project or task, consider if a status line block would help. Good candidates:
- Long-running processes (training, builds, deploys)
- Services that should stay up (servers, databases)
- Remote resources costing money (cloud GPUs, VMs)
- Workflows with progress (migrations, data processing)

Ask: "Soll ich einen Status-Line Block für X erstellen?" if the answer would clearly be yes.
