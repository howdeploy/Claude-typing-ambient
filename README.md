**English** | [Русский](README.ru.md)

# claude-typing-ambient

Ambient mechanical keyboard typing sounds while Claude Code works. Plays continuous, realistic keystroke audio from the moment Claude starts processing until the task is complete.

**Works out of the box** — includes pre-recorded keyboard samples. Just install, and Claude starts "typing."

## How it works

When you send a message, you hear a mechanical keyboard typing. The sound plays continuously throughout Claude's entire response — reading files, thinking, editing code — and gently fades out a few seconds after the task completes. No choppy clips, no gaps between samples.

**Features:**
- Works immediately after installation — samples included
- Continuous playback across all tool calls (Read, Edit, Bash, Grep, etc.)
- Gapless shuffled loop — seamless transitions between samples
- Smart fade-out: 3-second grace period prevents cuts between tool calls
- Pauses on permission requests, resumes on next activity
- Replaceable sounds — use recordings of your own keyboard
- Configurable volume and playback mode

## Requirements

| Dependency | Required | Purpose |
|------------|----------|---------|
| **mpv** | Yes | Gapless audio playback with IPC control |
| **socat** | Recommended | Enables pause/unpause without restarting |

### Linux

```bash
# Arch / Manjaro
sudo pacman -S mpv socat

# Ubuntu / Debian
sudo apt install mpv socat

# Fedora
sudo dnf install mpv socat
```

### macOS

```bash
brew install mpv socat
```

## Installation

### From Marketplace (Recommended)

In Claude Code, run:

```
/plugin marketplace add howdeploy/Claude-typing-ambient
/plugin install claude-typing-ambient@howdeploy-plugins
```

Restart Claude Code after installation.

### Manual

```bash
git clone https://github.com/howdeploy/Claude-typing-ambient.git
claude --plugin-dir ./Claude-typing-ambient
```

That's it. Send any message to Claude and you'll hear typing.

## Configuration

Create `~/.claude/claude-typing-ambient.local.md`:

```markdown
---
mode: always
volume: 40
---
```

| Option | Values | Default | Description |
|--------|--------|---------|-------------|
| `mode` | `always` / `edit-only` / `off` | `always` | When to play typing sounds |
| `volume` | `0`–`200` | `130` | mpv volume (100 = original level) |

**Modes:**
- **always** — plays during all Claude activity
- **edit-only** — plays only when Claude writes/edits files
- **off** — disabled

Project-level config (`.claude/claude-typing-ambient.local.md`) overrides global.

## Using Your Own Keyboard Sounds

The plugin ships with default samples, but you can replace them with recordings of your own keyboard.

### What you need

- A recording of yourself typing (5–10 minutes, `.ogg` or `.wav`)
- **ffmpeg** — for slicing the recording into chunks

```bash
# Install ffmpeg (only needed for custom sounds)
sudo pacman -S ffmpeg    # Arch / Manjaro
sudo apt install ffmpeg  # Ubuntu / Debian
brew install ffmpeg      # macOS
```

### Steps

1. **Record** your keyboard typing — use Audacity, OBS, your phone, anything. Save as `.ogg` or `.wav`.

2. **Place** recordings in the `raw/` directory:
```bash
cp ~/my-keyboard-recording.ogg raw/
```

3. **Slice** into samples:
```bash
bash scripts/slice-samples.sh
```
This chops recordings into 20–90 second chunks, filters out silence, and rebuilds the playlist. Your new sounds replace the defaults.

4. **Restart** Claude Code.

### Recording tips

- **Quiet room** — background noise carries into samples
- **Type naturally** — don't force speed or rhythm, just work as usual
- **5–10 minutes** — more source audio = less repetition
- **Multiple sessions** — record on different days for more variety

### Tuning the slicer

Edit `scripts/slice-samples.sh` to adjust:

| Variable | Default | Description |
|----------|---------|-------------|
| `MIN_LEN` | `20.0` | Minimum chunk length in seconds |
| `MAX_LEN` | `90.0` | Maximum chunk length in seconds |
| `FADE_MS` | `0.3` | Crossfade duration at chunk edges (seconds) |
| `MIN_PEAK_DB` | `-30` | Discard chunks quieter than this threshold |

Shorter chunks (5–15s) give more shuffle variety but risk audible transitions. Longer chunks (30–90s) sound more natural.

## Commands

| Command | Description |
|---------|-------------|
| `/claude-typing-ambient:setup` | Slice raw recordings into samples |
| `/claude-typing-ambient:test` | Play 5 seconds of typing, show current config |

## Architecture

Hook-driven lifecycle using Claude Code's plugin hook system.

### Event flow

```
UserPromptSubmit  →  start mpv (shuffled, gapless, looping)
       │
PreToolUse (*)    →  keepalive: cancel pending fade, unpause if paused
       │
Stop              →  fade: schedule pause after 3s grace period
       │              (cancelled by next PreToolUse)
       │
PermissionRequest →  immediate pause (user interaction needed)
       │
SessionEnd        →  kill mpv process, cleanup
```

### Why it sounds continuous

The key insight: `PreToolUse` fires for **every** tool (Read, Edit, Bash, Grep, Glob...), not just writes. Each tool call cancels any pending fade and unpauses if needed. The `Stop` event only schedules a *delayed* pause — if Claude continues working within 3 seconds, the fade is cancelled and playback continues uninterrupted.

### Files

| File | Purpose |
|------|---------|
| `hooks/hooks.json` | Hook event registrations (plugin entry point) |
| `hooks/start-typing.sh` | Config, process management, player launch |
| `hooks/stop-typing.sh` | Fade/pause/stop/kill with IPC and signal fallbacks |
| `samples/chunks/` | Pre-sliced audio samples (shipped with plugin) |
| `samples/typing-playlist.m3u` | Shuffled playlist for mpv |
| `scripts/slice-samples.sh` | ffmpeg slicer for custom sounds |
| `scripts/detect-player.sh` | Player detection with capability reporting |
| `.claude-plugin/plugin.json` | Plugin metadata |
| `commands/setup.md` | `/setup` slash command definition |
| `commands/test.md` | `/test` slash command definition |

### Runtime state

`var/` directory (gitignored) holds runtime files:
- `typing.pid` — PID of the active mpv process
- `mpv.sock` — Unix socket for mpv IPC commands
- `fade.pending` — Sentinel file for delayed fade timer

### Fallback players

If mpv is not available, the plugin falls back to: `ffplay` → `paplay` → `aplay` → `afplay`. Note: fallback players lack gapless playback and IPC pause/unpause.

## Troubleshooting

**No sound:**
- Run `bash scripts/detect-player.sh` — is mpv found?
- Run `ls samples/chunks/ | wc -l` — are samples generated?
- Check that mode is not `off` in your config file

**Sound doesn't stop after task completes:**
- Run `bash hooks/stop-typing.sh kill` to force-stop
- Verify PID: `cat var/typing.pid` then `kill -0 $(cat var/typing.pid)`

**Choppy playback / gaps between samples:**
- Make sure `mpv` is installed (only mpv supports gapless playback)
- Check that you have at least 5+ chunks in `samples/chunks/`
- Try increasing `MIN_LEN` in `scripts/slice-samples.sh` and re-slicing

**Sound too quiet or too loud:**
- Adjust `volume` in config (50 = half, 100 = normal, 150 = amplified)

## License

MIT
