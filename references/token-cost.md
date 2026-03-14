# Status Line — Zero Context Cost

## The status line does NOT consume tokens

From the [official Claude Code docs](https://code.claude.com/docs/en/statusline.md):

> "The status line runs locally and does not consume API tokens."

The output is:
- Executed locally on your machine
- Displayed as a UI element at the bottom of the terminal
- **Never sent to the API**
- **Never injected into the conversation context**
- **Never part of the transcript**

This means you can monitor as many things as you want without any impact on your context window.

## Why blocks still self-suppress

Even though there's no token cost, blocks hide when irrelevant for **visual clarity** — a cluttered status bar is hard to scan. The goal is a clean, glanceable bar that shows only what matters right now.

## Refresh intervals (configurable per block)

Each block caches independently in `/tmp/claude-statusline/`. The `AGE -gt <SECONDS>` value controls refresh rate.

| Block | Default | Adjustable via |
|-------|---------|---------------|
| context | every turn | N/A (from session data) |
| gpu | 30s | `AGE -gt 30` in gpu.sh |
| runpod (pod) | 60s | `POD_AGE -gt 60` in runpod.sh |
| runpod (training) | 30s | `TRAIN_AGE -gt 30` in runpod.sh |
| openclaw | 45s | `AGE -gt 45` in openclaw.sh |
| services | 120s | `AGE -gt 120` in services.sh |

Lower value = fresher data but more API/SSH calls. Higher = less load, staler data. SSH-heavy blocks (runpod training) should stay ≥30s to avoid connection spam.
