---
name: setup
description: Set up claude-typing-ambient — slice audio samples from raw recordings
---

# Setup claude-typing-ambient

Run the audio slicer to prepare typing samples from raw recordings.

## Steps

1. Check that raw audio files exist in the `raw/` directory
2. Run `scripts/slice-samples.sh` to slice them into chunks
3. Report results: number of chunks, playlist size

## Instructions

Run these commands in sequence:

```bash
# Check for raw recordings
ls -la "$CLAUDE_PLUGIN_ROOT/raw/"*.ogg 2>/dev/null && echo "Raw files found" || echo "ERROR: No .ogg files in raw/ — copy your keyboard recordings there first"
```

```bash
# Run the slicer
bash "$CLAUDE_PLUGIN_ROOT/scripts/slice-samples.sh"
```

```bash
# Verify results
echo "=== Chunks ===" && ls "$CLAUDE_PLUGIN_ROOT/samples/chunks/" 2>/dev/null | wc -l
echo "=== Playlist ===" && wc -l "$CLAUDE_PLUGIN_ROOT/samples/typing-playlist.m3u" 2>/dev/null
```

Report the chunk count and playlist size to the user and confirm setup is complete.
