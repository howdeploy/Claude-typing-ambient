#!/usr/bin/env bash
# start-typing.sh — Start ambient keyboard typing sounds
# Called by Claude Code hooks: UserPromptSubmit, PreToolUse
# Usage: start-typing.sh [chat|edit|keepalive]
#
# Triggers:
#   chat      — start playback (respects mode config)
#   edit      — start playback (for edit-only mode)
#   keepalive — cancel pending fades, unpause if playing; never starts new player
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VAR_DIR="$PLUGIN_ROOT/var"
PID_FILE="$VAR_DIR/typing.pid"
SOCK_FILE="$VAR_DIR/mpv.sock"
PLAYER_FILE="$VAR_DIR/player.info"
FADE_FILE="$VAR_DIR/fade.pending"
PLAYLIST="$PLUGIN_ROOT/samples/typing-playlist.m3u"
TRIGGER="${1:-chat}"

mkdir -p "$VAR_DIR"

# --- Always cancel pending fade on any activity ---
rm -f "$FADE_FILE"

# --- Config ---
parse_config() {
    local config_file=""
    if [[ -f ".claude/claude-typing-ambient.local.md" ]]; then
        config_file=".claude/claude-typing-ambient.local.md"
    elif [[ -f "$HOME/.claude/claude-typing-ambient.local.md" ]]; then
        config_file="$HOME/.claude/claude-typing-ambient.local.md"
    fi

    MODE="always"
    VOLUME="130"

    if [[ -n "$config_file" ]]; then
        local in_frontmatter=false
        while IFS= read -r line; do
            if [[ "$line" == "---" ]]; then
                if $in_frontmatter; then break; fi
                in_frontmatter=true
                continue
            fi
            if $in_frontmatter; then
                if [[ "$line" =~ ^mode:\ *(.+)$ ]]; then
                    MODE="${BASH_REMATCH[1]}"
                elif [[ "$line" =~ ^volume:\ *([0-9]+)$ ]]; then
                    VOLUME="${BASH_REMATCH[1]}"
                fi
            fi
        done < "$config_file"
    fi
}

parse_config

# --- Mode check (skip for keepalive — it only keeps existing sound alive) ---
if [[ "$TRIGGER" != "keepalive" ]]; then
    if [[ "$MODE" == "off" ]]; then
        exit 0
    fi
    if [[ "$MODE" == "edit-only" && "$TRIGGER" == "chat" ]]; then
        exit 0
    fi
fi

if [[ ! -f "$PLAYLIST" ]]; then
    exit 0
fi

# --- Process management ---

cleanup_stale() {
    if [[ -f "$PID_FILE" ]]; then
        local old_pid
        old_pid=$(cat "$PID_FILE")
        if ! kill -0 "$old_pid" 2>/dev/null; then
            rm -f "$PID_FILE" "$SOCK_FILE" "$PLAYER_FILE"
        fi
    fi
}

cleanup_stale

# If player already running, just unpause
if [[ -f "$PID_FILE" ]]; then
    local_pid=$(cat "$PID_FILE")
    if kill -0 "$local_pid" 2>/dev/null; then
        if [[ -S "$SOCK_FILE" ]] && command -v socat >/dev/null 2>&1; then
            echo '{"command":["set_property","pause",false]}' | socat - "$SOCK_FILE" >/dev/null 2>&1 || true
        fi
        exit 0
    fi
fi

# --- Keepalive: never start a new player, only keep existing one alive ---
if [[ "$TRIGGER" == "keepalive" ]]; then
    exit 0
fi

# --- Detect player ---
PLAYER=""
if command -v mpv >/dev/null 2>&1; then
    PLAYER="mpv"
elif command -v ffplay >/dev/null 2>&1; then
    PLAYER="ffplay"
elif command -v paplay >/dev/null 2>&1; then
    PLAYER="paplay"
elif command -v aplay >/dev/null 2>&1; then
    PLAYER="aplay"
elif command -v afplay >/dev/null 2>&1; then
    PLAYER="afplay"
fi

if [[ -z "$PLAYER" ]]; then
    exit 0
fi

