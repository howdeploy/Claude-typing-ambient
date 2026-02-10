#!/usr/bin/env bash
# detect-player.sh — Detect available audio player
# Outputs: player name and capabilities
set -euo pipefail

check_player() {
    local name="$1" features="$2"
    if command -v "$name" >/dev/null 2>&1; then
        local version
        case "$name" in
            mpv)    version=$(mpv --version 2>/dev/null | head -1) ;;
            ffplay) version=$(ffplay -version 2>/dev/null | head -1) ;;
            *)      version="installed" ;;
        esac
        echo "$name|$features|$version"
        return 0
    fi
    return 1
}

# Priority order: mpv (best) > ffplay > paplay > aplay > afplay
if   check_player mpv    "gapless,shuffle,ipc,volume"; then exit 0
elif check_player ffplay  "volume"; then exit 0
elif check_player paplay  "basic"; then exit 0
elif check_player aplay   "basic"; then exit 0
elif check_player afplay  "volume"; then exit 0
else
    echo "none|none|No audio player found"
    echo "" >&2
    echo "No supported audio player found!" >&2
    echo "Please install one of: mpv (recommended), ffplay, paplay, aplay, afplay" >&2
    echo "" >&2
    echo "  Arch/Manjaro: sudo pacman -S mpv" >&2
    echo "  Ubuntu/Debian: sudo apt install mpv" >&2
    echo "  macOS: brew install mpv" >&2
    exit 1
fi
