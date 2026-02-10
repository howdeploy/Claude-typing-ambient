#!/usr/bin/env bash
# stop-typing.sh — Stop/pause ambient keyboard typing sounds
# Called by Claude Code hooks: Stop, PermissionRequest, SessionEnd
# Usage: stop-typing.sh [stop|pause|fade|kill]
#
# Actions:
#   fade  — delayed pause (3s grace period, cancelled by new activity)
#   pause — immediate pause via IPC
#   stop  — graceful quit
#   kill  — hard kill (SIGKILL)
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VAR_DIR="$PLUGIN_ROOT/var"
PID_FILE="$VAR_DIR/typing.pid"
SOCK_FILE="$VAR_DIR/mpv.sock"
PLAYER_FILE="$VAR_DIR/player.info"
FADE_FILE="$VAR_DIR/fade.pending"
ACTION="${1:-stop}"

# --- Fade: delayed pause with cancellation support ---
if [[ "$ACTION" == "fade" ]]; then
    # Generate unique fade ID — if start-typing.sh runs before the timer
    # fires, it deletes FADE_FILE and the timer becomes a no-op.
    FADE_ID="$$.$RANDOM"
    echo "$FADE_ID" > "$FADE_FILE"

    setsid bash -c '
        fade_file="$1"; fade_id="$2"; sock_file="$3"
        pid_file="$4"; player_file="$5"

        sleep 1

        # Check if this fade is still the active one (not cancelled)
        if [[ ! -f "$fade_file" ]] || [[ "$(cat "$fade_file" 2>/dev/null)" != "$fade_id" ]]; then
            exit 0
        fi

        # Read player info
        player="unknown"
        [[ -f "$player_file" ]] && player=$(cat "$player_file")

        if [[ "$player" == "mpv" ]] && [[ -S "$sock_file" ]] && command -v socat >/dev/null 2>&1; then
            echo "{\"command\":[\"set_property\",\"pause\",true]}" | socat - "$sock_file" >/dev/null 2>&1 || true
        elif [[ -f "$pid_file" ]]; then
            pid=$(cat "$pid_file")
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null || true
            fi
            rm -f "$pid_file" "$sock_file" "$player_file"
        fi

        rm -f "$fade_file"
    ' _ "$FADE_FILE" "$FADE_ID" "$SOCK_FILE" "$PID_FILE" "$PLAYER_FILE" </dev/null >/dev/null 2>&1 &
    exit 0
fi

# --- All other actions: cancel any pending fade first ---
rm -f "$FADE_FILE"

if [[ ! -f "$PID_FILE" ]]; then
    exit 0
fi

PID=$(cat "$PID_FILE")
PLAYER="unknown"
[[ -f "$PLAYER_FILE" ]] && PLAYER=$(cat "$PLAYER_FILE")

if ! kill -0 "$PID" 2>/dev/null; then
    rm -f "$PID_FILE" "$SOCK_FILE" "$PLAYER_FILE"
    exit 0
fi

case "$ACTION" in
    pause)
        if [[ "$PLAYER" == "mpv" ]] && [[ -S "$SOCK_FILE" ]] && command -v socat >/dev/null 2>&1; then
            echo '{"command":["set_property","pause",true]}' | socat - "$SOCK_FILE" >/dev/null 2>&1 || true
        fi
        ;;
    stop)
        if [[ "$PLAYER" == "mpv" ]] && [[ -S "$SOCK_FILE" ]] && command -v socat >/dev/null 2>&1; then
            echo '{"command":["quit"]}' | socat - "$SOCK_FILE" >/dev/null 2>&1 || true
            for _ in 1 2 3 4 5; do
                kill -0 "$PID" 2>/dev/null || break
                sleep 0.1
            done
        fi
        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID" 2>/dev/null || true
            pkill -9 -P "$PID" 2>/dev/null || true
        fi
        rm -f "$PID_FILE" "$SOCK_FILE" "$PLAYER_FILE"
        ;;
    kill)
        kill -9 "$PID" 2>/dev/null || true
        pkill -9 -P "$PID" 2>/dev/null || true
        rm -f "$PID_FILE" "$SOCK_FILE" "$PLAYER_FILE"
        ;;
    *)
        kill "$PID" 2>/dev/null || true
        rm -f "$PID_FILE" "$SOCK_FILE" "$PLAYER_FILE"
        ;;
esac

exit 0
