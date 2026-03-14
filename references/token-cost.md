# Token Cost Analysis

The status line output is injected after each assistant message. Token cost is minimal because:

1. **Blocks self-suppress** — no output = 0 tokens
2. **Output is compact** — abbreviations, no prose, ~4 chars/token
3. **Heavy work is cached** — API/SSH calls run in background subshells, only cached results are read

## Measured costs (2026-03-14)

| Block | When active | When inactive |
|-------|------------|---------------|
| context | ~2 tokens (only >50%) | 0 |
| openclaw | ~7 tokens | 0 (gateway down) |
| runpod | ~16 tokens (pod+training) | 0 (no pod) |
| services | 0 (all healthy) | ~5 tokens (lists down services) |
| **Total worst case** | **~25 tokens/turn** | **0** |

For comparison: a typical CLAUDE.md consumes 500-2000 tokens per turn.

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

## Design goal

Status line output should stay under 50 tokens per turn. If a block exceeds ~20 tokens, it should be split or compressed.
