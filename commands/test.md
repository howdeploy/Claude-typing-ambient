---
name: test
description: Test claude-typing-ambient — play 5 seconds of typing sounds
---

# Test claude-typing-ambient

Play a short typing sample to verify the plugin works.

## Instructions

1. Detect the audio player:
```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/detect-player.sh"
```

2. Play 5 seconds of typing:
```bash
bash "$CLAUDE_PLUGIN_ROOT/hooks/start-typing.sh" chat && sleep 5 && bash "$CLAUDE_PLUGIN_ROOT/hooks/stop-typing.sh" stop
```

3. Show current config and sample info:
```bash
echo "=== Global config ==="
cat "$HOME/.claude/claude-typing-ambient.local.md" 2>/dev/null || echo "(not set — using defaults: mode=always, volume=130)"
echo ""
echo "=== Player ==="
bash "$CLAUDE_PLUGIN_ROOT/scripts/detect-player.sh"
echo ""
echo "=== Samples ==="
echo "Chunks: $(ls "$CLAUDE_PLUGIN_ROOT/samples/chunks/" 2>/dev/null | wc -l)"
echo "Playlist entries: $(grep -c -v '^#' "$CLAUDE_PLUGIN_ROOT/samples/typing-playlist.m3u" 2>/dev/null || echo 0)"
```

Report results to the user: whether sound played, which player was used, and how many samples are available.