# --- Launch player (detached, survives hook timeout) ---
rm -f "$SOCK_FILE"

if [[ "$PLAYER" == "mpv" ]]; then
    # setsid forks — $! gets the parent PID which dies immediately.
    # Fix: use bash -c 'echo $$ > PID; exec mpv' so the PID file
    # gets the actual mpv process PID (bash writes its PID, then exec
    # replaces bash with mpv keeping the same PID).
    if command -v setsid >/dev/null 2>&1; then
        setsid bash -c '
            echo $$ > "$1"
            exec mpv \
                --no-video \
                --really-quiet \
                --no-terminal \
                --audio-display=no \
                --gapless-audio=yes \
                --shuffle \
                --loop-playlist=inf \
                --volume="$2" \
                --input-ipc-server="$3" \
                --playlist="$4"
        ' _ "$PID_FILE" "$VOLUME" "$SOCK_FILE" "$PLAYLIST" </dev/null >/dev/null 2>&1 &
    else
        nohup mpv \
            --no-video \
            --really-quiet \
            --no-terminal \
            --audio-display=no \
            --gapless-audio=yes \
            --shuffle \
            --loop-playlist=inf \
            --volume="$VOLUME" \
            --input-ipc-server="$SOCK_FILE" \
            --playlist="$PLAYLIST" </dev/null >/dev/null 2>&1 &
        echo $! > "$PID_FILE"
    fi
    echo "mpv" > "$PLAYER_FILE"

elif [[ "$PLAYER" == "ffplay" ]]; then
    if command -v setsid >/dev/null 2>&1; then
        setsid bash -c '
            echo $$ > "$1"
            playlist="$2"; volume="$3"
            while true; do
                sample=$(grep -v "^#" "$playlist" | shuf -n1)
                [[ -z "$sample" ]] && continue
                ffplay -nodisp -autoexit -volume "$volume" "$sample" >/dev/null 2>&1
            done
        ' _ "$PID_FILE" "$PLAYLIST" "$VOLUME" </dev/null >/dev/null 2>&1 &
    else
        nohup bash -c '
            playlist="$1"; volume="$2"
            while true; do
                sample=$(grep -v "^#" "$playlist" | shuf -n1)
                [[ -z "$sample" ]] && continue
                ffplay -nodisp -autoexit -volume "$volume" "$sample" >/dev/null 2>&1
            done
        ' _ "$PLAYLIST" "$VOLUME" </dev/null >/dev/null 2>&1 &
        echo $! > "$PID_FILE"
    fi
    echo "ffplay" > "$PLAYER_FILE"

else
    if command -v setsid >/dev/null 2>&1; then
        setsid bash -c '
            echo $$ > "$1"
            playlist="$2"; volume="$3"; player="$4"
            while true; do
                sample=$(grep -v "^#" "$playlist" | shuf -n1)
                [[ -z "$sample" ]] && continue
                case "$player" in
                    paplay) paplay "$sample" 2>/dev/null ;;
                    aplay)  aplay -q "$sample" 2>/dev/null ;;
                    afplay) afplay -v "$(echo "scale=2; $volume / 100" | bc)" "$sample" 2>/dev/null ;;
                esac
            done
        ' _ "$PID_FILE" "$PLAYLIST" "$VOLUME" "$PLAYER" </dev/null >/dev/null 2>&1 &
    else
        nohup bash -c '
            playlist="$1"; volume="$2"; player="$3"
            while true; do
                sample=$(grep -v "^#" "$playlist" | shuf -n1)
                [[ -z "$sample" ]] && continue
                case "$player" in
                    paplay) paplay "$sample" 2>/dev/null ;;
                    aplay)  aplay -q "$sample" 2>/dev/null ;;
                    afplay) afplay -v "$(echo "scale=2; $volume / 100" | bc)" "$sample" 2>/dev/null ;;
                esac
            done
        ' _ "$PLAYLIST" "$VOLUME" "$PLAYER" </dev/null >/dev/null 2>&1 &
        echo $! > "$PID_FILE"
    fi
    echo "$PLAYER" > "$PLAYER_FILE"
fi

exit 0
