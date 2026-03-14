# Statusline Factory

Modular, auto-composing status line blocks for [Claude Code](https://claude.com/claude-code). See live training progress, server health, GPU usage, and project-specific metrics — right in your terminal's bottom bar.

```
🦞 up 2h | ecap: 3m ago  🚀 A100 31m $0.62 (my-pod) 🏋️ 200/625 (32%) ETA 1h04m  🎮 18.2/24G qwen3.5
```

## Why?

Long coding sessions lose track of what's running. A training job finishes and you don't notice for 20 minutes. A server crashes silently. Your context window fills up. This fixes that — **zero tokens when nothing's happening, ~25 tokens when everything is.**

## Features

- **Modular blocks** — each concern is a standalone script
- **Self-suppressing** — blocks show nothing when irrelevant (no pod = no RunPod line)
- **Cached** — slow operations (API, SSH) run in background, results cached 30-120s
- **Color-coded** — green=healthy, yellow=warning, red=down/crashed
- **Copy-friendly** — includes identifiers (pod names, branches) you can paste into chat
- **Token-efficient** — ~25 tokens/turn worst case, 0 when idle. See [token cost analysis](references/token-cost.md)

## Included Blocks

| Block | What it shows | When visible |
|-------|--------------|-------------|
| `context` | Context window % | Only when >50% (yellow/red) |
| `gpu` | Local VRAM + loaded model | Only when VRAM >1GB in use |
| `runpod` | Pod GPU, uptime, cost, training ETA | Only when a pod is running |
| `openclaw` | Gateway uptime, agent last activity | Only when gateway is running |
| `services` | Down services | Only when something is DOWN |

## Install

```bash
# 1. Copy blocks and composer
mkdir -p ~/.claude/statusline-blocks
cp blocks/*.sh ~/.claude/statusline-blocks/
cp composer.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh ~/.claude/statusline-blocks/*.sh

# 2. Enable in Claude Code settings
# Add to ~/.claude/settings.json:
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}

# 3. Restart Claude Code (or it hot-reloads)
```

## Create Your Own Block

```bash
#!/bin/bash
# Block: MyThing — one-line description
CACHE_DIR="/tmp/claude-statusline"
mkdir -p "$CACHE_DIR"
CACHE="$CACHE_DIR/mything"
AGE=999
[ -f "$CACHE" ] && AGE=$(( $(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null || echo 0) ))

if [ "$AGE" -gt 60 ]; then
  (
    # Your check here (API call, SSH, port check, etc.)
    echo "result" > "$CACHE"
  ) &  # MUST be background — don't block the status line
fi

VALUE=$(cat "$CACHE" 2>/dev/null)
[ -z "$VALUE" ] && exit 0  # Nothing = silent

echo -e "\033[32m🔧 $VALUE\033[0m"  # green, yellow(\033[33m), red(\033[31m)
```

Save as `~/.claude/statusline-blocks/mything.sh` — it auto-discovers.

## Token Cost

The status line output is injected after each assistant message.

| Scenario | Tokens/turn |
|----------|------------|
| Nothing running | 0 |
| Only context warning | ~2 |
| Full stack (GPU + RunPod + training + OpenClaw) | ~25 |

For comparison: a typical CLAUDE.md costs 500-2000 tokens/turn.

## Block Design Rules

1. **Self-suppress** — `exit 0` with no output when irrelevant
2. **Cache slow ops** — background subshells, never block the render
3. **Be compact** — max ~50 chars per block, use abbreviations
4. **Color convention** — green=ok, yellow=warn, red=down
5. **Include identifiers** — pod names, branches, ports — things the user can reference

## Skill

The `statusline-factory` skill teaches Claude Code how to create and manage blocks. Install the skill for auto-creation of blocks when you start new projects:

```bash
cp SKILL.md ~/.claude/skills/statusline-factory/SKILL.md
```

## License

MIT
