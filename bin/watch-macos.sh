#!/bin/bash
set -euo pipefail

# Check dependencies
if ! command -v fswatch &>/dev/null; then
    echo "Error: fswatch not found."
    echo "Install it with: brew install fswatch"
    exit 1
fi

# Load config
ENV_FILE="${WHISPER_CONFIG:-$HOME/.config/local-whisper-obsidian/.env}"
[ -f "$ENV_FILE" ] || { echo "Config not found: $ENV_FILE"; exit 1; }
set -a; source "$ENV_FILE"; set +a

# Validate watch paths
IFS=':' read -ra RAW_PATHS <<< "$SCAN_PATHS"
VALID=()
for p in "${RAW_PATHS[@]}"; do
    if [ -d "$p" ]; then
        VALID+=("$p")
        echo "Watching: $p"
    else
        echo "Warning: path not found, skipping: $p"
    fi
done
[ ${#VALID[@]} -eq 0 ] && { echo "Error: no valid watch paths"; exit 1; }

PYTHON="$WHISPER_ENV/bin/python"
SCRIPT="$WHISPER_SRC/transcribe.py"

# fswatch fires on file create; brief delay ensures write is complete
fswatch -0 -e ".*" -i "\.(m4a|mp3|wav|ogg|opus|webm|flac)$" "${VALID[@]}" \
| while IFS= read -r -d "" file; do
    sleep 0.5
    echo "New audio detected: $file"
    "$PYTHON" "$SCRIPT" "$file" --model "$MODEL" --language "$LANGUAGE" \
        || echo "Failed to transcribe: $file"
done
