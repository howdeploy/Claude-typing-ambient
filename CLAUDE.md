# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Code plugin that plays ambient mechanical keyboard typing sounds while Claude processes responses. Uses Claude Code's hook system to start/stop audio playback via shell scripts. Distributed as a `.claude-plugin`.

## Architecture

**Hook-driven lifecycle** — `hooks/hooks.json` registers shell scripts against Claude Code events:

- `UserPromptSubmit` → `start-typing.sh chat` (start playback)
- `PreToolUse` (Edit/Write/NotebookEdit) → `start-typing.sh edit` (start if mode=edit-only)
- `PreToolUse` (*) → `start-typing.sh keepalive` (cancel fade, unpause — never starts new player)
- `Stop` → `stop-typing.sh fade` (delayed pause with 3s grace period)
- `PermissionRequest` → `stop-typing.sh pause` (immediate pause via IPC)
- `SessionEnd` → `stop-typing.sh kill` (hard cleanup)

**Continuity model:**
- Sound starts once on `UserPromptSubmit` and plays continuously
- Every `PreToolUse` (any tool) cancels pending fades and unpauses if needed
- `Stop` schedules a fade — if a new tool fires within 3s, the fade is cancelled
- Result: uninterrupted playback for the entire duration of multi-step tasks

**Audio pipeline:**
1. Raw `.ogg` recordings go in `raw/`
2. `scripts/slice-samples.sh` uses ffmpeg to chop into 20–90 second `.wav` chunks in `samples/chunks/`, generates `samples/typing-playlist.m3u`
3. `start-typing.sh` launches mpv with gapless shuffled loop playback, writes PID to `var/typing.pid` and IPC socket to `var/mpv.sock`
4. `stop-typing.sh` controls mpv via IPC (socat) for pause/quit, falls back to signals

**PID tracking:** mpv is launched via `setsid bash -c 'echo $$ > PID_FILE; exec mpv ...'` to reliably capture the actual mpv PID (plain `setsid mpv &; echo $!` captures the parent setsid PID which dies immediately).

**Fade mechanism:** `stop-typing.sh fade` writes a unique ID to `var/fade.pending` and spawns a detached timer (sleep 3s). If `start-typing.sh` runs before the timer fires, it deletes `fade.pending`, making the timer a no-op.

**Player fallback chain:** mpv → ffplay → paplay → aplay → afplay. Only mpv supports gapless playback and IPC pause/unpause.

**Config resolution:** project `.claude/claude-typing-ambient.local.md` > global `~/.claude/claude-typing-ambient.local.md` > defaults (mode=always, volume=130). Config is YAML frontmatter in markdown.

## Key Files

| File | Purpose |
|------|---------|
| `hooks/hooks.json` | Hook event registrations (the plugin entry point) |
| `hooks/start-typing.sh` | Config parsing, process management, player launch |
| `hooks/stop-typing.sh` | Fade/pause/stop/kill with IPC and signal fallbacks |
| `scripts/slice-samples.sh` | ffmpeg audio slicer, playlist generator |
| `scripts/detect-player.sh` | Player detection with capability reporting |
| `.claude-plugin/plugin.json` | Plugin metadata |
| `commands/setup.md` | `/setup` slash command definition |
| `commands/test.md` | `/test` slash command definition |

## Commands

```bash
# Slice raw recordings into samples
bash scripts/slice-samples.sh

# Detect available audio player
bash scripts/detect-player.sh

# Manual test: play 5 seconds of typing
bash hooks/start-typing.sh chat && sleep 5 && bash hooks/stop-typing.sh stop

# Force-stop stuck playback
bash hooks/stop-typing.sh kill
```

## Runtime State

`var/` directory (gitignored) holds:
- `typing.pid` — PID of active mpv process
- `mpv.sock` — Unix socket for mpv IPC (JSON commands via socat)
- `fade.pending` — Sentinel file for delayed fade timer (contains unique fade ID)

## Configuration

Edit `~/.claude/claude-typing-ambient.local.md`:

```markdown
---
mode: always
volume: 40
---
```

- **mode**: `always` | `edit-only` | `off`
- **volume**: 0–200 (100 = original level, >100 = amplified)

Project-level config (`.claude/claude-typing-ambient.local.md`) overrides global.

## Requirements

- **mpv** (recommended) — gapless playback, IPC control
- **ffmpeg** — audio slicing (setup only)
- **socat** — mpv IPC communication (recommended, for pause/unpause)
